import { NextResponse, type NextRequest } from "next/server";

/**
 * Two quiet doors.
 *
 * 1. The staging gate (STAGING_GATE_KEY): the whole deployment is private —
 *    arriving with ?gate=<key> sets a long-lived cookie; without it, a calm
 *    dark nothing. Exempt: /welcome and identity completion (their own tokens).
 *
 * 2. The replay viewer (EXPERIMENT_VIEWER_KEY): a SEPARATE secret for the
 *    facilitator-only Discovery tool at /replay. Testers hold the staging key,
 *    so the recordings need their own door — ?viewer=<key> sets its cookie.
 *    Without that key configured, /replay is closed entirely.
 */

const GATE_COOKIE = "lb_gate";
const VIEWER_COOKIE = "lb_viewer";
const EXEMPT_PREFIXES = ["/welcome", "/api/identity/complete", "/_next", "/favicon"];
const VIEWER_PREFIXES = ["/replay", "/api/experiment/replay"];
const COOKIE_MAX_AGE = 180 * 24 * 60 * 60;

function darkNothing() {
  return new NextResponse(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>LifeBook</title></head><body style="background:#0b0a09;margin:0;height:100vh"></body></html>`,
    { status: 404, headers: { "content-type": "text/html" } },
  );
}

function keyDoor(
  request: NextRequest,
  param: string,
  cookieName: string,
  key: string,
) {
  const offered = request.nextUrl.searchParams.get(param);
  if (offered === key) {
    const url = request.nextUrl.clone();
    url.searchParams.delete(param);
    const response = NextResponse.redirect(url);
    response.cookies.set(cookieName, key, {
      httpOnly: true,
      secure: true,
      sameSite: "lax",
      maxAge: COOKIE_MAX_AGE,
      path: "/",
    });
    return response;
  }
  if (request.cookies.get(cookieName)?.value === key) {
    return NextResponse.next();
  }
  return darkNothing();
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Facilitator-only replay viewer — its own secret, closed without one.
  if (VIEWER_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    const viewerKey = process.env.EXPERIMENT_VIEWER_KEY;
    if (!viewerKey) return darkNothing();
    return keyDoor(request, "viewer", VIEWER_COOKIE, viewerKey);
  }

  // The staging gate for everything else.
  const gateKey = process.env.STAGING_GATE_KEY;
  if (!gateKey) return NextResponse.next();
  if (EXEMPT_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    return NextResponse.next();
  }
  return keyDoor(request, "gate", GATE_COOKIE, gateKey);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image).*)"],
};
