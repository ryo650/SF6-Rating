import type { AuthEnv } from "@/lib/env/auth";

type HeaderReader = Pick<Headers, "get">;

type AuthOriginInput = {
  env: AuthEnv;
  headers: HeaderReader;
  requestUrl?: string | URL;
};

export class AuthOriginError extends Error {
  constructor(readonly reason: string) {
    super(`Auth origin rejected: ${reason}`);
    this.name = "AuthOriginError";
  }
}

function singleHeader(headers: HeaderReader, name: string): string | null {
  const value = headers.get(name)?.trim();
  if (!value) return null;
  if (value.includes(",")) throw new AuthOriginError(`${name}_multiple`);
  return value;
}

function isLoopback(hostname: string) {
  return (
    hostname === "localhost" || hostname === "127.0.0.1" || hostname === "[::1]"
  );
}

function parseOrigin(value: string, reason: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new AuthOriginError(`${reason}_invalid`);
  }

  if (
    parsed.username ||
    parsed.password ||
    (parsed.protocol !== "https:" && parsed.protocol !== "http:")
  ) {
    throw new AuthOriginError(`${reason}_invalid`);
  }

  return new URL(parsed.origin);
}

function configuredVercelHost(value: string | undefined): string | null {
  if (!value) return null;
  const candidate = value.trim().toLowerCase();
  if (
    !candidate ||
    candidate.includes(",") ||
    candidate.includes("://") ||
    candidate.includes("/") ||
    candidate.includes("@")
  ) {
    throw new AuthOriginError("vercel_url_invalid");
  }

  const parsed = parseOrigin(`https://${candidate}`, "vercel_url");
  if (parsed.port) throw new AuthOriginError("vercel_url_port");
  return parsed.host;
}

function requestOrigin({ headers, requestUrl }: AuthOriginInput): URL {
  const forwardedHost = singleHeader(headers, "x-forwarded-host");
  const host = forwardedHost ?? singleHeader(headers, "host");
  const forwardedProto = singleHeader(
    headers,
    "x-forwarded-proto",
  )?.toLowerCase();

  if (
    forwardedProto &&
    forwardedProto !== "https" &&
    forwardedProto !== "http"
  ) {
    throw new AuthOriginError("forwarded_proto_invalid");
  }

  let fallback: URL | null = null;
  if (requestUrl) fallback = parseOrigin(requestUrl.toString(), "request_url");
  const candidateHost = host ?? fallback?.host;
  if (!candidateHost) throw new AuthOriginError("request_host_missing");

  const hostname = candidateHost.startsWith("[")
    ? candidateHost.slice(0, candidateHost.indexOf("]") + 1).toLowerCase()
    : candidateHost.split(":")[0].toLowerCase();
  const protocol = forwardedProto
    ? `${forwardedProto}:`
    : (fallback?.protocol ?? (isLoopback(hostname) ? "http:" : "https:"));

  return parseOrigin(`${protocol}//${candidateHost}`, "request_origin");
}

function runtimeMode(env: AuthEnv) {
  if (env.VERCEL_ENV) return env.VERCEL_ENV;
  return env.NODE_ENV === "production" ? "production" : "development";
}

export function resolveAuthOrigin(input: AuthOriginInput): string {
  const mode = runtimeMode(input.env);
  const actual = requestOrigin(input);

  if (mode === "production") {
    const canonical = parseOrigin(input.env.APP_BASE_URL, "app_base_url");
    if (canonical.protocol !== "https:" && !isLoopback(canonical.hostname)) {
      throw new AuthOriginError("production_origin_not_https");
    }
    if (actual.origin !== canonical.origin) {
      throw new AuthOriginError("production_origin_mismatch");
    }
    return canonical.origin;
  }

  if (mode === "preview") {
    const allowedHosts = new Set(
      [input.env.VERCEL_URL, input.env.VERCEL_BRANCH_URL]
        .map(configuredVercelHost)
        .filter((host): host is string => host !== null),
    );
    if (actual.protocol !== "https:") {
      throw new AuthOriginError("preview_origin_not_https");
    }
    if (!allowedHosts.has(actual.host.toLowerCase())) {
      throw new AuthOriginError("preview_origin_not_allowed");
    }
    return actual.origin;
  }

  if (!isLoopback(actual.hostname)) {
    throw new AuthOriginError("development_origin_not_loopback");
  }
  return actual.origin;
}

export function buildAuthCallbackUrl(
  input: AuthOriginInput,
  next: string,
): string {
  const callback = new URL("/auth/callback", resolveAuthOrigin(input));
  callback.searchParams.set("next", next);
  return callback.toString();
}
