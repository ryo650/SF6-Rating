# Phase 2 — Account & Onboarding Implementation Plan

Status: Ready for Implementation
Planning date: 2026-08-17
Branch: `codex/phase-2-account-onboarding-decisions`
Scope: Planning only. This document does not apply migrations, change hosted Auth settings, or implement feature code.

## 1. Goal and Sources of Truth

Phase 1のnullable data foundationを、Google / Discord / verified Email + Password認証、3-step onboarding、Profile編集、Avatar、削除・匿名化までを含む安全なvertical sliceへ完成させる。Onboarding完了時には、Profile、Starting Rating、Placement状態、matching eligibilityが一貫して確定していることを目標とする。

競合時は次の順に解釈する。

1. `docs/features/README.md`の横断ルールと最も具体的なFeature Spec
2. `docs/phase-2-account-onboarding-decisions.md`
3. `docs/architecture.md`
4. `docs/product-spec.md`
5. 本計画と`docs/phase-2-account-onboarding-tasks.md`

参照した実装契約:

- `docs/features/account-profile.md`
- `docs/features/placement.md`
- `docs/features/public-profile.md`
- `docs/features/match-room.md`
- `docs/phase-1-data-foundation.md`
- `docs/implementation-plan.md`
- AI Development OS `os/feature-development.md`
- AI Development OS `templates/implementation-plan.md`
- AI Development OS `templates/tasks.md`
- AI Development OS `templates/decision.md`

Implementation時に再確認するnon-normative technical references:

- Supabase: [Server-Side Auth for Next.js](https://supabase.com/docs/guides/auth/server-side/creating-a-client?framework=nextjs&queryGroups=framework)
- Supabase: [Password-based Auth](https://supabase.com/docs/guides/auth/passwords)
- Supabase: [Google Auth](https://supabase.com/docs/guides/auth/social-login/auth-google) / [Discord Auth](https://supabase.com/docs/guides/auth/social-login/auth-discord)
- Supabase: [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- Supabase: [Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control) / [Storage Ownership](https://supabase.com/docs/guides/storage/security/ownership)
- Supabase: [Managing User Data](https://supabase.com/docs/guides/auth/managing-user-data) / [Delete a User](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser)
- Supabase: [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- Unicode Consortium: [Case Mapping FAQ](https://www.unicode.org/faq/casemap_charprop.html) / [Unicode Character Database](https://www.unicode.org/ucd/)

## 2. Decision Gate

2026-08-17にDecision Formalizationを再監査した。

- 承認済み9領域はAccount / Profile、Placement、Public Profile、Match Room、Architecture、全体Implementation Planへ反映済み。
- Phase 1のimmutable Public User ID、nullable Profile skeleton、public/private projection、default-deny RLS、idempotency receiptをforward migrationで拡張できる。
- Phase 2実装を止めるBlocking Human Decisionは0件。
- 残る実装詳細はAI-owned Assumption、後続Phase依存はFuture / Out of Scopeとして分類済み。
- 既存仕様間にPhase 2着手を妨げる矛盾はない。

したがってPhase 2は実装開始可能である。ただし、実providerを使う統合検証にはHuman Action Pointsの環境設定が必要になる。

## 3. Repository Investigation

### Existing foundation

- Next.js App Router、TypeScript、ja/en locale routing、Supabase browser/server client、session refresh proxyがある。
- Supabase migration、seed、pgTAP、Vitest、two-session concurrency testの基盤がある。
- `profiles.id`をimmutable Public User IDとして使用する。UsernameをURLや履歴参照keyにしない。
- `profiles`、`profile_accounts`、`profile_sf6_identities`、`profile_private_details`、`placement_initializations`にPhase 2向けnullable skeletonがある。
- browser roleの直接writeはdefault denyで、public、owner、active-match participant、admin用のread projectionが分離されている。
- `private.domain_action_receipts`とclaim / complete helperがあり、atomic / idempotent actionへ再利用できる。
- local AuthではEmail confirmationが現在無効である。Phase 2のlocal configでは有効化し、Mailpitで確認する必要がある。
- StorageのPhase 2用bucket / policy / image processingはまだない。
- Starting Rating parameter v1はMR範囲未確定の状態である。既存rowを破壊的に変更せずv2を追加する。
- Phase 1 fixtureの一部は12桁SF6 User Codeを使うため、10桁contractに合わせてPhase 2 forward tests / fixturesを更新する必要がある。

### Constraints on implementation

- 既存migrationを編集しない。すべてforward migrationとする。
- PostgreSQLをpersistent stateのSource of Truthとし、重要なmutationをtrusted Server / Database境界へ置く。
- Realtimeを確定状態のSource of Truthにしない。
- Supabase service-role keyはserver-only moduleからだけ利用し、browser bundleへ含めない。
- Auth accountの作成・provider identity・email verification・passwordはSupabase AuthをSource of Truthとする。

## 4. Proposed Approach

### 4.1 Trusted mutation boundary

BrowserからPhase 2 domain tableへ直接writeさせない。Server ActionまたはRoute Handlerがsessionを検証し、trusted RPC / transactionを呼び出す。

- 通常の認証済みqueryはSupabase SSR server clientを使う。
- 認可判断は検証済みclaimsを基準にし、email verificationや削除前の再認証など最新Auth状態が必要な箇所はSupabase Authへ再照会する。
- service-roleを必要とするAuth admin deletion等は、新しいserver-only admin clientに限定する。
- RPCへactor IDを渡す場合も、DB側でaccount mapping、status、ownership、current stateを再検証する。
- Idempotency keyはclient retryを許容しつつactor / action scopeへ結び付ける。
- Public / owner / active-opponentのreadは列を絞ったprojectionを使い、Client-side hidingだけへ依存しない。

### 4.2 Normalization and validation

Usernameはtrimした表示値と比較用normalized valueを分離する。trusted serverでNFKC、pinned Unicode versionのdefault full case folding、grapheme count、category validation、reserved-name checkを行い、DB unique constraintを最終競合guardとする。locale依存lowercaseをcase foldingの代替にしない。

SF6 User CodeはNFKC後に許可した空白・hyphen separatorだけを除去し、ASCII 10 digitsへcanonicalizeする。application validationに加えDB checkとunique constraintを置く。SF6 Player Nameはtrim、control / format拒否、1〜32 graphemeを初期値とし、重複を許可する。

Username / User Codeの30日cooldownはserver timeと確定変更timestampで判定する。Onboarding完了前のUsername修正はcooldownに数えない。Active Match中はPlayer NameとUser Codeの双方をtransaction内で拒否する。

### 4.3 Auth-to-profile provisioning

`auth.users`作成を契機に、同じAuth userへ一度だけ対応するProfile skeletonと関連rowを作るidempotent triggerを追加する。既存Auth userにmappingがない場合のbackfillもforward migrationに含める。

OAuth / Email callback後にProfile skeletonとonboarding statusを読み、未完了なら保存済みstep、完了済みならapp entryへ遷移する。callbackの`next`はlocal relative pathのallowlistで検証し、open redirectを防ぐ。

MVPでは独自Account Linking UIを作らない。provider identity競合はSupabase Authの結果を尊重し、情報を漏らさない汎用errorと既存sign-in / reset導線を返す。

### 4.4 Three-step onboarding

各stepは「次へ」でserverへ保存し、成功後のみ遷移する。未送信入力はClient stateで保持できるが復元保証はしない。

1. Account: Username、Avatar sourceまたはdefaultを確定する。
2. SF6 Player Info: Player Name、User Code、Country、Broad Regionを確定する。
3. Rating Setup: Main Character、SF6 Rank、rank tier、Master MRを確定し、Starting Rating previewを表示する。

最終Completionは1つのatomic / idempotent transactionで、active parameter versionのsnapshot、Starting Rating 1800〜2200 clamp、placement initialization、Profile rating / placement status、account onboarding completion / active status、public eligibilityを確定する。ClientからStarting Rating値を受け取って信用しない。

### 4.5 Avatar lifecycle

Avatar inputは5 MB以下のJPEG / PNG / WebPだけを受け付け、magic bytesとdecode結果を検証する。animated input、SVG、異常pixel count、decode bombを拒否する。EXIF orientation補正とmetadata除去後、中央1:1 crop、最大512×512、no-upscale、WebPへ再encodeする。

Storage pathはimmutable Public User IDとasset versionから構成する。ownerだけがupload / replace / deleteでき、object一覧や他者writeを許可しない。新objectを保存してからDB pointerをatomicに切り替え、旧objectはbest-effort cleanup queue / retry対象にする。OAuth avatarは信頼できるprovider metadataのHTTPS URLだけを初期候補とし、owner uploadを自動で上書きしない。

### 4.6 Account deletion state machine

削除requestはrecent authenticationを要求し、blocking dependencyをtransactionで検査する。Active Match、unresolved Result、Disputeがあれば`deletion_pending`にして新規Matchmakingを禁止し、解消に必要な操作だけを残す。

finalizerはidempotent jobとして次を実行する。

1. blocking dependencyを再検査する。
2. owned Storage objectを削除する。
3. SF6 User Codeのraw valueを消し、private reclaim ledgerへkeyed digestを保存する。
4. Profile / private data / identityを匿名化し、historyはimmutable Public User IDに匿名表示で残す。
5. app accessを失効させる。
6. server-only Auth admin clientでSupabase Auth userを削除する。
7. retry可能なjob statusと監査情報を確定する。

DB匿名化後にAuth削除が失敗してもapp mappingを再有効化せず、jobに必要最小限のAuth IDだけを保持して再試行する。User Code reclaim / releaseはAdminの監査対象actionだけにする。

## 5. Files and Components

以下は実装時の予定範囲であり、Repository Investigationで既存conventionに合わせて最終確定する。

### Create

- `supabase/migrations/*_phase2_account_schema_and_masters.sql`
- `supabase/migrations/*_phase2_account_domain_actions.sql`
- `supabase/migrations/*_phase2_account_rls_and_storage.sql`
- `supabase/tests/phase2_account_schema.test.sql`
- `supabase/tests/phase2_account_actions.test.sql`
- `supabase/tests/phase2_account_rls.test.sql`
- `scripts/test-phase2-concurrency.sh`
- `src/lib/supabase/admin.ts`
- `src/features/auth/*`
- `src/features/account/normalization.ts`
- `src/features/account/validation.ts`
- `src/features/account/actions.ts`
- `src/features/account/queries.ts`
- `src/features/account/rate-limit.ts`
- `src/features/onboarding/validation.ts`
- `src/features/onboarding/rating.ts`
- `src/features/onboarding/actions.ts`
- `src/features/onboarding/queries.ts`
- `src/features/avatar/*`
- `src/app/auth/callback/route.ts`
- `src/app/[locale]/(auth)/*`
- `src/app/[locale]/(app)/onboarding/*`
- `src/app/[locale]/(app)/settings/profile/*`
- `src/app/[locale]/(app)/settings/account/*`
- Phase 2 unit / integration / browser test files

### Modify

- `package.json` / lockfile for audited image processing and browser-test dependencies if required
- `supabase/config.toml` for local-only Auth verification and redirect contract
- `supabase/seed.sql` for managed country / region data where appropriate
- generated database types and database aliases
- `src/lib/supabase/client.ts`, `server.ts`, `proxy.ts` only where the Auth contract requires it
- ja/en messages, navigation, shared form / status styles
- `.env.example` and README setup documentation using variable names only
- `docs/implementation-plan.md`, `docs/tasks.md`, and verification evidence documents

### No planned deletion

Phase 1 migrations、RLS tests、idempotency helpers、history referencesは削除しない。

## 6. Data and Migration Plan

Forward migrationsは次をdependency順に追加する。

1. Country / Broad Region master tables、stable codes、active / deprecated state、display labels、FK、ISO alpha-2 constraints、全country fallbackと日本7区分seed。
2. Existing profile tablesのPhase 2 constraints / timestamps / indexes。SF6 User Codeはcanonical 10-digit checkを持つ。
3. Auth user → Profile skeleton provisioning triggerとsafe backfill。
4. Avatar asset metadataとStorage bucket / object ownership policy。
5. Username reserved-name data、named rate-limit state、account deletion job、private User Code reclaim digest ledger。
6. `starting-rating-v2`をMR 1〜5000で追加し、v1は許可された`is_active`変更だけでinactiveにする。
7. Step save、profile edit、onboarding completion、deletion request / finalization用trusted functions。
8. Public / owner / active-match / admin projectionsとRLS grantsの再検証。

Migrationはempty resetとPhase 1からのupgradeの両方をtestする。新しいmaster codeは表示名変更で変えず、inactive rowを履歴FKから物理削除しない。

## 7. Server / Action Contracts

実装時に具体的なtyped resultとerror codeを定義する。少なくとも次のaction境界を持つ。

- sign up、sign in、OAuth start、sign out、verification resend、password reset request / update
- Auth callback code exchangeとsafe redirect
- onboarding progress query / resume
- save Account step
- save SF6 Player Info step
- preview Rating Setup
- complete onboarding with idempotency key
- upload / replace / delete avatar
- update Username、SF6 identity、Country / Region、Rating profile inputs
- request account deletion
- retry / finalize eligible deletion
- Admin-only SF6 User Code reclaim / release boundary（Admin UIは後続Phase）

Domain errorsはja/enへ安全にmapできるstable codeを返し、unique conflict、cooldown、active-match lock、invalid master、unverified email、rate limit、stale stateを区別する。raw database error、provider secret、Email存在有無をClientへ漏らさない。

## 8. UI and UX Plan

- Auth画面: Google、Discord、Email / Password sign-up / sign-in、verification pending / resend、forgot password、update password、callback error、sign-out。
- Onboarding: 3-step progress、back / resume、server-save loading、field / form error、unique conflict、offline / retry、duplicate-submit protection。
- Account step: Username rules / availability結果、Avatar default / provider candidate / upload preview。
- SF6 step: Player NameとUser Codeの役割差、10桁入力補助、Country / managed Broad Region dependent select、privacy説明。
- Rating step: Character / Rank / tier / MR、1〜5000 validation、Starting Rating preview、Placement説明、final completion retry。
- Profile settings: public / private区分、cooldown next-eligible date、Active Match lock、Avatar change/delete、account deletion state / blockers。
- Public Profile:承認済みbaselineだけを表示し、private fieldはpayloadへ含めない。

すべてja/en、mobile-first、keyboard-only操作、visible focus、semantic label / error association、status announcement、44px相当のtouch target、reduced motion、十分なcontrastを確認する。OAuth / reset callbackはlocaleを保持し、不明localeを安全にdefaultへ戻す。

## 9. Authorization, RLS, and Abuse Boundaries

- Guest: public projectionだけをread可能。
- Authenticated owner:自分のowner projectionと許可されたtrusted actionだけを利用可能。
- Active Match opponent:既存contractの期間・match範囲に限りPlayer Name / User Codeをread可能。
- Admin:既存role contractに従う。reclaim / deletion retryは監査対象。
- Browser direct write:引き続きdeny。
- Service role:server-only、最小module、import boundary test、logへsecretを出さない。
- Storage: MIME declarationだけでなくcontent decodeを検証し、owner prefixとobject ownershipをpolicyで再確認する。
- Redirect: relative allowlist、origin固定、arbitrary URLを拒否する。
- CSRF / replay: SameSite cookie、Origin検査が必要なmutation、idempotency、one-time Auth codeの公式flowを利用する。
- Rate limits: Supabase Authのbuilt-in limitsに加え、application actionをactor / IP補助 / action名で制限する。初期AI-owned baselineはstep save 30回/5分、profile mutation 10回/時、avatar mutation 5回/時、deletion request 3回/日とし、設定可能にする。
- Logging: Email、raw SF6 User Code、password、OAuth token、service key、reclaim pepperをlogしない。

## 10. Human Action Points

以下はコードだけでは完了せず、実provider / Preview統合検証前に権限を持つHumanが行う。secret値そのものを文書やcommitへ書かない。

1. Google CloudでOAuth consent / clientを準備し、Client ID / Secretを対象Supabase environmentへ登録する。
2. Discord Developer Portalでapplication / OAuth credentialsを準備し、対象Supabase environmentへ登録する。
3. Supabase DashboardでGoogle / Discord providerを有効化し、Email / PasswordとEmail verification policyを確認する。
4. Supabase AuthのSite URLとRedirect URL allowlistへLocal、Vercel Preview、Productionの承認済みURLを登録する。
5. Google / Discord側にSupabase Auth callback URLを登録し、Local OAuthを検証する場合はlocal callbackも許可する。
6. SMTP sender、Email verification / password reset template、link expiry、delivery監視を設定する。
7. Vercel Preview / Productionへ公開Supabase URL / publishable keyと、server-only service-role key、User Code reclaim digest用pepperをsecretとして設定する。
8. Previewが接続するSupabase environmentとdata isolation方針を確認し、実user dataをtestへ使わない。
9. 実Google / Discord account、Email inboxを使うprovider別smoke testとVercel PreviewのHuman UX reviewを行う。

Human Actionが未完了でもlocal DB / Email / UI実装と大部分の自動testは進められる。実providerとPreviewのCompletion Gateだけは該当設定完了までpass扱いにしない。

## 11. Dependency-Ordered Vertical Slices

### Phase 2.1 — DB / Auth Foundation

Forward migration、masters、constraints、Auth provisioning、trusted action / admin boundary、types、RLS / Storage baseline、normalization / validation primitivesを作る。

### Phase 2.2 — Authentication Flow

Google、Discord、Email / Password、Email verification、resend、password reset、callback、safe redirect、SSR session、sign-out、Auth error stateを完成させる。

### Phase 2.3 — Onboarding Step 1: Account

Username normalization / uniqueness、pre-completion edit、Avatar default / provider candidate / uploadを、server saveとresumeまで縦に実装する。

### Phase 2.4 — Onboarding Step 2: SF6 Player Info

Player Name、10桁User Code、Country / Broad Region master、unique conflict、privacy、server save / resumeを実装する。

### Phase 2.5 — Onboarding Step 3 + Placement Initialization

Character / Rank / tier / MR、versioned Starting Rating preview、atomic / idempotent completion、Placement初期化、matching eligibilityを実装する。

### Phase 2.6 — Avatar and Profile Editing

Avatar replace / delete、Username / SF6 identity / region / rating inputsの編集、30日cooldown、Active Match lock、public / private projectionを完成させる。

### Phase 2.7 — Account Deletion and Anonymization

request / pending / blocked state、Storage cleanup、reclaim digest、anonymous history、Auth admin deletion、retry / recoveryを実装する。

### Phase 2.8 — Integration, Security, and UX Verification

local Supabase、Auth、RLS、concurrency、browser e2e、ja/en、mobile、accessibility、Vercel Previewをまとめて検証し、Independent ReviewのCritical / Important findingsを修正して再検証する。

各sliceは前のsliceに依存する。小さなtest utility以外は後続sliceを先行実装しない。

## 12. High-Risk Areas and Mitigation

### Authentication and session

Risk: callback redirect、stale / forged session、unverified Email、account enumeration、provider collision。

Mitigation: SupabaseのPKCE / SSR contract、verified claims、latest-state check、relative redirect allowlist、generic errors、provider別integration tests。

### RLS and trusted authorization

Risk: private Profile / SF6 identity / Broad Region漏えい、service-role露出、actor spoofing。

Mitigation: default deny、column projection、DB re-authorization、two-session tests、client bundle import test、negative permission matrix。

### SF6 identity and Username

Risk: normalization差、raceによるduplicate、cooldown bypass、Active Match中変更、deleted code即時再利用。

Mitigation: pinned normalization implementation、DB unique / check、server time、transaction lock、concurrency tests、private keyed-digest reclaim ledger。

### Onboarding completion transaction

Risk: Profileだけ公開、Ratingだけ作成、retryで二重初期化、parameter versionずれ。

Mitigation: single transaction、idempotency receipt、active parameter snapshot、row lock、failure injection / duplicate / concurrent completion tests。

### Account deletion

Risk: Storage ownershipによりAuth deletion失敗、部分匿名化、dependency見落とし、retry不能、history破損。

Mitigation: explicit state machine、dependency recheck、Storage先行cleanup、durable job、minimal Auth ID retention、idempotent retry、history invariant tests。

### Avatar processing

Risk: spoofed MIME、animated / malicious image、decode resource exhaustion、orphan object。

Mitigation: byte / magic / decode / pixel limits、server re-encode、metadata strip、owner policy、pointer swapとcleanup retry。

## 13. Verification Plan

原則としてCodex側で次を一括実行する。

`Implementation → Self Verification → Independent Review → AI-fixable Critical/Important fixes → Re-verification`

Human-only provider設定・credential投入・最終UX判断はHuman Action evidenceとして分離する。

### Self Verification

- Static: format、lint、typecheck、production build、client/server import boundary、secret scan。
- Unit: Username NFKC / case folding / grapheme / categories / reserved words、User Code normalization、Player Name、cooldown、rating formula / clamp、safe redirect、rate limit、avatar validation。
- Migration: empty `db reset`、Phase 1からforward upgrade、seed idempotency、generated types diff、no historical migration rewrite。
- pgTAP / DB integration: constraints、master FK、provisioning trigger、RLS matrix、public/private/active-opponent projection、trusted RPC authorization、cooldown、Active Match lock、reclaim ledger。
- Concurrency: duplicate Username / User Code、same-step retry、two-tab final completion、deletion duplicate / retry、avatar pointer race。
- Failure injection: completion途中errorで全rollback、Storage削除失敗、Auth deletion失敗、finalizer再実行、stale parameter / onboarding state。
- Local Auth: Email sign-up → Mailpit verification → session → Profile provisioning、invalid/expired verification、resend、password reset / update、sign-out、callback error。
- Browser e2e: 3-step save / back / reload / resume / duplicate submit、profile edit、cooldown、active-match block、avatar upload/delete、deletion pending / eligible paths。
- UX: ja/en、Desktop / narrow mobile、keyboard、focus order、labels / descriptions / errors、live status、contrast、reduced motion。

### Auth Integration Verification

- Local Email flowは自動化し、Mailpit APIまたはtest-safe inboxからverification / reset linkを取得する。
- Google / Discordはmockだけで完了扱いにせず、Human Action完了後に各providerでLocalまたはPreviewの実callbackを1回以上確認する。
- callback cookie、PKCE code exchange、locale / safe `next`、未完了onboarding resume、完了user redirectを確認する。
- provider denial、cancel、missing code、replayed code、unapproved redirectを確認する。

### Vercel Preview Verification

- Preview buildとruntime env validation。
- Google / Discord / Email callback URL、secure cookie、server-only key非露出。
- signup / verification / reset / sign-in / sign-out、3-step onboarding、Avatar、Profile edit、public privacy、deletion requestのsmoke。
- Preview URLでja/en、mobile、keyboard / screen-reader-friendly stateをHuman review。
- PreviewがProduction data / secretへ暗黙接続していないことを確認する。

### Independent Review

実装者と別のAI contextへ、Decision Record、Feature Specs、migration diff、RLS matrix、action contracts、test results、Preview evidenceを渡す。特にAuth、RLS、Account deletion、SF6 Identity、onboarding completion transactionをHigh-riskとして、security、data integrity、privacy、concurrency、rollbackをreviewする。

Critical / Important findingのうちコード・test・documentationで直せるものはCodexが修正し、影響範囲のtestsとfull gateを再実行する。Human credential、provider approval、Product intent変更だけをHumanへ戻す。Critical / Important未解決、未検証High-risk path、secret露出がある状態ではPhase 2をCompleteにしない。

## 14. Rollback and Recovery

- Applicationはbranch / commit revertとfeature entry disableでrollback可能にする。
- Migrationはdown migrationや既存file編集に依存せず、補正forward migrationを使う。
- `starting-rating-v2`に問題がある場合も過去snapshotを消さず、新version追加またはactive flagのforward fixを行う。
- New nullable table / columnは後続codeが未展開でもPhase 1 read contractを壊さない順でdeployする。
- Avatar pointerは新object確認後に切替え、失敗時は旧Avatarを維持する。
- Hosted deletion finalizerはHigh-risk gate完了前に有効化しない。匿名化 / Auth削除後は自動復元できないため、dry-run / fixtureで先に検証する。
- Account deletionの部分失敗はdurable jobから再試行し、手動DB修復を通常運用にしない。

## 15. Assumptions and Deferred Scope

### Non-blocking AI-owned assumptions

- Decision Record §5の11項目を実装defaultとする。
- Unicode case-fold data version、image library、exact pixel limit、password policy値は実装時点のsupport / security reviewで固定し、testsとdocsへ記録する。
- Application rate-limit初期値は§9のbaselineとし、observabilityを見て後から設定変更できる。
- Deletion finalizerはPhase 2でidempotent entrypoint / retry jobまで作り、後続Match / Result / Dispute actionが解消時に呼べるcontractを公開する。
- OAuth avatar取得失敗はdefault avatarへfallbackし、onboardingを止めない。

### Future / Out of Scope

- Custom Account Linking UI、X login、SF6 identity公式所有確認。
- Waiting中のRegion変更snapshot / matching挙動の最終実装（Phase 3）。
- Active Match UIでのidentity表示実装（Phase 4。Phase 2はread / edit gateを保証）。
- Public Match / Rating History UI、pagination、Username search（Phase 6）。
- Admin reclaim / moderation / legal-hold UI（Phase 8。Phase 2は安全なserver boundaryとledgerを用意）。
- Production rate-limit tuning、CAPTCHA導入判断、scheduled reconciliation運用、monitoring / alerting（Phase 9）。
- OAuth avatarの継続同期、advanced crop UI、animated image support。

### Blocking Human Decisions

なし。
