export interface Env {
  PHOTOS: R2Bucket;
  AUTH_TOKEN: string;
  ANTHROPIC_KEY: string;
}

/**
 * Bearer トークンによる認証チェック
 * AUTH_TOKEN が未設定の場合は認証をスキップ（開発用）
 */
export function authenticate(request: Request, env: Env): Response | null {
  const token = env.AUTH_TOKEN;
  if (!token) return null; // no auth configured

  const header = request.headers.get("Authorization");
  if (!header || header !== `Bearer ${token}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  return null;
}
