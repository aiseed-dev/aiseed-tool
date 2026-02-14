import { Env } from "./auth";
import { generateSiteHtml, SiteData } from "./site_template";

/**
 * ユーザーホームページ機能
 *
 * POST /sites/generate  - HTML 生成 (JSON レスポンス)
 * POST /sites/deploy    - ユーザーの Cloudflare Pages に自動デプロイ
 */

// ---------- Generate ----------

export async function handleSiteGenerate(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = (await request.json()) as SiteData;

  if (!body.farmName) {
    return jsonResponse({ error: "farmName is required" }, 400);
  }

  // 写真キーを公開 URL に変換
  // photoUrls が /photos/ で始まるパスなら、リクエスト元のサーバー URL で補完
  const serverOrigin = new URL(request.url).origin;
  const data: SiteData = {
    ...body,
    crops: body.crops.map((crop) => ({
      ...crop,
      photoUrls: crop.photoUrls.map((url) =>
        url.startsWith("/") ? `${serverOrigin}${url}` : url,
      ),
    })),
  };

  const html = generateSiteHtml(data);

  return jsonResponse({ html, size: html.length });
}

// ---------- Deploy to user's Cloudflare Pages ----------

interface DeployRequest {
  /** サイトデータ */
  site: SiteData;
  /** ユーザーの Cloudflare Account ID */
  cfAccountId: string;
  /** ユーザーの Cloudflare API Token */
  cfApiToken: string;
  /** Pages プロジェクト名 */
  projectName: string;
}

export async function handleSiteDeploy(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = (await request.json()) as DeployRequest;

  if (!body.site?.farmName) {
    return jsonResponse({ error: "site.farmName is required" }, 400);
  }
  if (!body.cfAccountId || !body.cfApiToken) {
    return jsonResponse(
      { error: "cfAccountId and cfApiToken are required" },
      400,
    );
  }
  if (!body.projectName) {
    return jsonResponse({ error: "projectName is required" }, 400);
  }

  // HTML を生成
  const serverOrigin = new URL(request.url).origin;
  const data: SiteData = {
    ...body.site,
    crops: body.site.crops.map((crop) => ({
      ...crop,
      photoUrls: crop.photoUrls.map((url) =>
        url.startsWith("/") ? `${serverOrigin}${url}` : url,
      ),
    })),
  };
  const html = generateSiteHtml(data);

  const cfBase = `https://api.cloudflare.com/client/v4/accounts/${body.cfAccountId}/pages/projects`;

  // 1. プロジェクトが存在するか確認、なければ作成
  const projectCheck = await fetch(`${cfBase}/${body.projectName}`, {
    headers: { Authorization: `Bearer ${body.cfApiToken}` },
  });

  if (projectCheck.status === 404) {
    const createRes = await fetch(cfBase, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${body.cfApiToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: body.projectName,
        production_branch: "main",
      }),
    });

    if (!createRes.ok) {
      const err = await createRes.text();
      return jsonResponse(
        { error: "Failed to create Pages project", detail: err },
        502,
      );
    }
  } else if (!projectCheck.ok) {
    const err = await projectCheck.text();
    return jsonResponse(
      { error: "Failed to check Pages project", detail: err },
      502,
    );
  }

  // 2. Direct Upload でデプロイ
  const form = new FormData();
  form.append("index.html", new Blob([html], { type: "text/html" }), "index.html");

  const deployRes = await fetch(
    `${cfBase}/${body.projectName}/deployments`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${body.cfApiToken}`,
      },
      body: form,
    },
  );

  if (!deployRes.ok) {
    const err = await deployRes.text();
    return jsonResponse(
      { error: "Failed to deploy to Pages", detail: err },
      502,
    );
  }

  const deployResult = (await deployRes.json()) as {
    result?: { url?: string; id?: string };
  };

  return jsonResponse({
    ok: true,
    url: deployResult.result?.url,
    deploymentId: deployResult.result?.id,
    projectUrl: `https://${body.projectName}.pages.dev`,
  });
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
