import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

const root = new URL("../", import.meta.url);
const supabaseBinary = new URL("node_modules/.bin/supabase", root).pathname;

function localStatus() {
  let output = "";
  try {
    output = execFileSync(supabaseBinary, ["status", "-o", "json"], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    output = `${error.stdout ?? ""}\n${error.stderr ?? ""}`;
  }

  const start = output.indexOf("{");
  const end = output.lastIndexOf("}");
  if (start < 0 || end < start) {
    throw new Error("Local Supabase status JSON is unavailable");
  }
  return JSON.parse(output.slice(start, end + 1));
}

function requiredStatusValue(status, candidates) {
  for (const key of candidates) {
    if (typeof status[key] === "string" && status[key].length > 0) {
      return status[key];
    }
  }
  throw new Error(`Local Supabase status is missing ${candidates.join("/")}`);
}

async function waitForMessage(mailpitUrl, email, excludedIds = new Set()) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const response = await fetch(`${mailpitUrl}/api/v1/messages`);
    assert.equal(response.ok, true, "Mailpit messages endpoint must respond");
    const mailbox = await response.json();
    const message = mailbox.messages?.find(
      (candidate) =>
        !excludedIds.has(candidate.ID) &&
        candidate.To?.some(
          (recipient) => recipient.Address?.toLowerCase() === email,
        ),
    );
    if (message) return message;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("Expected local Auth email was not delivered to Mailpit");
}

async function verificationUrl(mailpitUrl, messageId) {
  const response = await fetch(`${mailpitUrl}/api/v1/message/${messageId}`);
  assert.equal(response.ok, true, "Mailpit message endpoint must respond");
  const message = await response.json();
  const body = `${message.HTML ?? ""}\n${message.Text ?? ""}`
    .replaceAll("&amp;", "&")
    .replaceAll("&#34;", '"');
  const links = body.match(/https?:\/\/[^\s"'<>]+/g) ?? [];
  const link = links.find((candidate) => candidate.includes("/auth/v1/verify"));
  if (!link)
    throw new Error("Auth verification URL is missing from local email");
  return link.replace(/[).,]+$/, "");
}

async function followAuthEmail(link) {
  const response = await fetch(link, { redirect: "manual" });
  assert.ok(
    response.status >= 200 && response.status < 400,
    `Auth email verification returned ${response.status}`,
  );
  return response.headers.get("location");
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

const status = localStatus();
const apiUrl = requiredStatusValue(status, ["API_URL"]);
const publicKey = requiredStatusValue(status, ["PUBLISHABLE_KEY", "ANON_KEY"]);
const serviceKey = requiredStatusValue(status, [
  "SECRET_KEY",
  "SERVICE_ROLE_KEY",
]);
const mailpitUrl = requiredStatusValue(status, ["INBUCKET_URL"]);
const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
const email = `phase2-auth-${suffix}@example.test`;
const initialPassword = `P2-local-${randomUUID()}!`;
const updatedPassword = `P2-reset-${randomUUID()}!`;
const username = `auth${suffix}`.slice(0, 20);
const sf6UserCode = suffix.replace(/\D/g, "").slice(-10).padStart(10, "0");

const client = createClient(apiUrl, publicKey, {
  auth: {
    autoRefreshToken: false,
    detectSessionInUrl: false,
    flowType: "implicit",
    persistSession: false,
  },
});
const admin = createClient(apiUrl, serviceKey, {
  auth: {
    autoRefreshToken: false,
    detectSessionInUrl: false,
    persistSession: false,
  },
});

let profileId;
let userId;
let hasAppendOnlyHistory = false;
try {
  const signUp = await client.auth.signUp({
    email,
    password: initialPassword,
    options: { emailRedirectTo: "http://127.0.0.1:3000/auth/callback" },
  });
  assert.ifError(signUp.error);
  assert.ok(signUp.data.user?.id, "Sign-up must create an Auth user");
  if (signUp.data.session !== null) {
    throw new Error("Unverified signup unexpectedly received a session");
  }
  userId = signUp.data.user.id;

  const provisioned = await admin
    .from("profile_accounts")
    .select("profile_id,account_status,onboarding_status")
    .eq("auth_user_id", userId)
    .single();
  assert.ifError(provisioned.error);
  assert.equal(provisioned.data.account_status, "onboarding");
  assert.equal(provisioned.data.onboarding_status, "not_started");
  profileId = provisioned.data.profile_id;

  const confirmationMessage = await waitForMessage(mailpitUrl, email);
  const confirmationLink = await verificationUrl(
    mailpitUrl,
    confirmationMessage.ID,
  );
  await followAuthEmail(confirmationLink);

  const signIn = await client.auth.signInWithPassword({
    email,
    password: initialPassword,
  });
  assert.ifError(signIn.error);
  assert.ok(signIn.data.user?.email_confirmed_at);
  assert.ok(signIn.data.session?.access_token);

  const resetRequest = await client.auth.resetPasswordForEmail(email, {
    redirectTo: "http://127.0.0.1:3000/auth/callback",
  });
  assert.ifError(resetRequest.error);
  const resetMessage = await waitForMessage(
    mailpitUrl,
    email,
    new Set([confirmationMessage.ID]),
  );
  const resetLink = await verificationUrl(mailpitUrl, resetMessage.ID);
  const resetLocation = await followAuthEmail(resetLink);
  assert.ok(resetLocation, "Recovery verification must return a redirect");
  const resetRedirect = new URL(resetLocation);
  const recovery = new URLSearchParams(resetRedirect.hash.slice(1));
  const accessToken = recovery.get("access_token");
  const refreshToken = recovery.get("refresh_token");
  assert.ok(
    accessToken && refreshToken,
    "Recovery redirect must contain a session",
  );
  const recoverySession = await client.auth.setSession({
    access_token: accessToken,
    refresh_token: refreshToken,
  });
  assert.ifError(recoverySession.error);
  const passwordUpdate = await client.auth.updateUser({
    password: updatedPassword,
  });
  assert.ifError(passwordUpdate.error);
  await client.auth.signOut({ scope: "local" });
  const resetSignIn = await client.auth.signInWithPassword({
    email,
    password: updatedPassword,
  });
  assert.ifError(resetSignIn.error);

  const accountSave = await admin.rpc("phase2_save_account_step", {
    requested_actor_auth_user_id: userId,
    requested_username: username,
    requested_username_normalized: username,
    requested_idempotency_key: `auth-account-${suffix}`,
    requested_hash: sha256(`account-${suffix}`),
  });
  assert.ifError(accountSave.error);
  const sf6Save = await admin.rpc("phase2_save_sf6_info_step", {
    requested_actor_auth_user_id: userId,
    requested_player_name: "Local Auth Test",
    requested_user_code: sf6UserCode,
    requested_user_code_digest: sha256(`reclaim-${sf6UserCode}`),
    requested_country_code: "JP",
    requested_broad_region_code: "JP-KANTO",
    requested_idempotency_key: `auth-sf6-${suffix}`,
    requested_hash: sha256(`sf6-${suffix}`),
  });
  assert.ifError(sf6Save.error);
  const completion = await admin.rpc("phase2_complete_onboarding", {
    requested_actor_auth_user_id: userId,
    requested_character_code: "ryu",
    requested_rank: "gold",
    requested_rank_tier: 3,
    requested_master_rating: null,
    requested_idempotency_key: `auth-complete-${suffix}`,
    requested_hash: sha256(`complete-${suffix}`),
    requested_preview_parameter_version: "starting-rating-v2",
  });
  assert.ifError(completion.error);
  hasAppendOnlyHistory = true;

  const deletionRequest = await admin.rpc("phase2_request_account_deletion", {
    requested_actor_auth_user_id: userId,
    requested_idempotency_key: `auth-delete-${suffix}`,
    requested_hash: sha256(`delete-${suffix}`),
  });
  assert.ifError(deletionRequest.error);
  assert.equal(deletionRequest.data.ready_to_finalize, true);
  const detach = await admin.rpc("phase2_detach_avatars_for_deletion", {
    requested_actor_auth_user_id: userId,
  });
  assert.ifError(detach.error);
  assert.deepEqual(detach.data, []);
  const anonymization = await admin.rpc(
    "phase2_prepare_account_anonymization",
    {
      requested_actor_auth_user_id: userId,
      requested_user_code_digest: sha256(`reclaim-${sf6UserCode}`),
      requested_idempotency_key: `auth-anonymize-${suffix}`,
      requested_hash: sha256(`anonymize-${suffix}`),
    },
  );
  assert.ifError(anonymization.error);
  const authDeletion = await admin.auth.admin.deleteUser(userId);
  assert.ifError(authDeletion.error);
  const jobCompletion = await admin.rpc("phase2_mark_auth_deletion_complete", {
    requested_job_id: anonymization.data.job_id,
  });
  assert.ifError(jobCompletion.error);

  const retained = await admin
    .from("profile_accounts")
    .select("auth_user_id,account_status")
    .eq("profile_id", profileId)
    .single();
  assert.ifError(retained.error);
  assert.equal(retained.data.auth_user_id, null);
  assert.equal(retained.data.account_status, "anonymized");
  const history = await admin
    .from("rating_history")
    .select("id", { count: "exact", head: true })
    .eq("profile_id", profileId);
  assert.ifError(history.error);
  assert.equal(
    history.count,
    1,
    "Anonymized account must retain rating history",
  );

  console.log(
    "Phase 2 Auth integration: PASS (verification, reset, provisioning, session, Auth deletion)",
  );
} finally {
  if (userId) {
    await admin.auth.admin.deleteUser(userId).catch(() => undefined);
  }
  if (profileId && !hasAppendOnlyHistory) {
    const projectId = readFileSync(
      new URL("supabase/config.toml", root),
      "utf8",
    ).match(/^project_id = "([^"]+)"/m)?.[1];
    if (projectId) {
      const cleanup = `
        delete from private.domain_action_receipts where actor_profile_id = '${profileId}'::uuid;
        delete from private.action_rate_limits where actor_key = '${userId}';
        delete from private.deleted_user_code_reclaims where deleted_profile_id = '${profileId}'::uuid;
        delete from private.account_deletion_jobs where profile_id = '${profileId}'::uuid;
        delete from public.rating_history where profile_id = '${profileId}'::uuid;
        delete from public.placement_initializations where profile_id = '${profileId}'::uuid;
        delete from public.profile_sf6_identities where profile_id = '${profileId}'::uuid;
        delete from public.profile_private_details where profile_id = '${profileId}'::uuid;
        delete from public.avatar_assets where profile_id = '${profileId}'::uuid;
        delete from public.profile_accounts where profile_id = '${profileId}'::uuid;
        delete from public.profiles where id = '${profileId}'::uuid;
      `;
      try {
        execFileSync(
          "docker",
          [
            "exec",
            `supabase_db_${projectId}`,
            "psql",
            "-X",
            "-qAt",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            cleanup,
          ],
          { stdio: "ignore" },
        );
      } catch {
        // The next clean DB reset removes failed-test fixtures. Never mask the
        // original Auth assertion with best-effort local cleanup.
      }
    }
  }
}
