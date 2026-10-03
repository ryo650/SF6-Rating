# Phase 2 — Independent Review

Review date: 2026-08-20
Current gate (2026-10-03): P1 remediation is implemented in an isolated local worktree; independent closure review and Production verification remain pending. Earlier completion results below are historical.
Branch: `phase/2-account-onboarding`
Scope: Spec compliance、correctness、security、data integrity、Auth / authorization、privacy、account deletion、regression、UX / accessibility

## 1. Review Sequence

1. Implementation後に、実装時の前提を引き継がないfresh reviewを実施した。
2. 初回findingのCritical / ImportantをCodexが修正した。
3. targeted testsとfull local verificationを実行した。
4. fresh re-reviewで残ったImportantを再修正した。
5. 最終static re-reviewを実施し、残るfindingとverification gapを分離した。

## 2. Initial Review

Result: Critical 0 / Important 9 / Minor 3。

| Severity | Finding | Disposition |
| --- | --- | --- |
| Important | deletion job / receipt / rate-limitにPII / Auth IDが残る | anonymization時のreceipt・rate-limit scrub、Auth削除完了時のjob Auth ID null化、constraint追加で修正 |
| Important | live / deleted SF6 User Code claimがatomicでなくdigest bindingも不足 | private claim ledger、live/reclaim single-owner、HMAC digest binding、transactional transferで修正 |
| Important | User Code reclaim releaseにAdmin監査境界がない | active Admin限定、idempotency、audit log付きRPCを追加 |
| Important | SF6 Identity変更とActive Match参加が同じaccount lockを共有しない | advisory account lockとparticipant triggerを追加 |
| Important | browser uploadを許しserver image processingを迂回できる | Storage mutation policyを削除し、server-only uploadへ限定 |
| Important | Next Server Action既定body limitで5 MB仕様へ到達できない | `serverActions.bodySizeLimit`を6 MBに設定し、decoded inputは5 MBで検査 |
| Important | AccountとAvatar pointer確定がatomicでない | combined Account RPCとserver-staged processed objectへ変更 |
| Important | mutable `user_metadata`のOAuth Avatar URLを信用する | mutable metadata経路を廃止し、後続re-reviewで安全なprovider identity候補を復元 |
| Important | completionがfresh Starting Rating previewを要求しない | HMAC preview tokenとDB parameter version再検査を追加 |
| Minor | base-table grantでprojectionを迂回し得る | column grantへ縮小 |
| Minor | deletion blockerの表示が不足 | localized blocker summaryを追加 |
| Minor | error localization / association不足 | localization追加。field単位の関連付けはMinorとして残存 |

## 3. Re-review

Result before second remediation: Critical 0 / Important 4 / Minor 3。

| Severity | Finding | Disposition |
| --- | --- | --- |
| Important | content-hash Avatar pathと全asset列挙cleanupがlive objectを消し得る | action-key + content hashのimmutable path、DBが返すexact prior pathだけのcleanup、RPC error時は削除しない方式へ変更 |
| Important | deletion requestとMatch participant activationのrace | deletion requestもshared account lockを取得し、activeでないaccountのparticipant insert / reactivationをtriggerで拒否 |
| Important | OAuth candidate要件を削除してsecurity findingを閉じていた | `user.identities`だけを参照し、Google / Discord host allowlist、authenticated proxy、server fetch、decode / re-encode後の内部Storage保存を追加 |
| Important | review fixがcommit済みPhase 2 migration番号を変更 | 旧版適用後にも進めるforward補正migration `20260817000400`を追加し、legacy overload / RLS / ledger / deletion scrubを補正 |
| Minor | completion resultが画面に残らない | Starting Rating / Placement completion summaryを追加 |
| Minor | form errorがfieldと関連付かない | 未解消。下記Minor findingへ継続 |
| Minor | opponentがUser Code変更timestampをbase grantで読める | authenticated column grantからtimestampを除外 |

## 4. Final Result

- Critical remaining: 0
- Important remaining: 0
- Targeted closure reviewでは、OAuth revisitの自動上書き、triggerのservice-role boundary、不正なMatch enum test、OAuth internal-asset constraintを追加検出した。すべて修正し、最終narrow reviewでclosedを確認した。
- Minor remaining: pre-RPC Avatar staging orphanとfield-level error associationの2件。current Avatarを消すcleanupは行わず安全側に倒しており、Product / authorization stateを変えないためPhase 2 gateを単独ではblockしない。
- Verification: **PASS**。clean 001〜004 install、Phase 1 pre-upgrade 68 tests、Phase 1→Phase 2 001〜004 apply、full post-upgrade pgTAP 150 tests、Phase 2 82 tests、両concurrency、Auth/Mailpit、Playwright、DB lint、types stability、`npm run verify`、secret scanがpassした。Phase 1互換fixtureは公開投影のtest intentを維持したまま、Phase 2では内部`avatar_assets`参照を持つ有効なOAuth Avatar状態を作るよう補正した。
- Human Action Points: Preview / StagingのGoogle / Discord / hosted Email / redirect / Stable Branch smokeは2026-08-26に完了した。残るHuman Actionは、別Production Supabase project、Production専用provider / SMTP credentials、sender-domain認証、Production redirect / Vercel設定とproduction smokeである。
- PR readiness: **Ready**。Critical / Important 0、Minor 2、全local Completion GateがPASSした。

## 5. Review Boundary

Local review時点では実Google / Discord account、hosted Email delivery、Vercel Preview、Hosted Supabase設定を静的contractまで確認した。その後のPreview / Staging hosted smokeはSection 7に追記した。Production環境はreview boundary外であり、未構築をcode defectとして数えない。

## 6. Preview Auth Callback Follow-up — 2026-08-23

Hosted provider smokeで、OAuth開始・callback完了の両方が固定`APP_BASE_URL`を使うため、Vercel Previewのaccess hostとPKCE cookie / redirect hostが分かれ得る問題を確認した。Productionはcanonical `APP_BASE_URL`固定を維持し、Previewは実request originが`VERCEL_URL`または`VERCEL_BRANCH_URL`と完全一致する場合だけ採用、Developmentはloopbackだけを採用するresolverへ変更した。Auth callback用env検証をservice-role / reclaim pepper検証から分離し、callback / Email confirmの例外をsafe error redirectまたはno-store 400 fallbackへ変換した。

回帰testはGoogle / Discord OAuth URL、Email verification / resend / password reset URL、Production / Preview / Development origin matrix、forwarded host偽装、PKCE exchange成功 / Auth error / SDK throw / unsafe-origin fallbackを対象とした。final PR headの`npm run verify`（Vitest 70/70、production buildを含む）、local Auth / Mailpit integration、Playwright desktop 5/5・mobile 4/4（full lifecycle 1 intentional skip）がPASSした。この時点で未実施だった実provider credentialを使うVercel Preview smokeは、Section 7のfollow-upで完了した。

## 7. Hosted External Integration Follow-up — 2026-08-26

Preview / Staging専用Supabase projectとVercel Stable Branch URLで、Google OAuth、Discord OAuth、Email + Passwordをfresh hosted evidenceとして確認した。

- Hosted DB prerequisite: forward migration `20260825000100`の適用後、Active Season 0件で`active_season_required`とatomic no-op、Preview Validation Season bootstrap後にcompletion、Starting Rating / Placement / Rating History、retry idempotencyを確認した。
- Google / Discord: provider認可、Supabase callback、Stable Branchへの復帰、session作成、onboarding redirect、reload persistenceがPASSした。Discordの最初の試行は認可画面で長時間待機したためOAuth state期限切れとなったが、即時再試行で成功し、設定・code defectとして再現しなかった。
- Email verification: Preview専用Mailtrap Email Sandboxでsignup、verification delivery、verification callback、sessionを確認した。Hosted Auth settingsは`mailer_autoconfirm=false`であり、verification必須contractを維持していた。
- Resend / recovery: resend、forgot password、recovery delivery、update-password callback、password update、新password sign-in、reload persistenceがPASSした。
- Invalid link: 再送で無効化された古い確認リンクはlocalized `/ja/auth-error`へ遷移した。Vercelでは同pathが200、Warning / Error / Fatal 0で、fragment内のAuth error、email、OTP、token、secretはserver logへ送信されなかった。
- Redirect: 成功flowはStable Branch hostを維持し、Production URLへの遷移やPKCE / session cookie host分離は観測されなかった。
- Logs: Email flowでは想定外Auth / Vercel error 0。Discord callback直後に一度だけretryable fetch warningがあったが、即時retry後は再現せず結果への影響もなかったためinformational observationとする。
- Environment boundary: Mailtrap Sandboxとtest usersはPreview / Staging専用。Productionは別Supabase projectと別SMTP credentialを使う。Production sender-domain、SPF / DKIM / DMARC、実mailbox deliverabilityは未検証のHuman Actionである。

Hosted follow-up後もclassificationはCritical 0 / Important 0 / Minor 2。既知Minorはpre-RPC Avatar staging orphanとfield-level ARIA error associationであり、今回のAuth smokeによる新規blocking findingはない。PR #2はexternal integration evidence上もreview readyであり、main mergeは未承認のまま維持する。

## 8. Profile Details / Deletion Follow-up — 2026-10-03

PR #2の[P1 review thread](https://github.com/ryo650/SF6-Rating/pull/2#discussion_r3859841688)は未解決・non-outdatedである。`phase2_update_profile_details`がactive状態を確認してからprivate detailsのrow lockを待つ間に匿名化がcommitすると、その後の更新でCountry / Region / Character / Rank / MRを復元し得る。隔離したPostgreSQL 17.6で旧定義が実際にこの競合を起こし、PII非復元のregression assertionにFAILした。本番での悪用・データ露出を確認したものではない。

Forward migration `20261003000100_phase2_profile_details_deletion_lock.sql`は、既存RPCのactor解決直後、rate-limit / receipt / active状態検査より前に共通account lockを取得する。既適用migrationを変更せず、署名、security definer、search_path、execute grants、validation、idempotencyの既存契約を維持する。

`scripts/test-phase2-profile-deletion-concurrency.mjs`は、Dockerのlocal Unix socketと対象projectのcontainer-local PostgreSQL socketを検証してからsynthetic fixturesを作成する。Deletion先行ではaccount / private-details locksを保持し、更新RPCのDB待機を確認した後に匿名化をcommitする。Update先行では更新と同じ要求のretryを保持し、削除RPCの待機を確認してからcommitする。両順序で匿名化後PII null、Rating / Placement snapshotとHistory保持、single initializationを検査し、retryは1 receiptのみを残す。固定sleepによる競合順序の推測は行わない。既存`db:test`へ追加した。

Local evidence（未commit worktree、baseline `c64c7c5c427b51e6d0254b9029bc4cbe7560fc1d`）:

- 旧定義: PII非復元assertionでFAIL。修正後: 両競合順序PASS。
- 既存Phase 2からのforward applyとRPC署名 / 属性 / ACL不変: PASS。
- pgTAP: upgrade後とapplication schemas再構築後、各5 files / 160 tests PASS。
- Phase 1 / Phase 2既存concurrency、DB lint、`npm run verify`: PASS（Vitest 70/70、production buildを含む）。
- Clean検証は、専用DBの`public` / `private`を再構築して同じschema owner / ACLを復元し、全migrationとlocal seedを適用したもの。Supabase platformのAuth / Storage / extensions prerequisitesは保持しており、通常のfull CLI clean-reset後の全stack検証とは区別する。

Local runtime上の制約: Supabase CLI startと旧版resetがport公開を`0.0.0.0`へ設定する挙動を検出し、その都度今回のtest projectだけを停止した。以後は明示`127.0.0.1:55322`の専用DBとcontainer-local socketのみを使用し、CLI start/resetは再使用しない。独立reviewへのhandoffに操作時刻、port、seed-onlyだった範囲と接続観測の限界を記録する。Auth / Mailpitとdesktop/mobile browser全stack検証は未実施。本番 / Preview DB、既存local DB、Provider / Secret設定、domain、Season、PR merge、公開範囲への変更はない。

Disposition: **Local remediation ready for independent review; P1 closure / Phase 2 Complete / Release approvalは未成立**。新候補のreviewed HEAD、本番forward migrationの別承認、P4-A/B/C再検証、Production Google Client ID修正と最終Human Gateは引き続き必要である。
