import { NextResponse, type NextRequest } from "next/server";

/**
 * The staging gate — LifeBook's own quiet door.
 *
 * When STAGING_GATE_KEY is set, the deployment is private: arriving with
 * ?gate=<key> (the link Tracy sends) sets a long-lived cookie; arriving
 * without it shows nothing but a calm dark page. When the variable is not
 * set (local development, and one day production), the gate does not exist.
 *
 * Exempt: /welcome and the identity-completion API — a doorway opened on a
 * brand-new device must work; those paths are already protected by their
 * own single-use token.
 */

const GATE_COOKIE = "lb_gate";
const EXEMPT_PREFIXES = ["/welcome", "/api/identity/complete", "/_next", "/favicon"];

export function middleware(request: NextRequest) {
  const gateKey = process.env.STAGING_GATE_KEY;
  if (!gateKey) {
    return NextResponse.next();
  }

  const { pathname, searchParams } = request.nextUrl;

  if (EXEMPT_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    return NextResponse.next();
  }

  const offered = searchParams.get("gate");
  if (offered === gateKey) {
    const url = request.nextUrl.clone();
    url.searchParams.delete("gate");
    const response = NextResponse.redirect(url);
    response.cookies.set(GATE_COOKIE, gateKey, {
      httpOnly: true,
      secure: true,
      sameSite: "lax",
      maxAge: 180 * 24 * 60 * 60,
      path: "/",
    });
    return response;
  }

  if (request.cookies.get(GATE_COOKIE)?.value === gateKey) {
    return NextResponse.next();
  }

  // Nothing to see: a calm dark nothing, not an error, not a login form.
  return new NextResponse(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>LifeBook</title></head><body style="background:#0b0a09;margin:0;height:100vh"></body></html>`,
    { status: 404, headers: { "content-type": "text/html" } },
  );
}

export const config = {
  matcher: ["/((?!_next/static|_next/image).*)"],
};
