import { execFileSync, spawn } from "node:child_process";

const root = new URL("../", import.meta.url);
const binary = new URL("node_modules/.bin/supabase", root).pathname;
const output = execFileSync(binary, ["status", "-o", "json"], {
  cwd: root,
  encoding: "utf8",
  stdio: ["ignore", "pipe", "pipe"],
});
const start = output.indexOf("{");
const end = output.lastIndexOf("}");
if (start < 0 || end < start) {
  throw new Error("Local Supabase status JSON is unavailable");
}
const status = JSON.parse(output.slice(start, end + 1));
const publicKey = status.PUBLISHABLE_KEY ?? status.ANON_KEY;
const serviceKey = status.SECRET_KEY ?? status.SERVICE_ROLE_KEY;
if (!status.API_URL || !publicKey || !serviceKey) {
  throw new Error("Local Supabase Auth environment is incomplete");
}

const child = spawn(
  process.execPath,
  [new URL("node_modules/next/dist/bin/next", root).pathname, "dev"],
  {
    cwd: root,
    env: {
      ...process.env,
      APP_BASE_URL: "http://127.0.0.1:3000",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publicKey,
      NEXT_PUBLIC_SUPABASE_URL: status.API_URL,
      SF6_USER_CODE_RECLAIM_PEPPER:
        "local-browser-test-pepper-not-for-hosted-use",
      SUPABASE_SERVICE_ROLE_KEY: serviceKey,
    },
    stdio: "inherit",
  },
);

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => child.kill(signal));
}
child.on("exit", (code) => process.exit(code ?? 0));
