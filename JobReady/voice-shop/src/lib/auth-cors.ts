import { NextResponse } from "next/server";

const allowedOrigins = new Set([
  "https://getreadyjob.com",
  "https://www.getreadyjob.com",
  "https://getreadyjob-india-1cb34.web.app",
  "https://getreadyjob-india-1cb34.firebaseapp.com",
]);

export function withAuthCors(response: NextResponse, request: Request) {
  const origin = request.headers.get("origin") || "";
  if (allowedOrigins.has(origin)) {
    response.headers.set("Access-Control-Allow-Origin", origin);
    response.headers.set("Access-Control-Allow-Credentials", "true");
    response.headers.set("Vary", "Origin");
  }
  return response;
}

export function authCorsOptions(request: Request) {
  const response = new NextResponse(null, { status: 204 });
  const origin = request.headers.get("origin") || "";
  if (allowedOrigins.has(origin)) {
    response.headers.set("Access-Control-Allow-Origin", origin);
    response.headers.set("Access-Control-Allow-Credentials", "true");
    response.headers.set("Access-Control-Allow-Headers", "Content-Type");
    response.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.headers.set("Vary", "Origin");
  }
  return response;
}
