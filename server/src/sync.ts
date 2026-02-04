import { Env } from "./auth";

/**
 * データ同期エンドポイント
 *
 * POST /sync/pull  - サーバーの更新データを取得
 *   Body: { "since": "2024-06-15T00:00:00.000Z" }
 *   Response: { "locations": [...], "plots": [...], ..., "deleted": [...], "timestamp": "..." }
 *
 * POST /sync/push  - ローカルの更新データを送信
 *   Body: { "locations": [...], "plots": [...], ..., "deleted": [...] }
 *   Response: { "ok": true, "timestamp": "..." }
 */

const SYNC_TABLES = [
  "locations",
  "plots",
  "crops",
  "records",
  "record_photos",
  "observations",
  "observation_entries",
] as const;

type TableName = (typeof SYNC_TABLES)[number];

export async function handleSyncPull(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = (await request.json()) as { since?: string };
  const since = body.since || "1970-01-01T00:00:00.000Z";
  const now = new Date().toISOString();

  const result: Record<string, unknown[]> = {};

  for (const table of SYNC_TABLES) {
    const { results } = await env.DB.prepare(
      `SELECT * FROM ${table} WHERE updated_at > ?`,
    )
      .bind(since)
      .all();
    result[table] = results || [];
  }

  // Get deleted records since last sync
  const { results: deleted } = await env.DB.prepare(
    `SELECT id, table_name, deleted_at FROM deleted_records WHERE deleted_at > ?`,
  )
    .bind(since)
    .all();

  return jsonResponse({
    ...result,
    deleted: deleted || [],
    timestamp: now,
  });
}

export async function handleSyncPush(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = (await request.json()) as Record<string, unknown[]>;
  const now = new Date().toISOString();

  for (const table of SYNC_TABLES) {
    const rows = body[table] as Record<string, unknown>[] | undefined;
    if (!rows || rows.length === 0) continue;

    for (const row of rows) {
      const columns = Object.keys(row);
      const placeholders = columns.map(() => "?").join(", ");
      const updates = columns
        .filter((c) => c !== "id")
        .map((c) => `${c} = excluded.${c}`)
        .join(", ");

      await env.DB.prepare(
        `INSERT INTO ${table} (${columns.join(", ")}) VALUES (${placeholders})
         ON CONFLICT(id) DO UPDATE SET ${updates}`,
      )
        .bind(...columns.map((c) => row[c]))
        .run();
    }
  }

  // Handle deletions
  const deleted = body.deleted as
    | Array<{ id: string; table_name: string }>
    | undefined;
  if (deleted && deleted.length > 0) {
    for (const del of deleted) {
      if (!SYNC_TABLES.includes(del.table_name as TableName)) continue;

      await env.DB.prepare(`DELETE FROM ${del.table_name} WHERE id = ?`)
        .bind(del.id)
        .run();

      await env.DB.prepare(
        `INSERT INTO deleted_records (id, table_name, deleted_at) VALUES (?, ?, ?)
         ON CONFLICT(id, table_name) DO UPDATE SET deleted_at = excluded.deleted_at`,
      )
        .bind(del.id, del.table_name, now)
        .run();
    }
  }

  return jsonResponse({ ok: true, timestamp: now });
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
