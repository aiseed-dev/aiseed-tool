import { Env, authenticate } from "./auth";
import {
  handleReadUrl,
  handleReadImage,
  handleSearch,
} from "./cultivation_info";
import { handleIdentify } from "./identify";
import {
  handlePhotoUpload,
  handlePhotoGet,
  handlePhotoDelete,
  handlePhotoList,
} from "./photos";
import { handleSyncPull, handleSyncPush } from "./sync";
import { handleSiteGenerate, handleSiteDeploy } from "./sites";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CORS headers for app access
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }

    // Auth check
    const authError = authenticate(request, env);
    if (authError) return withCors(authError);

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Routes
      if (path === "/identify" && request.method === "POST") {
        return withCors(await handleIdentify(request, env));
      }

      // Cultivation info endpoints
      if (
        path === "/cultivation-info/read-url" &&
        request.method === "POST"
      ) {
        return withCors(await handleReadUrl(request, env));
      }

      if (
        path === "/cultivation-info/read-image" &&
        request.method === "POST"
      ) {
        return withCors(await handleReadImage(request, env));
      }

      if (path === "/cultivation-info" && request.method === "GET") {
        return withCors(await handleSearch(request, env));
      }

      if (path === "/sync/pull" && request.method === "POST") {
        return withCors(await handleSyncPull(request, env));
      }

      if (path === "/sync/push" && request.method === "POST") {
        return withCors(await handleSyncPush(request, env));
      }

      if (path === "/photos" && request.method === "POST") {
        return withCors(await handlePhotoUpload(request, env));
      }

      if (path === "/photos" && request.method === "GET") {
        return withCors(await handlePhotoList(request, env));
      }

      if (path.startsWith("/photos/") && request.method === "GET") {
        const key = decodeURIComponent(path.slice("/photos/".length));
        return withCors(await handlePhotoGet(key, env));
      }

      if (path.startsWith("/photos/") && request.method === "DELETE") {
        const key = decodeURIComponent(path.slice("/photos/".length));
        return withCors(await handlePhotoDelete(key, env));
      }

      // Site generation & deployment
      if (path === "/sites/generate" && request.method === "POST") {
        return withCors(await handleSiteGenerate(request, env));
      }

      if (path === "/sites/deploy" && request.method === "POST") {
        return withCors(await handleSiteDeploy(request, env));
      }

      // Health check
      if (path === "/" || path === "/health") {
        return withCors(
          new Response(JSON.stringify({ status: "ok", version: "0.1.0" }), {
            headers: { "Content-Type": "application/json" },
          }),
        );
      }

      return withCors(
        new Response(JSON.stringify({ error: "Not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        }),
      );
    } catch (err) {
      console.error("Unhandled error:", err);
      return withCors(
        new Response(JSON.stringify({ error: "Internal server error" }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
  },
} satisfies ExportedHandler<Env>;

function corsHeaders(): Headers {
  const headers = new Headers();
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  headers.set("Access-Control-Max-Age", "86400");
  return headers;
}

function withCors(response: Response): Response {
  const newHeaders = new Headers(response.headers);
  newHeaders.set("Access-Control-Allow-Origin", "*");
  return new Response(response.body, {
    status: response.status,
    headers: newHeaders,
  });
}
