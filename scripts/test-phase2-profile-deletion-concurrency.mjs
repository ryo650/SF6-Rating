import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { createHash, randomInt, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";

// This suite writes disposable fixtures through a local Docker Unix socket.
// It never accepts a database URL, hosted credentials, or a remote Docker host.
const project = readFileSync("supabase/config.toml", "utf8").match(
  /^project_id = "([a-zA-Z0-9_-]+)"/m,
)?.[1];
assert.ok(project, "Local Supabase project ID is required");
assert.ok(!process.env.DOCKER_HOST, "DOCKER_HOST overrides are not allowed");
const context = execFileSync("docker", ["context", "show"], {
  encoding: "utf8",
}).trim();
const endpoint = execFileSync(
  "docker",
  ["context", "inspect", context, "--format", "{{.Endpoints.docker.Host}}"],
  { encoding: "utf8" },
).trim();
assert.ok(
  endpoint.startsWith("unix://"),
  "Docker must use a local Unix socket",
);
const container = `supabase_db_${project}`;
const docker = ["--context", context];
const inspected = JSON.parse(
  execFileSync(
    "docker",
    [
      ...docker,
      "inspect",
      "--format",
      '{"name":{{json .Name}},"running":{{json .State.Running}},"image":{{json .Config.Image}}}',
      container,
    ],
    { encoding: "utf8" },
  ),
);
assert.equal(inspected.name, `/${container}`);
assert.equal(inspected.running, true);
assert.match(inspected.image, /(?:^|\/)supabase\/postgres(?::|@)/);

const psql = [
  "exec",
  "-i",
  "-e",
  "PGOPTIONS=-c statement_timeout=15000 -c lock_timeout=10000",
  container,
  "psql",
  "-h",
  "/var/run/postgresql",
  "-X",
  "-qAt",
  "-U",
  "postgres",
  "-d",
  "postgres",
  "-v",
  "ON_ERROR_STOP=1",
];
const literal = (value) => `'${String(value).replaceAll("'", "''")}'`;
const query = (sql) =>
  execFileSync("docker", [...docker, ...psql], {
    input: sql,
    encoding: "utf8",
    timeout: 20000,
    stdio: ["pipe", "pipe", "pipe"],
  }).trim();
assert.equal(
  query(
    "select inet_server_addr() is null and current_database() = 'postgres';",
  ),
  "t",
  "Database must be accessed through the container-local PostgreSQL socket",
);

const sessions = new Set();
class Session {
  constructor(name) {
    this.output = "";
    this.errors = "";
    this.sequence = 0;
    this.pending = new Map();
    this.child = spawn("docker", [...docker, ...psql], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    sessions.add(this);
    this.done = new Promise((resolve) => {
      this.child.on("exit", (code) => {
        this.exitCode = code;
        for (const { reject, timer } of this.pending.values()) {
          clearTimeout(timer);
          reject(
            new Error(`SQL session ${name} exited (${code}): ${this.errors}`),
          );
        }
        this.pending.clear();
        sessions.delete(this);
        resolve(code);
      });
    });
    this.child.stderr.on("data", (data) => (this.errors += data));
    this.child.stdout.on("data", (data) => {
      this.output += data;
      for (const [marker, pending] of this.pending) {
        if (this.output.split(/\r?\n/).includes(marker)) {
          clearTimeout(pending.timer);
          this.pending.delete(marker);
          pending.resolve();
        }
      }
    });
    this.name = name;
  }

  sql(sql) {
    const marker = `race_done_${++this.sequence}`;
    const promise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(marker);
        reject(new Error(`Timed out waiting for SQL session ${this.name}`));
      }, 20000);
      this.pending.set(marker, { resolve, reject, timer });
    });
    this.child.stdin.write(`${sql}\n\\echo ${marker}\n`);
    return promise;
  }

  async close() {
    if (this.exitCode === undefined) this.child.stdin.end("\\q\n");
    return this.done;
  }
}

async function waitBlocked(waiter, holder) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const blocked = query(`
      select count(*) from pg_catalog.pg_stat_activity as waiting
      join pg_catalog.pg_stat_activity as holding
        on holding.pid = any(pg_catalog.pg_blocking_pids(waiting.pid))
      where waiting.application_name = ${literal(waiter.name)}
        and holding.application_name = ${literal(holder.name)}
        and waiting.wait_event_type = 'Lock';
    `);
    if (blocked === "1") return;
    assert.equal(
      waiter.exitCode,
      undefined,
      "Contending RPC must still be pending",
    );
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error("RPC did not block behind the first transaction");
}

const fixtures = [];
function fixture() {
  const user = randomUUID();
  const name = `race${user.replaceAll("-", "").slice(0, 12)}`;
  const digest = createHash("sha256").update(user).digest("hex");
  const code = String(randomInt(1000000000, 10000000000));
  const test = { user, digest };
  fixtures.push(test);
  query(`
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      ${literal(user)}::uuid, '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated', ${literal(`${name}@example.test`)}, '',
      statement_timestamp(), '{}'::jsonb, '{}'::jsonb,
      statement_timestamp(), statement_timestamp()
    );
  `);
  test.profile = query(`select profile_id from public.profile_accounts
    where auth_user_id = ${literal(user)}::uuid;`);
  query(`
    select public.phase2_save_account_step(
      ${literal(user)}, ${literal(name)}, ${literal(name)}, 'race-account', repeat('a', 64));
    select public.phase2_save_sf6_info_step(
      ${literal(user)}, 'Local Race', ${literal(code)}, ${literal(digest)},
      'JP', 'JP-KANTO', 'race-sf6', repeat('b', 64));
    select public.phase2_complete_onboarding(
      ${literal(user)}, 'ryu', 'gold', 3::smallint, null::integer,
      'race-complete', repeat('c', 64), 'starting-rating-v2');
  `);
  test.ratingState = query(`select json_build_object(
    'rating', current_rating, 'placement', placement_status,
    'count', placement_completed_count)::text from public.profiles
    where id = ${literal(test.profile)}::uuid;`);
  return test;
}
const update = (test) => `select public.phase2_update_profile_details(
  ${literal(test.user)}, 'US', 'US-ALL', 'ken', 'master',
  null::smallint, 1800, 'race-details', repeat('d', 64));`;
const anonymize = (test) => `
  select public.phase2_request_account_deletion(
    ${literal(test.user)}, 'race-delete', repeat('e', 64));
  select public.phase2_prepare_account_anonymization(
    ${literal(test.user)}, ${literal(test.digest)}, 'race-anonymize', repeat('f', 64));
`;
const history = (test) =>
  query(`select jsonb_agg(to_jsonb(history) order by history.id)::text
    from public.rating_history as history where profile_id = ${literal(test.profile)}::uuid;`);
function assertAnonymized(test, beforeHistory) {
  assert.equal(
    query(`select account.account_status = 'anonymized'
      and account.auth_user_id is null and not profile.is_public
      and profile.country_code is null and details.broad_region_code is null
      and details.main_character_code is null and details.current_sf6_rank is null
      and details.current_sf6_rank_tier is null and details.current_master_rating is null
      from public.profile_accounts as account
      join public.profiles as profile on profile.id = account.profile_id
      join public.profile_private_details as details on details.profile_id = profile.id
      where profile.id = ${literal(test.profile)}::uuid;`),
    "t",
    "A concurrent details update must not restore anonymized personal information",
  );
  assert.equal(
    history(test),
    beforeHistory,
    "Deletion must preserve rating history",
  );
  assert.equal(
    query(`select json_build_object(
      'rating', current_rating, 'placement', placement_status,
      'count', placement_completed_count)::text from public.profiles
      where id = ${literal(test.profile)}::uuid;`),
    test.ratingState,
    "Profile mutations and deletion must not change the rating/placement snapshot",
  );
  assert.equal(
    query(`select count(*) from public.placement_initializations
      where profile_id = ${literal(test.profile)}::uuid;`),
    "1",
    "Concurrent operations must preserve the single placement initialization",
  );
}

try {
  // Deletion owns both locks before the update starts. The old RPC reads active
  // and blocks on the private-details row; the fixed RPC waits before that read.
  const deletedFirst = fixture();
  const beforeDeletion = history(deletedFirst);
  const deletion = new Session(`profile-race-delete-${deletedFirst.user}`);
  const lateUpdate = new Session(`profile-race-update-${deletedFirst.user}`);
  await deletion.sql(`set application_name = ${literal(deletion.name)};
    begin;
    select private.phase2_lock_account(${literal(deletedFirst.profile)});
    select profile_id from public.profile_private_details
      where profile_id = ${literal(deletedFirst.profile)}::uuid for update;`);
  await lateUpdate.sql(`set application_name = ${literal(lateUpdate.name)};`);
  const updateOutcome = lateUpdate.sql(update(deletedFirst)).then(
    () => ({ succeeded: true }),
    (error) => ({ succeeded: false, error }),
  );
  await waitBlocked(lateUpdate, deletion);
  await deletion.sql(`${anonymize(deletedFirst)} commit;`);
  const outcome = await updateOutcome;
  await deletion.close();
  await lateUpdate.close();
  // Check data first: the original definition commits a successful PII restore.
  assertAnonymized(deletedFirst, beforeDeletion);
  assert.equal(
    outcome.succeeded,
    false,
    "An update after deletion must be rejected",
  );
  assert.match(lateUpdate.errors, /active_account_required/);
  console.log(
    "Profile details/deletion: PASS (deletion first, late update rejected)",
  );

  // Update owns the account lock first. Deletion waits until the updated details
  // commit, then anonymizes that committed state without losing history.
  const updatedFirst = fixture();
  const beforeUpdate = history(updatedFirst);
  const firstUpdate = new Session(`profile-race-first-${updatedFirst.user}`);
  const laterDeletion = new Session(`profile-race-later-${updatedFirst.user}`);
  await firstUpdate.sql(`set application_name = ${literal(firstUpdate.name)};
    begin; ${update(updatedFirst)} ${update(updatedFirst)}`);
  await laterDeletion.sql(
    `set application_name = ${literal(laterDeletion.name)};`,
  );
  const deletionOutcome = laterDeletion.sql(anonymize(updatedFirst)).then(
    () => ({ succeeded: true }),
    (error) => ({ succeeded: false, error }),
  );
  await waitBlocked(laterDeletion, firstUpdate);
  await firstUpdate.sql("commit;");
  assert.equal((await deletionOutcome).succeeded, true);
  assert.equal(await firstUpdate.close(), 0);
  assert.equal(await laterDeletion.close(), 0);
  assertAnonymized(updatedFirst, beforeUpdate);
  assert.equal(
    query(`select count(*) from private.domain_action_receipts
      where actor_profile_id = ${literal(updatedFirst.profile)}::uuid
        and action_scope = 'phase2.profile.details';`),
    "1",
    "A repeated details update must commit only one idempotency receipt",
  );
  console.log(
    "Profile details/deletion: PASS (update first, deletion serialized)",
  );
} finally {
  for (const session of sessions) session.child.stdin.destroy();
  await Promise.all([...sessions].map((session) => session.done));
  // Remove only this run's synthetic fixtures in the disposable local database.
  for (const test of fixtures) {
    if (!test.profile) {
      query(`delete from auth.users where id = ${literal(test.user)}::uuid;`);
      continue;
    }
    query(`begin; set local session_replication_role = replica;
      delete from private.domain_action_receipts where actor_profile_id = ${literal(test.profile)}::uuid;
      delete from private.action_rate_limits where actor_key = ${literal(test.user)};
      delete from private.sf6_user_code_claims where code_digest = ${literal(test.digest)};
      delete from private.deleted_user_code_reclaims where deleted_profile_id = ${literal(test.profile)}::uuid;
      delete from private.account_deletion_jobs where profile_id = ${literal(test.profile)}::uuid;
      delete from public.rating_history where profile_id = ${literal(test.profile)}::uuid;
      delete from public.placement_initializations where profile_id = ${literal(test.profile)}::uuid;
      delete from public.profile_sf6_identities where profile_id = ${literal(test.profile)}::uuid;
      delete from public.profile_private_details where profile_id = ${literal(test.profile)}::uuid;
      delete from public.profile_accounts where profile_id = ${literal(test.profile)}::uuid;
      delete from public.profiles where id = ${literal(test.profile)}::uuid;
      delete from auth.users where id = ${literal(test.user)}::uuid;
      commit;`);
  }
}
