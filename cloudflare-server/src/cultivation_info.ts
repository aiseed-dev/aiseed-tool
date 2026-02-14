import { Env } from "./auth";

/**
 * 栽培情報の構造化データ
 */
export interface CultivationInfo {
  id: string;
  source_url: string | null;
  source_type: string; // 'url' | 'seed_photo'
  crop_name: string;
  variety: string;
  data: string; // JSON string of structured info
  created_at: string;
}

export interface CultivationData {
  cropName: string;
  variety: string;
  sowingPeriod: string;
  harvestPeriod: string;
  spacing: string;
  depth: string;
  sunlight: string;
  watering: string;
  fertilizer: string;
  companionPlants: string;
  tips: string;
  rawText: string;
}

const CULTIVATION_PROMPT = `この情報から栽培に必要なデータを抽出してください。

以下のJSON形式で回答してください（説明文は不要、JSONのみ）:
{
  "cropName": "作物名（日本語）",
  "variety": "品種名",
  "sowingPeriod": "播種時期（例: 3月〜4月）",
  "harvestPeriod": "収穫時期（例: 7月〜9月）",
  "spacing": "株間（例: 40-50cm）",
  "depth": "播種深さ（例: 5mm）",
  "sunlight": "日照条件",
  "watering": "水やりの頻度・量",
  "fertilizer": "施肥情報",
  "companionPlants": "コンパニオンプランツ",
  "tips": "栽培のコツ・注意点",
  "rawText": "元の情報から読み取れたテキスト全文"
}

注意:
- 情報が読み取れない項目は空文字列にしてください
- 日本語で回答してください
- 外国語の情報は日本語に翻訳してください`;

/**
 * POST /cultivation-info/read-url
 * URLからWebページを取得し、AIで栽培情報を構造化
 */
export async function handleReadUrl(
  request: Request,
  env: Env,
): Promise<Response> {
  if (!env.ANTHROPIC_KEY) {
    return jsonResponse({ error: "ANTHROPIC_KEY not configured" }, 500);
  }

  const body = (await request.json()) as { url?: string };
  if (!body.url) {
    return jsonResponse({ error: "url is required" }, 400);
  }

  const url = body.url;

  // Check cache in D1
  const cached = await findByUrl(env.DB, url);
  if (cached) {
    return jsonResponse({
      ...JSON.parse(cached.data),
      id: cached.id,
      cached: true,
    });
  }

  // Fetch web page
  let pageText: string;
  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; GrowApp/1.0; cultivation info reader)",
      },
    });
    if (!res.ok) {
      return jsonResponse(
        { error: `Failed to fetch URL: ${res.status}` },
        400,
      );
    }
    const html = await res.text();
    pageText = htmlToText(html);
  } catch (err) {
    return jsonResponse({ error: `Failed to fetch URL: ${err}` }, 400);
  }

  // Truncate to avoid token limits
  if (pageText.length > 10000) {
    pageText = pageText.substring(0, 10000);
  }

  // Call Claude to structure the info
  const data = await callClaudeText(
    env.ANTHROPIC_KEY,
    `以下はWebページ（${url}）のテキストです:\n\n${pageText}`,
  );

  if (!data) {
    return jsonResponse({ error: "Failed to extract cultivation info" }, 500);
  }

  // Save to D1
  const id = crypto.randomUUID();
  await saveCultivationInfo(env.DB, {
    id,
    source_url: url,
    source_type: "url",
    crop_name: data.cropName,
    variety: data.variety,
    data: JSON.stringify(data),
    created_at: new Date().toISOString(),
  });

  return jsonResponse({ ...data, id, cached: false });
}

/**
 * POST /cultivation-info/read-image
 * 種袋写真からAIで栽培情報を構造化
 */
export async function handleReadImage(
  request: Request,
  env: Env,
): Promise<Response> {
  if (!env.ANTHROPIC_KEY) {
    return jsonResponse({ error: "ANTHROPIC_KEY not configured" }, 500);
  }

  const formData = await request.formData();
  const imageFile = formData.get("image");

  if (!imageFile || !(imageFile instanceof File)) {
    return jsonResponse({ error: "No image file provided" }, 400);
  }

  const imageBytes = await imageFile.arrayBuffer();
  const base64Image = arrayBufferToBase64(imageBytes);
  const mediaType = detectMediaType(imageFile.type, imageFile.name);

  const data = await callClaudeVision(env.ANTHROPIC_KEY, base64Image, mediaType);

  if (!data) {
    return jsonResponse(
      { error: "Failed to extract cultivation info from image" },
      500,
    );
  }

  // Save to D1
  const id = crypto.randomUUID();
  await saveCultivationInfo(env.DB, {
    id,
    source_url: null,
    source_type: "seed_photo",
    crop_name: data.cropName,
    variety: data.variety,
    data: JSON.stringify(data),
    created_at: new Date().toISOString(),
  });

  return jsonResponse({ ...data, id, cached: false });
}

/**
 * GET /cultivation-info?url=...&q=...
 * URLまたはキーワードで既存の栽培情報を検索
 */
export async function handleSearch(
  request: Request,
  env: Env,
): Promise<Response> {
  const url = new URL(request.url);
  const searchUrl = url.searchParams.get("url");
  const query = url.searchParams.get("q");

  if (searchUrl) {
    const result = await findByUrl(env.DB, searchUrl);
    if (result) {
      return jsonResponse({
        results: [{ ...JSON.parse(result.data), id: result.id }],
      });
    }
    return jsonResponse({ results: [] });
  }

  if (query) {
    const results = await searchByName(env.DB, query);
    return jsonResponse({
      results: results.map((r) => ({ ...JSON.parse(r.data), id: r.id })),
    });
  }

  return jsonResponse({ error: "url or q parameter required" }, 400);
}

// -- Claude API calls --

async function callClaudeText(
  apiKey: string,
  userText: string,
): Promise<CultivationData | null> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
      messages: [
        {
          role: "user",
          content: `${userText}\n\n${CULTIVATION_PROMPT}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    console.error(`Claude API error: ${response.status}`);
    return null;
  }

  return parseClaudeResponse(response);
}

async function callClaudeVision(
  apiKey: string,
  base64Image: string,
  mediaType: string,
): Promise<CultivationData | null> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
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
              text: `この種袋の写真から栽培情報を読み取ってください。\n\n${CULTIVATION_PROMPT}`,
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    console.error(`Claude API error: ${response.status}`);
    return null;
  }

  return parseClaudeResponse(response);
}

async function parseClaudeResponse(
  response: Response,
): Promise<CultivationData | null> {
  const data = (await response.json()) as {
    content: Array<{ type: string; text?: string }>;
  };

  const textBlock = data.content.find((b) => b.type === "text");
  if (!textBlock?.text) return null;

  try {
    const jsonStr = extractJson(textBlock.text);
    return JSON.parse(jsonStr) as CultivationData;
  } catch {
    console.error("Failed to parse Claude response:", textBlock.text);
    return null;
  }
}

// -- D1 operations --

async function findByUrl(
  db: D1Database,
  url: string,
): Promise<CultivationInfo | null> {
  const result = await db
    .prepare("SELECT * FROM cultivation_info WHERE source_url = ? LIMIT 1")
    .bind(url)
    .first<CultivationInfo>();
  return result;
}

async function searchByName(
  db: D1Database,
  query: string,
): Promise<CultivationInfo[]> {
  const pattern = `%${query}%`;
  const result = await db
    .prepare(
      "SELECT * FROM cultivation_info WHERE crop_name LIKE ? OR variety LIKE ? ORDER BY created_at DESC LIMIT 20",
    )
    .bind(pattern, pattern)
    .all<CultivationInfo>();
  return result.results;
}

async function saveCultivationInfo(
  db: D1Database,
  info: CultivationInfo,
): Promise<void> {
  await db
    .prepare(
      "INSERT INTO cultivation_info (id, source_url, source_type, crop_name, variety, data, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(
      info.id,
      info.source_url,
      info.source_type,
      info.crop_name,
      info.variety,
      info.data,
      info.created_at,
    )
    .run();
}

// -- Utilities --

function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<nav[\s\S]*?<\/nav>/gi, "")
    .replace(/<footer[\s\S]*?<\/footer>/gi, "")
    .replace(/<header[\s\S]*?<\/header>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function extractJson(text: string): string {
  const codeBlockMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) return codeBlockMatch[1].trim();
  const objMatch = text.match(/\{[\s\S]*\}/);
  if (objMatch) return objMatch[0];
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
