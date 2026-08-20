# SF6-Rating — MVP Execution Tasks

Status: Phase 2 Implementation Complete — Verification Gate Pending
Related plan: `docs/implementation-plan.md`

## 1. Goal and Rules

MVPを依存関係順に、各Phaseで検証・review可能な単位へ分解する。Phase 0はCodexがそのまま実行できる粒度、Phase 1以降は実装直前のRepository Investigationでファイルと詳細を確定できる粒度とする。

各Taskは不要なFeatureやrefactorを含めず、完了後に証跡を残す。各Phaseの最後は必ず次のGateを通す。

`Implementation → Self Verification → Independent Review → fixes if needed → Human Review → phase complete`

## 2. Phase 0 — Project Foundation

### P0-T01 — Runtime and Next.js scaffold

- [x] **Purpose:** Greenfield repositoryにsupportされたNext.js + TypeScript + App Routerの実行可能な土台を置く。
- **Changes:** repository rootをアプリrootとして初期化し、package manager/runtime version、lockfile、scripts、`src/app`、基本configを追加する。実装時点の公式support範囲を確認する。
- **Done Criteria:** clean install可能で、App Routerの最小pageがlocal serverで表示される。SF6固有Featureやdomain dataはない。
- **Verification:** fresh install、dev server smoke、runtime/version確認、git diff review。

### P0-T02 — Code quality configuration

- [x] **Purpose:** すべての後続Taskで同じ静的品質基準を使えるようにする。
- **Changes:** lint、format方針、strict TypeScript、`typecheck` script、import/path方針を設定する。
- **Done Criteria:** source/test/configが一貫して検査対象となり、警告を黙殺するblanket disableがない。
- **Verification:** lintとtypecheckを実行しpassを記録する。

### P0-T03 — Test foundation

- [x] **Purpose:** unit/component/server foundationを自動検証できる最小test harnessを用意する。
- **Changes:** Next.js/TypeScriptと互換性のあるtest runner、DOMが必要な場合のenvironment、coverage対象、最小smoke testを追加する。
- **Done Criteria:** 空の成功ではなく、基本layoutまたはpure utilityを実際に検証するtestがあり、watchなしでCI実行できる。
- **Verification:** test commandをclean環境で実行しpassを記録する。

### P0-T04 — Environment contract and secret safety

- [x] **Purpose:** Local/Preview/Productionの設定境界を明確にし、secret流出を防ぐ。
- **Changes:** browser公開値とserver-only値を区別した環境変数schema、`.env.example`、`.gitignore`、セットアップ説明を追加する。Supabase URLとPublishable keyを基本接続契約とする。
- **Done Criteria:** 必須値不足は理解可能なerrorになり、実secret値、service-role key、OAuth secretはtracked fileに存在しない。
- **Verification:** envあり/なしのtests、tracked filesとdiffのsecret scan、client bundle境界確認。

### P0-T05 — Supabase client/server foundation

- [x] **Purpose:** BrowserとServerで適切なsession/cookie境界を持つSupabase接続基盤を作る。
- **Changes:** browser client、server client、必要最小限のsession refresh/callback foundationを公式推奨方式で追加する。Feature queryやtableは追加しない。
- **Done Criteria:** client/server用途が分離され、server-only secretをbrowserへ渡さず、公開接続設定で初期化できる。
- **Verification:** client creation tests、server/client import boundary、local/Preview build、可能なら非破壊のconnection smoke。

### P0-T06 — Supabase CLI and migration workspace

- [x] **Purpose:** schemaをGit管理し、Phase 1以降で再現可能に変更できる場所を作る。
- **Changes:** Supabase CLI config、migrations/seed置き場、local start/reset/link/pushの安全な説明を追加する。既存remote schemaは変更しない。
- **Done Criteria:** directory conventionとcommandsが明確で、SF6 domain migrationはまだ存在しない。
- **Verification:** CLI config validation、file layout review、remoteにmigrationを適用していないことを確認する。

### P0-T07 — ja/en i18n foundation

- [x] **Purpose:** 最初から日本語/英語を同じrouting/rendering基盤で扱う。
- **Changes:** locale定義、message loading、default/fallback、locale-aware navigation、最小ja/en messageを追加する。
- **Done Criteria:** ja/en URLまたは同等の選択契約で基本pageが表示され、unsupported localeを安全に処理し、message key型/検証がある。
- **Verification:** ja/en render tests、unsupported locale test、browserでlocale切替と直リンクを確認する。

### P0-T08 — Base layout and generic app states

- [x] **Purpose:** 後続vertical sliceが再利用できるaccessibile/mobile-first shellを用意する。
- **Changes:** metadata、base layout、global styles、generic loading/error/not-found、focus/semantic baselineを追加する。
- **Done Criteria:** Desktop/Mobileで破綻せず、ja/en表示可能で、SF6固有navigation/Feature UI/仮dataはない。
- **Verification:** browser Desktop/Mobile、keyboard/focus、loading/error/not-found smoke、snapshot/component tests。

### P0-T09 — CI quality gate

- [x] **Purpose:** push/PRごとに最低限の品質低下を自動検知する。
- **Changes:** supported Node/package-manager cacheを使い、install → lint → typecheck → tests → production buildを実行するGitHub Actions workflowを追加する。
- **Done Criteria:** workflowが再現可能で、secretなしでも基礎checkが走り、必要な公開dummy/test envの扱いが説明される。
- **Verification:** workflow syntax review、local同等commands、GitHub上の成功run。

### P0-T10 — Vercel readiness and setup documentation

- [x] **Purpose:** GitHub連携したVercel Previewへ安全にdeployできる構成と手順を確立する。
- **Changes:** framework/build設定、環境変数一覧、Supabase/Vercel/OAuth callbackの環境別注意、local setup/commandsをREADMEまたはdocsへ記載する。
- **Done Criteria:** repository固有の手動手順が明確で、Previewがproduction secret/dataに暗黙依存しない。
- **Verification:** production build、Vercel Preview deploy、Preview ja/en smoke、secret exposure review。

### P0-T11 — Phase 0 completion gate

- [x] **Purpose:** Feature開発前にProject Foundationを独立して完成させる。
- **Changes:** 実装変更は原則行わず、不足があれば該当Taskへ戻して修正する。
- **Done Criteria:** local start、lint、typecheck、tests、production build、Supabase client/server foundation、`.env.example`、secret非commit、Vercel Preview、ja/en、CIがすべて確認済みで、SF6固有Featureがない。
- **Verification:** Self Verification → Independent Review → fixes → Human Reviewを実施し、commands/Preview URL/review findingsを記録する。

## 3. Phase 1 — Data Foundation

### P1-T01 — Repository and schema contract investigation

- [x] **Purpose:** Phase 0後の実構成と全Featureのdata責務を再確認する。
- **Changes:** canonical match terminology、ownership/publicity、transaction boundaries、ERD、migration order、open decisionsを計画へ反映する。
- **Done Criteria:** tableを無目的に先行作成せず、各fieldのownerとprivacy、Phaseが明確。
- **Verification:** Feature/Architecture traceability review。

### P1-T02 — Migration, constraints, indexes, and seed baseline

- [x] **Purpose:** empty環境から再現可能なDB foundationを作る。
- **Changes:** shared schema、FK/unique/check/index、active season/config seed、generated types workflowを依存順に追加する。
- **Done Criteria:** local resetとtest fixture作成が再現可能。
- **Verification:** migrate up/reset、constraint/index inspection、type generation diff。

### P1-T03 — RLS and trusted domain-action baseline

- [x] **Purpose:** default-denyとatomic/idempotent mutation patternを確立する。
- **Changes:** role別policies、public/private projection、server/RPC authorization pattern、transaction test harnessを追加する。
- **Done Criteria:** guest/user/owner/admin/service境界がpermission matrixと一致。
- **Verification:** RLS negative/positive integration tests、duplicate/concurrency tests。

### P1-T04 — Phase 1 gate

- [x] **Purpose:** Account実装前にdata foundationの整合性を確定する。
- **Changes:** review findingsのみ修正する。
- **Done Criteria:** migration/RLS/types/tests/docsがreview済み。
- **Verification:** Standard Phase Gate。

## 4. Phase 2 — Account & Onboarding

### P2-T01 — Resolve Account implementation decisions

- [x] **Purpose:** normalization、region、avatar、email、deletionのblocking設定を確定する。
- **Changes:** `docs/phase-2-account-onboarding-decisions.md`をAcceptedとして追加し、Product / Architecture / Account / Placement / Public Profile / Implementation Planを同期した。Feature code、migration、Auth provider設定は未変更。
- **Done Criteria:** Phase 2開始を止めるHuman Decisionがなく、残る詳細がAI-owned assumptionまたは後続Featureへ分類されている。
- **Verification:** Product / Architecture / Feature / Phase 1 contractのtraceability reviewとdocumentation diff。2026-08-17の最終監査でBlocking Human Decision 0を確認済み。

### P2-T02 — Execute DB / Auth foundation and Authentication Flow

- [x] **Purpose:** 必須authと安全なprofile lifecycleの共通基盤を実装する。
- **Changes:** 詳細Tasks P2.1〜P2.2。forward schema / masters、Auth provisioning、normalization、RLS / Storage、Google / Discord / Email、verification / reset、callback / session。
- **Done Criteria:** auth userから一意で権限適合したProfileを作成・復元でき、全必須Auth flowが共通callback contractを使う。
- **Verification:** `docs/phase-2-account-onboarding-tasks.md`のP2.1 / P2.2 Done Criteria。

### P2-T03 — Execute three-step onboarding slices

- [x] **Purpose:** Account、SF6 Player Info、Rating Setupをstep保存とatomic completionまで完成させる。
- **Changes:** 詳細Tasks P2.3〜P2.5。Username / Avatar、SF6 identity / Region、MR / Starting Rating / Placement initialization、resume。
- **Done Criteria:** Feature acceptance criteriaを満たし、retry / concurrencyでも1回だけ一貫してcompletionするend-to-end flowがある。
- **Verification:** `docs/phase-2-account-onboarding-tasks.md`のP2.3〜P2.5 Done Criteria。

### P2-T04 — Execute Profile editing and deletion slices

- [x] **Purpose:** Onboarding後のowner-controlled lifecycleを完成させる。
- **Changes:** 詳細Tasks P2.6〜P2.7。Avatar / Profile edit、cooldown / Active Match gate、deletion pending、anonymization、Auth deletion / retry。
- **Done Criteria:** private / public境界を保ち、active dependencyを壊さず、historyを匿名参照で保持できる。
- **Verification:** `docs/phase-2-account-onboarding-tasks.md`のP2.6〜P2.7 Done Criteria。

### P2-T05 — Phase 2 integration and review gate

- [ ] **Purpose:** Account sliceを完成させる。
- **Changes:** 詳細Tasks P2.8。Self Verification、Auth / Preview verification、Independent Review、AI-fixable Critical / Important fixes、再検証。
- **Done Criteria:** onboarding完了userがmatching eligibilityを持ち、High-risk領域の未解決Critical / Importantがない。
- **Verification:** `docs/phase-2-account-onboarding-tasks.md`のP2.8 Done CriteriaとStandard Phase Gate。

## 5. Phase 3 — Matchmaking

### P3-T01 — Matchmaking investigation and configurable rules

- [ ] **Purpose:** grouping、weights、heartbeat、rate limitsと既存schema適合を確定する。
- **Changes:** initial config/assumptionsと計測項目を記録する。
- **Done Criteria:** concurrency/privacyを含む実装契約が明確。
- **Verification:** spec/data review。

### P3-T02 — Waiting and match-creation domain slice

- [ ] **Purpose:** Quick/Manual双方を同じpoolから安全に成立させる。
- **Changes:** waiting/expiry/candidate/rated eligibility/cooldown/season cutoff/atomic match creation/audit。
- **Done Criteria:** competing requestsでも1 matchだけ成立し、stale candidateを拒否する。
- **Verification:** DB integration、concurrency、idempotency、permission tests。

### P3-T03 — Matchmaking UI and recovery slice

- [ ] **Purpose:** waiting/candidate/match-found体験を完成させる。
- **Changes:** global waiting、list、loading/empty/error、Realtime + refetch recovery、ja/en/mobile。
- **Done Criteria:** Quick/Find双方がFeature acceptance criteriaを満たす。
- **Verification:** 2-user browser tests、reload/sleep/multi-tab、privacy。

### P3-T04 — Phase 3 gate

- [ ] **Purpose:** Matchmaking sliceを完成させる。
- **Changes:** review fixes。
- **Done Criteria:** 1件だけのMatch成立とprivate data保護が証明済み。
- **Verification:** Standard Phase Gate。

## 6. Phase 4 — Match Room & FT3

### P4-T01 — Match Room/FT3 contract investigation

- [ ] **Purpose:** host algorithm、event retention、active-profile ruleとstate transitionを確定する。
- **Changes:** implementation decisionsとtest matrixを更新する。
- **Done Criteria:** canonical states/resolutionsと矛盾がない。
- **Verification:** cross-feature review。

### P4-T02 — Room domain actions and participant projection

- [ ] **Purpose:** host、events、state、recoveryをtrusted boundaryで実装する。
- **Changes:** participant-only view/actions、preset messages、host change、reporting transition、incident/cancellation entry。
- **Done Criteria:** unauthorized/duplicate/invalid transitionを拒否する。
- **Verification:** permission、state-machine、idempotency、Realtime recovery tests。

### P4-T03 — Match Room and FT3 UI

- [ ] **Purpose:** SF6内で迷わずRated FT3を開始・完了できる案内を提供する。
- **Changes:** roles、copy、timeline、trouble、resume、60-second Round Time guidance、ja/en/mobile。
- **Done Criteria:** 2ユーザーがMatch Foundからreporting入口へ到達できる。
- **Verification:** browser 2-session、reload/sleep、accessibility。

### P4-T04 — Phase 4 gate

- [ ] **Purpose:** Match Room/FT3 sliceを完成させる。
- **Changes:** review fixes。
- **Done Criteria:** Feature acceptance criteriaと60-second ruleを満たす。
- **Verification:** Standard Phase Gate。

## 7. Phase 5 — Result Reporting + Rating Core

### P5-T01 — Rating/Placement simulation and finalization contract

- [ ] **Purpose:** formula、rounding、caps、snapshots、unrated/forfeit choicesを実装前に固定する。
- **Changes:** pure model simulation、decision/config、transaction contractを更新する。
- **Done Criteria:** boundary examplesとexpected valuesがreview済み。
- **Verification:** formula/property/table tests。

### P5-T02 — Reporting and resolution domain slice

- [ ] **Purpose:** blind reports、mismatch、forfeit、cancellation、incident/nonresponseを安全に処理する。
- **Changes:** report/revision visibility、normalization、state actions、5/30分/24時間flow。
- **Done Criteria:** unauthorized data leakや競合二重確定がない。
- **Verification:** RLS、clock、concurrency、idempotency integration tests。

### P5-T03 — Atomic rating and placement finalization

- [ ] **Purpose:** confirmed Rated resultを一度だけ全関連recordへ反映する。
- **Changes:** match/result、rating history/current rating、season stats、placement count/multiplier/capを単一transactionで更新する。
- **Done Criteria:** retry/simultaneous submitで同一結果となり、Unrated/no-ratingではratingを変更しない。
- **Verification:** DB transaction/failure injection/formula tests。

### P5-T04 — Reporting/result UI slice

- [ ] **Purpose:** You/Opponent視点で誤入力しにくいblind reporting体験を完成させる。
- **Changes:** confirmation、pending、revision、dispute、forfeit、cancellation、rating delta、ja/en/mobile。
- **Done Criteria:** Feature acceptance criteriaを満たす。
- **Verification:** browser normal/error/mismatch/multi-tab/accessibility tests。

### P5-T05 — Internal MVP Golden Path E2E

- [ ] **Purpose:** 中心価値をPhases 0–5横断で証明する。
- **Changes:** deterministic fixturesと2-browser-session E2Eを追加する。
- **Done Criteria:** 新規ユーザー2人 → onboarding/Placement → Match → Match Room → Result → Rating/Placement/stats更新を完走し、DB期待値と一致する。
- **Verification:** clean DBでE2E、retry後のno-duplicate、active rated gate解除、ja/enとmobile代表経路。

### P5-T06 — Internal MVP checkpoint gate

- [ ] **Purpose:** Internal MVPを独立してreviewする。
- **Changes:** review fixesのみ。
- **Done Criteria:** Phases 0–5 regressionとGolden Pathがpassし、Critical/High issueが0件。
- **Verification:** Self Verification → Independent Review → fixes → Human Review。

## 8. Phase 6 — Public Profile + Ranking

### P6-T01 — Public contract investigation

- [ ] **Purpose:** history page size、username search scope、public/private fieldsを確定する。
- **Changes:** query/index/UI contractを調整する。
- **Done Criteria:** 公開projectionが列単位で明確。
- **Verification:** privacy/spec review。

### P6-T02 — Public profile and history slice

- [ ] **Purpose:** 確定済み公開情報とpaginated historyを提供する。
- **Changes:** public queries/RLS、overview/history/seasons shell、deleted/placement/empty states。
- **Done Criteria:** pending/disputed/private dataを表示しない。
- **Verification:** guest/user permission、pagination、mobile tests。

### P6-T03 — Active ranking slice

- [ ] **Purpose:** eligible playersをrating順・同順位ルールで表示する。
- **Changes:** ranking query/index、pagination/current-user context、UI。
- **Done Criteria:** source data、tie、placement eligibilityがspecと一致。
- **Verification:** ranking fixtures/performance/browser tests。

### P6-T04 — Phase 6 gate

- [ ] **Purpose:** Public Profile/Rankingを完成させる。
- **Changes:** review fixes。
- **Done Criteria:** public privacyとacceptance criteriaが満たされる。
- **Verification:** Standard Phase Gate。

## 9. Phase 7 — Seasons

### P7-T01 — Season operating decisions

- [ ] **Purpose:** schedule/name/recovery detailsを確定する。
- **Changes:** config、runbook、implementation contract。
- **Done Criteria:** active/upcoming season seedとownerが明確。
- **Verification:** operational/spec review。

### P7-T02 — Season lifecycle and rollover domain slice

- [ ] **Purpose:** cutoff、snapshot、soft reset、boundary closeをidempotentに実行する。
- **Changes:** lifecycle/job/progress/recovery、match attribution、transaction guards。
- **Done Criteria:** concurrent/retry/failure後もsingle active seasonと一意snapshot/resetを維持する。
- **Verification:** controlled-clock、failure injection、concurrency tests。

### P7-T03 — Season UI/public integration

- [ ] **Purpose:** current/closing/past season状態を一貫して表示する。
- **Changes:** profile/ranking integration、cutoff messaging、error/recovery-safe UI。
- **Done Criteria:** mixed/partial rollover値を確定値として見せない。
- **Verification:** browser state matrix、ja/en/mobile。

### P7-T04 — Phase 7 gate

- [ ] **Purpose:** Season sliceを完成させる。
- **Changes:** review fixes。
- **Done Criteria:** rollover rehearsalとimmutable snapshotがpass。
- **Verification:** Standard Phase Gate。

## 10. Phase 8 — Admin / Dispute

### P8-T01 — Admin operating and authorization decisions

- [ ] **Purpose:** admin bootstrap、queue SLA、restriction ranges、retentionを確定する。
- **Changes:** decision/runbook/permission matrix。
- **Done Criteria:** admin権限付与と緊急recoveryが監査可能。
- **Verification:** security/operations review。

### P8-T02 — Dispute/restriction/correction domain slice

- [ ] **Purpose:** 全運営mutationをaudited trusted actionsに限定する。
- **Changes:** queue、incidents、three resolutions、restrictions、completed correction、audit。
- **Done Criteria:** retry-safeでcompleted season snapshotを変更しない。
- **Verification:** permission/idempotency/audit/correction tests。

### P8-T03 — Minimal Admin UI and user resolution feedback

- [ ] **Purpose:** 運営が必要情報を確認し安全に解決できるようにする。
- **Changes:** admin queue/detail/confirmation、user-visible outcome、ja/en/mobile最低限。
- **Done Criteria:** private moderation dataが非adminへ漏れず、reason/auditが必須。
- **Verification:** role-based browser tests、dangerous-action UX review。

### P8-T04 — Phase 8 gate

- [ ] **Purpose:** Admin/Dispute sliceを完成させる。
- **Changes:** review fixes。
- **Done Criteria:** 全mutationのauthorization/audit/recoveryが確認済み。
- **Verification:** Standard Phase Gate。

## 11. Phase 9 — Hardening & Launch

### P9-T01 — Full-system quality and security audit

- [ ] **Purpose:** 全MVPのregression、RLS、secrets、dependencies、accessibility、ja/enを監査する。
- **Changes:** issue fixesだけを行い、新Featureを追加しない。
- **Done Criteria:** Critical/High issueが0件。
- **Verification:** full suite、independent security/spec review。

### P9-T02 — Performance, observability, and operations

- [ ] **Purpose:** launch後に問題を検知・復旧できるようにする。
- **Changes:** query/load test、indexes、rate limits、logs/alerts/analytics、privacy redaction、runbooks。
- **Done Criteria:** 主要signal、owner、threshold、recovery actionが明確。
- **Verification:** load/failure test、alert smoke、runbook walkthrough。

### P9-T03 — Production migration and rollback rehearsal

- [ ] **Purpose:** production data/environmentへの安全な反映を確認する。
- **Changes:** migration plan、backup、forward-fix/rollback、OAuth/Vercel/Supabase checklist。
- **Done Criteria:** rehearsalが成功し、destructive/irreversible stepにHuman approval pointがある。
- **Verification:** clean/staging rehearsal、Preview smoke、rollback exercise。

### P9-T04 — Final MVP E2E and launch gate

- [ ] **Purpose:** product全体のgo/no-goを判断する。
- **Changes:** launch blocker fixesのみ。
- **Done Criteria:** Golden Path、全Feature acceptance、desktop/mobile、ja/en、error/recovery、operationsがpassし、Known Issuesが受容済み。
- **Verification:** Self Verification → Independent Review → fixes → Human Review → explicit Production approval。

## 12. Blocked and Deferred

### Blocked

- 現在、Phase 0をblockするTaskはない。
- Auth providerのcredential入力、Supabase project link、Vercel Preview環境変数など人間のsecret操作が必要なTaskは、値をrepositoryやchatへ貼らず、該当Taskでsecure environment設定として依頼する。

### Deferred / Out of Scope

- X OAuthをMVP必須にすること。
- 自由入力chat、live game state/API integration、evidence upload。
- Redis、専用Backend/Matchmaking Server、Supabase Branching。
- rating全履歴のpost-hoc再計算、completed season snapshot変更。
- advanced analytics、rating graph、region leaderboard、activity decay。
- Weekly Tournament、Character Matchup PracticeなどPost-MVP機能。

## 13. Completion Record

各Phase完了時に最低限、commit/PR、実行したverificationと結果、Preview、Independent Review findings、Human Review結果、Known Issues、次Phase開始可否を記録する。
