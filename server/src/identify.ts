import { Env } from "./auth";

interface IdentifyResult {
  name: string;
  confidence: number;
  description?: string;
}

/**
 * Claude Vision を使った植物同定エンドポイント
 *
 * リクエスト: POST /identify
 *   Content-Type: multipart/form-data
 *   Body: image (file)
 *
 * レスポンス:
 *   { "results": [{ "name": "トマト", "confidence": 0.95, "description": "..." }] }
 */
export async function handleIdentify(
  request: Request,
  env: Env,
): Promise<Response> {
  if (!env.ANTHROPIC_KEY) {
    return jsonResponse({ error: "ANTHROPIC_KEY not configured" }, 500);
  }

  // Parse multipart form data
  const formData = await request.formData();
  const imageFile = formData.get("image");

  if (!imageFile || !(imageFile instanceof File)) {
    return jsonResponse({ error: "No image file provided" }, 400);
  }

  // Convert to base64 for Claude Vision API
  const imageBytes = await imageFile.arrayBuffer();
  const base64Image = arrayBufferToBase64(imageBytes);

  // Determine media type
  const mediaType = detectMediaType(imageFile.type, imageFile.name);

  // Call Claude Vision API
  const results = await callClaudeVision(env.ANTHROPIC_KEY, base64Image, mediaType);

  return jsonResponse({ results });
}

async function callClaudeVision(
  apiKey: string,
  base64Image: string,
  mediaType: string,
): Promise<IdentifyResult[]> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mediaType,
                data: base64Image,
              },
            },
            {
              type: "text",
              text: `この写真に写っている植物を同定してください。

以下のJSON形式で回答してください（説明文は不要、JSONのみ）:
[
  {
    "name": "植物の一般名（日本語）",
    "scientific_name": "学名",
    "confidence": 0.0-1.0の確信度,
    "description": "状態の簡潔な説明（成長段階、健康状態、特徴など）"
  }
]

注意:
- 栽培作物だけでなく、雑草も同定してください
- 複数の植物が写っている場合はすべて列挙してください
- 確信度が低い場合でも候補を返してください
- 植物が写っていない場合は空配列 [] を返してください`,
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    console.error(`Claude API error: ${response.status}`);
    return [];
  }

  const data = (await response.json()) as {
    content: Array<{ type: string; text?: string }>;
  };

  const textBlock = data.content.find((b) => b.type === "text");
  if (!textBlock?.text) return [];

  try {
    // Extract JSON from response (may be wrapped in markdown code block)
    const jsonStr = extractJson(textBlock.text);
    const parsed = JSON.parse(jsonStr) as Array<{
      name: string;
      scientific_name?: string;
      confidence: number;
      description?: string;
    }>;

    return parsed.map((item) => ({
      name: item.name,
      confidence: item.confidence,
      description: item.description,
    }));
  } catch {
    console.error("Failed to parse Claude response:", textBlock.text);
    return [];
  }
}

function extractJson(text: string): string {
  // Try to extract JSON from markdown code block
  const codeBlockMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) return codeBlockMatch[1].trim();

  // Try to find JSON array directly
  const arrayMatch = text.match(/\[[\s\S]*\]/);
  if (arrayMatch) return arrayMatch[0];

  return text.trim();
}

function detectMediaType(mimeType: string, fileName: string): string {
  if (mimeType && mimeType.startsWith("image/")) return mimeType;
  const ext = fileName.toLowerCase().split(".").pop();
  switch (ext) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    case "heic":
      return "image/heic";
    default:
      return "image/jpeg";
  }
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
