# Phase 2 — Account & Onboarding Human Review Packet

Prepared: 2026-08-20
Updated: 2026-08-26（Hosted External Integration Verification）
Branch: `phase/2-account-onboarding`
Planning baseline: `38e6715aa37c2a005d9d98ebe8e6392c0a6bf157`

## Layer 1 — Decision Dashboard

### Change Summary

Phase 2のAccount lifecycleをlocal implementationとして完成させた。Supabase Auth、Email verification / reset、Google / Discord entry、Auth callback / SSR session、Auth user ↔ immutable Public User ID provisioning、3-step onboarding、Username / SF6 identity / master data、Starting Rating / Placement、Avatar、Profile edit、deletion / anonymization、RLS / rate limit、ja/en、mobile / accessibility testsを含む。

Preview / Staging専用Supabase projectにはPhase 2 migrationとPreview Validation Seasonを適用し、Google / Discord / Email AuthをStable Branch URLで検証した。Email deliveryはPreview専用Mailtrap Email Sandboxを使用する。Production Supabase、Vercel Production、main merge、Phase 3は変更していない。

### 🔴 Human Review Required

| Decision / Evidence | Impact | Reversibility | AI Confidence | Required action |
| --- | --- | --- | --- | --- |
| Production Auth / SMTP bootstrap | High。Productionでの認証・到達性境界 | Medium | High（Preview contract）/ Low（Production未構築） | 別Supabase projectと別SMTP credentialを用意し、provider、redirect、sender-domain、SPF / DKIM / DMARCを正式設定 |
| Production runtime smoke | High。cookie / callback / env境界 | High。Preview / deployment単位で切戻し可能 | High（Stable Branch evidence）/ Low（Production未構築） | Production環境構築後にGoogle / Discord / Email、ja/en、desktop/mobileを再smoke |

### Blockers

- Product / Decision blocker: 0
- Code implementation blocker: 0
- Completion evidence blocker: 0
- External integration blocker: 0（Preview / Staging hosted smoke完了）。Production rolloutはPhase 2 PR completionとは別のHuman Action

### Security Critical Remaining

0。

### Security Important Remaining

0。最終targeted closure reviewでCritical / Important 0を確認した。

### Verification Status

| Gate | Status | Evidence |
| --- | --- | --- |
| lint / Prettier / typecheck / Vitest / production build | PASS on final PR head | `npm run verify`; 16 files / 70 tests、Next production build pass |
| secret scan | PASS after final fixes | tracked / untracked sourceに該当pattern 0 |
| clean DB + full pgTAP | PASS | clean 001〜004 install成功。full pgTAP 5 files / 150 tests pass |
| Phase 1 → Phase 2 upgrade | PASS | Phase 1 reset、Phase 1 pgTAP 68/68、001〜004 forward apply、full post-upgrade pgTAP 150/150、Phase 2 pgTAP 82/82 |
| concurrency / idempotency | PASS | Phase 1 claim race、Phase 2 completion / Username / User Code / Active Match / deletion-Match lock |
| RLS / DB lint | PASS | Phase 2 schema/action/RLS 82 tests、service-role trigger regression、DB lint warning 0 |
| Local Auth / Mailpit | PASS | verification、password reset/update、provisioning、session、onboarding、Auth deletion |
| Browser E2E / axe | PASS WITH INTENTIONAL SKIP | desktop 5/5、mobile 4/4、mobile full lifecycle 1 intentional skip。full lifecycleはdesktopでpass |
| generated DB types | PASS | 2-run hash stable: `8fa7848e611e94be358777d83ae039fe6f77b03e1c81709ee1c92bb6a8138b3e` |
| Google / Discord / hosted Email / Vercel Preview | PASS | Stable BranchでGoogle / Discord callback・session、Mailtrap SandboxによるEmail verification / resend / recovery / password update / sign-in、invalid-link errorを確認 |

### AI Recommendation

Final VerificationとPreview / Staging Hosted External Integration Verificationは**PASS**。Critical / Importantは0、既知Minorは2。PR #2は外部integration evidenceを含めてreview可能である。main merge、Production project bootstrap、Production provider / SMTP / Vercel設定は別途Human approvalを必要とする。

## Layer 2 — Review Summary

### 🟡 Review Recommended

Humanは全コードではなく、次を優先して確認する。

1. Email signup → verification → 3-step onboarding → completion summary。
2. Google / Discord entry、deny / callback error、provider Username / Avatar candidate。
3. Profile公開値と非公開値の境界。
4. Active Match / unresolved stateがある削除pending表示と、解消後の削除。
5. mobileでのform、focus、error、Rating preview invalidation。

### Security Summary

- Browser direct table / Storage mutationはdeny。service-roleはserver-only moduleに限定。
- Auth callback originはProductionでは`APP_BASE_URL`へ固定し、Previewでは実request hostとVercel system URLの完全一致、Developmentではloopbackだけを許可する。relative safe next、private / no-store responseを維持し、origin / exchange例外はerror redirectまたはfail-closed fallbackへ送る。
- UsernameはNFKC + pinned full case fold、DB unique。User Codeは10 digits + HMAC claim ledger + DB unique。
- AvatarはJPEG / PNG / WebPをdecodeし、animation / SVG / oversized / excessive pixelsを拒否、metadata除去・square WebPへ再encode。
- Avatar replacementはimmutable request pathを使い、transactionが返すexact prior pathだけをcleanupする。
- deletionはMatch participantとshared account lockを使い、PII / receipt / rate identifierをscrubし、Auth deletionをretry可能に分離。

### Risk Summary

High-riskはAuth callback/session、RLS / service-role、SF6 identity uniqueness / cooldown、Active Match lock、completion transaction、Avatar pointer、deletion / anonymization。既知Critical / Importantは0で、targeted gateとfull regressionの両方がpassした。

### Verification Summary

最終worktreeに対してclean 001〜004 install、Phase 1 pre-upgrade 68 tests、Phase 1→Phase 2 001〜004 upgrade、full post-upgrade pgTAP 150 tests、Phase 2 82 tests、concurrency、Auth/Mailpit、Playwright、DB lint、types stability、`npm run verify`、secret scanがpassした。Phase 1 Avatar fixtureはPhase 1の公開投影test intentを維持し、Phase 2適用後だけ内部Asset参照を作る互換fixtureへ更新した。

### Independent Review Summary

初回 Critical 0 / Important 9 / Minor 3。修正後re-review Critical 0 / Important 4 / Minor 3。targeted closureでOAuth revisit、trigger service-role、concurrency fixture、OAuth asset constraintも修正し、最終結果はCritical 0 / Important 0 / Minor 2。詳細とdispositionは`docs/reviews/phase-2-independent-review.md`を参照。

### Remaining Human Action Points

1. Production用の別Supabase projectを作成し、migration、Season、Site URL、redirect allowlistを正式bootstrapする。
2. Production専用Google / Discord credentialsとSMTP credentialsを秘密管理し、Preview / Staging credentialを再利用しない。
3. Production sender domainのSPF / DKIM / DMARC、実mailbox到達性、template、expiry、rate limit / abuse monitoringを検証する。
4. Production Vercel環境を構築後、Google / Discord / Email、ja/en、desktop/mobileを再smokeする。
5. Preview smokeで作成したtest users / test rating historyはPreview / Staging内に限定し、必要なcleanupは承認済みrunbookで行う。

## Layer 3 — Evidence

### Detailed Tests

- Unit: Unicode case fold、grapheme、Username characters、User Code normalization、Player Name controls、safe redirect、feedback localization、environment、Supabase client、Avatar decode / formats / animation / SVG / byte / pixel limits、provider identity / host allowlist。
- DB: master FK、10-digit identity、provisioning、Starting Rating v2、step idempotency、preview version、completion single initialization、cooldowns、active-match gate、RLS matrix、column privileges、Avatar pointer prior-path response、deletion blockers / anonymization / retry、claim / Admin release audit。
- Concurrency: duplicate completion、normalized Username、User Code claim、Active Match identity lock、deletion request vs late Match participant。
- Auth: Email verification、resend-compatible state、password reset/update/sign-in、Profile provisioning、onboarding completion、Auth admin deletion。
- Browser: ja/en desktop/mobile Auth + axe、safe callback error、protected route、Mailpit verification、step resume、preview invalidation、completion summary、settings persistence、deletion、old session rejection。

### Migrations / RLS Evidence

- `20260817000100_phase2_account_schema_and_masters.sql`: masters、constraints、Auth provisioning、Avatar/deletion/rate-limit schema、Starting Rating v2。
- `20260817000200_phase2_account_domain_actions.sql`: trusted RPC、normalization guards、idempotency、locks、completion、Profile / Avatar / deletion lifecycle。
- `20260817000300_phase2_account_rls_and_storage.sql`: default-deny RLS、projection grants、browser Storage mutation deny。
- `20260817000400_phase2_account_review_hardening.sql`: old Phase 2 migration適用後にもclaim ledger、PII scrub、RPC overload cleanup、locks、Avatar swap、RLS補正を適用するforward correction。
- `20260825000100_phase2_active_season_prerequisite.sql`: Active Season不在を`active_season_required`（SQLSTATE `55000`）へ変換し、汎用save errorと区別するforward migration。Preview / Stagingへ適用後、Season 0件failureとPreview Validation Season作成後のrecovery / idempotencyを確認した。

### Implementation References

- Auth / callback: `src/features/auth/`, `src/app/auth/`
- Account domain / queries / validation: `src/features/account/`
- Avatar pipeline: `src/features/avatar/`
- Onboarding / settings UI: `src/features/onboarding/`, `src/app/[locale]/(app)/`
- Database tests: `supabase/tests/database/`
- Local integration: `scripts/test-phase2-auth.mjs`, `scripts/test-phase2-concurrency.sh`, `e2e/phase2-account-onboarding.spec.ts`

Primary technical contracts were checked against Supabase SSR / Auth / RLS / Storage documentation and Next.js Server Action body-size documentation listed in the Phase 2 Implementation Plan.

### Minor Findings

- RPC確定前にstagingしたAvatarは、validation / rate-limit / idempotency errorでorphan objectとして残り得る。live pointer誤削除を避けるため同期cleanupはせず、将来のreconciliation / expiry cleanup対象とする。
- Server errors are localized and announced at form level, but field-specific `aria-errormessage` / `aria-invalid` mapping is incomplete。Impactはlocalized error後のscreen-reader navigation qualityで、authorization / persistence correctnessには影響しない。

### AI-owned Details

- Username normalization library / pinned lockfile、Player Name Unicode control rejection。
- Avatar: 16,777,216 input pixels、max 512 square、WebP quality 82、provider fetch 5 seconds、redirect deny。
- OAuth Avatar allowlist: Google `googleusercontent.com`、Discord `cdn.discordapp.com` / `media.discordapp.net`。provider URL取得失敗はdefault Avatarへfallback。
- Rate-limit初期値、stable error codes、client-side draft / idempotency key mechanics。
- Provider imageは継続同期せず、ownerが保存した内部assetとして扱う。

### Hosted External Integration Evidence — 2026-08-26

- Hosted DB prerequisite: migration `20260825000100`適用、Active Season 0件時のlocalized failure、Preview Validation Season bootstrap、同一userのcompletion recovery、Starting Rating / Placement / Rating History、retry idempotencyがPASSした。
- Google OAuth: PASS。Stable BranchからSupabase callbackを経てonboardingへ戻り、reload後もsessionを維持した。
- Discord OAuth: PASS。最初の試行は認可画面で約5分待機したためSupabase OAuth state期限切れとなったが、即時再試行ではcallback、session、onboarding、reload persistenceがすべて成功した。設定・code defectとしては再現しなかった。
- Email signup / verification: PASS。Preview専用Mailtrap Email Sandboxで新規確認メールを受信し、確認リンクからStable Branchのonboardingへ遷移した。`mailer_autoconfirm=false`、Email provider有効、送信rate limit 30 emails/hをread-only evidenceで確認した。
- Resend verification: PASS。未確認accountへの再送で新しい確認メールを受信した。
- Password recovery: PASS。recovery email、Stable Branchのupdate-password、password update、新password sign-in、reload後sessionを確認した。
- Invalid / expired link: PASS。再送前の古い確認リンクはlocalized `/ja/auth-error`へ安全に着地し、Vercel requestは200、Warning / Error / Fatalは0だった。URL fragmentはserverへ送信されず、Vercel logにemail、OTP、token、secretは記録されなかった。
- Redirect / session: 全成功flowはStable Branch host内に留まり、Production URLへの遷移やPKCE cookie host分離は観測されなかった。
- Hosted observation: Discord初回callback後に一度だけretryable fetch warningを観測したが、即時retryと以後のflowでは再現せず、Auth / session結果に影響しなかった。未解決Critical / Importantには分類しない。
- Boundary: Mailtrap SandboxはPreview / Staging専用であり、実mailbox deliverabilityやProduction sender-domain認証を証明しない。DB / migration、Google / Discord provider、redirect allowlist、Vercel environment、Auth templateはこのEmail smoke中に変更していない。

## Finish Gate

- Phase 2 implementation code: complete
- Preview / Staging hosted migration / bootstrap / Auth integration: verified
- Production mutation: none
- Verification: PASS
- PR #2: external integration evidence complete（未merge）
- main merge: not approved
- Phase 3: not started
