import "server-only";

import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";

const retryJobSchema = z.object({
  job_id: z.uuid(),
  profile_id: z.uuid(),
  auth_user_id: z.uuid(),
  status: z.enum(["auth_delete_pending", "failed"]),
  attempt_count: z.number().int().nonnegative(),
});

/**
 * Trusted retry entrypoint for a worker/Admin workflow. Phase 2 deliberately
 * does not expose this to browser roles or schedule hosted automation.
 */
export async function retryAuthAccountDeletion(profileId: string) {
  const admin = createAdminClient();
  const jobResult = await admin.rpc("phase2_retryable_auth_deletion_job", {
    requested_profile_id: profileId,
  });
  if (jobResult.error) throw new Error("Deletion job is not retryable");
  const job = retryJobSchema.parse(jobResult.data);

  const deletion = await admin.auth.admin.deleteUser(job.auth_user_id);
  if (deletion.error && deletion.error.code !== "user_not_found") {
    await admin.rpc("phase2_mark_auth_deletion_failed", {
      requested_job_id: job.job_id,
      requested_error_code: deletion.error.code ?? "auth_delete_failed",
    });
    throw new Error("Auth deletion retry failed");
  }

  const completed = await admin.rpc("phase2_mark_auth_deletion_complete", {
    requested_job_id: job.job_id,
  });
  if (completed.error) throw new Error("Unable to complete deletion job");
  return { jobId: job.job_id, status: "completed" as const };
}
