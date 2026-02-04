import { Env } from "./auth";

/**
 * R2 を使った写真ストレージ
 *
 * POST   /photos         - アップロード (multipart/form-data, field: "image")
 * GET    /photos/:key    - ダウンロード
 * DELETE /photos/:key    - 削除
 * GET    /photos         - 一覧
 */

export async function handlePhotoUpload(
  request: Request,
  env: Env,
): Promise<Response> {
  const formData = await request.formData();
  const imageFile = formData.get("image");

  if (!imageFile || !(imageFile instanceof File)) {
    return jsonResponse({ error: "No image file provided" }, 400);
  }

  // Generate unique key: YYYY/MM/DD/timestamp-random.ext
  const now = new Date();
  const datePath = `${now.getFullYear()}/${pad(now.getMonth() + 1)}/${pad(now.getDate())}`;
  const ext = getExtension(imageFile.name);
  const key = `${datePath}/${now.getTime()}-${randomHex(6)}.${ext}`;

  await env.PHOTOS.put(key, imageFile.stream(), {
    httpMetadata: {
      contentType: imageFile.type || "image/jpeg",
    },
    customMetadata: {
      originalName: imageFile.name,
      uploadedAt: now.toISOString(),
    },
  });

  return jsonResponse({ key, size: imageFile.size });
}

export async function handlePhotoGet(
  key: string,
  env: Env,
): Promise<Response> {
  const object = await env.PHOTOS.get(key);
  if (!object) {
    return jsonResponse({ error: "Not found" }, 404);
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("Cache-Control", "public, max-age=31536000, immutable");

  return new Response(object.body, { headers });
}

export async function handlePhotoDelete(
  key: string,
  env: Env,
): Promise<Response> {
  await env.PHOTOS.delete(key);
  return jsonResponse({ deleted: true });
}

export async function handlePhotoList(
  request: Request,
  env: Env,
): Promise<Response> {
  const url = new URL(request.url);
  const prefix = url.searchParams.get("prefix") || undefined;
  const cursor = url.searchParams.get("cursor") || undefined;

  const listed = await env.PHOTOS.list({
    prefix,
    cursor,
    limit: 100,
  });

  const items = listed.objects.map((obj) => ({
    key: obj.key,
    size: obj.size,
    uploaded: obj.uploaded.toISOString(),
  }));

  return jsonResponse({
    items,
    cursor: listed.truncated ? listed.cursor : null,
  });
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

function getExtension(name: string): string {
  const ext = name.split(".").pop()?.toLowerCase();
  return ext || "jpg";
}

function randomHex(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
