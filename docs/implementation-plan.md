# SF6-Rating — MVP Implementation Plan

Status: Phase 2 Implementation Complete — Verification Gate Pending
Approach: Foundation + Vertical Slice
Internal MVP Checkpoint: Phase 5 complete

## 1. Overview

### Goal

Reviewed specificationsを、検証可能な10個のPhaseとして段階的に実装する。Phase 0とPhase 1で必要最小限の土台を作り、Phase 2以降はData、trusted server/domain logic、API、UI、security、testsを機能単位で縦に完成させる。各Phaseは独立した品質Gateを通過するまで次へ進まない。

### Source of Truth

競合時は次の順序を採用する。

1. `docs/features/README.md`の横断ルールと最も具体的なFeature Spec
2. `docs/architecture.md`
3. `docs/product-spec.md`
4. このImplementation Planと`docs/tasks.md`

Rated FT3の各gameのRound Timeは60 secondsとする。仕様変更が入った場合は実装前に本計画とTasksへの影響を再確認する。

### Related Documents

- Product: `docs/product-spec.md`
- Architecture: `docs/architecture.md`
- Features: `docs/features/*.md`
- Process: `AI-Development-OS/os/feature-development.md`
- Templates: `AI-Development-OS/templates/implementation-plan.md`, `AI-Development-OS/templates/tasks.md`

## 2. Repository Investigation

2026-08-15時点の最新`main`（`f5198e6`）とPhase 1成果物を調査した。

- Phase 0のNext.js / TypeScript / Supabase基盤と、Phase 1のmigration、RLS、generated types、database tests、transaction / idempotency基盤が存在する。
- ArchitectureはNext.js + TypeScript + App Router、Supabase、Vercel、日本語/英語を指定している。
- PostgreSQLを永続状態のSource of Truthとし、重要な状態遷移はtrusted Server / Database処理でAtomicかつIdempotentに行う。
- Supabase Realtimeは確定済み変更の通知にのみ使い、再接続時はDBから復元する。
- Supabase ProjectはTokyo regionで作成済み。Data API ON、Automatically expose new tables OFF、Automatic RLS ON。GitHub repositoryとの接続も完了済み。
- Phase 1の`profiles.id`はimmutable Public User IDとして使用でき、Profile / SF6 identity / private details / placement initialization / deletion metadataのnullable skeletonがある。Phase 2では既存migrationを編集せずforward migrationとtrusted actionsで契約を完成させる。
- Phase 2のProduct Decisionは`docs/phase-2-account-onboarding-decisions.md`でAcceptedとなり、Feature SpecsとArchitectureへ反映済みである。
- 実装直前には各Phaseで再度Repository Investigationを行い、既存パターン、schema、tests、利用可能なcomponentsを確認して詳細なファイル構成を確定する。

## 3. Implementation Approach

### Foundation + Vertical Slice

- Phase 0は実行・検証・deployの土台だけを作り、SF6固有Featureを実装しない。
- Phase 1は全Featureを先回りして完成させず、認証、RLS、migration、domain transactionを安全に積み上げる共通Data Foundationを作る。
- Phase 2以降はFeature Specの受け入れ条件をData → domain/server → API → UI → security → testsの縦方向で閉じる。
- Browserから重要データを直接確定させない。認可、入力検証、競合制御、Rating更新、season処理、admin操作はtrusted boundaryで実行する。
- MVPでは専用Backend、Redis、専用Matchmaking Server、Supabase Branchingを導入しない。

### Standard Phase Gate

すべてのPhaseで次を順番に行う。

`Implementation → Self Verification → Independent Review → fixes if needed → Human Review → phase complete`

- Self Verification: lint、typecheck、tests、production build、およびPhase固有検証。
- Independent Review: 別AIまたは別コンテキストでSpec compliance、bugs、security、data integrity、architecture、UX、regressionを確認する。
- Human Review: Previewまたはローカル環境で主要Desktop/Mobile体験を確認する。
- Critical/High issue、未検証のCompletion Gate、blocking Open Questionが残る間は次Phaseへ進まない。

## 4. Phase Plan

### Phase 0 — Project Foundation

**Goal**
Greenfield repositoryに、機能実装を安全に開始できるNext.jsプロジェクト土台を構築する。

**Dependencies**
最新`main`、supported Node runtime、Supabase Project、Vercel/GitHub連携。Supabaseの実secret値は環境側で設定し、Gitへ保存しない。

**Data changes**
Supabase CLI初期化とmigration/seedの置き場だけを用意する。SF6 domain tableやproduction data migrationは作らない。

**API / server changes**
browser/server用途を分離したSupabase client foundation、session/cookieを扱えるserver boundary、環境変数の型付き検証を用意する。Feature APIやdomain RPCは作らない。

**UI changes**
App Router、基本layout、global styles、locale routingまたは同等のi18n基盤、ja/enの最小メッセージ、汎用のnot-found/error/loading foundationを用意する。SF6固有画面は作らない。

**Security changes**
公開可能なSupabase URL/Publishable keyとserver-only secretを明確に分離する。`.env.example`には名前と説明だけを置き、`.gitignore`で実値を除外する。server-only moduleがclient bundleへ入らない構成を検証する。

**Risks / mitigation**

- package/runtime選定の陳腐化: 実装時に公式support範囲を確認し、lockfileをcommitする。
- Supabase SSR/cookieの誤用: browser/server clientを分離し、最小のcontract testを置く。
- i18nがroutingやbuildを複雑化: ja/enだけの小さな基盤から開始する。
- shared Test Databaseへの誤操作: Phase 0ではschema変更を行わず、環境を明示する。

**Verification**

- clean install後にローカル起動できる。
- lint、typecheck、tests、production buildが成功する。
- ja/enを切り替えて基本layoutを表示でき、unknown localeを安全に扱う。
- Supabase browser/server clientを公開鍵だけで初期化でき、未設定時は理解可能なerrorになる。
- CIがpull request/pushで最低限の品質チェックを実行する。
- Vercel Previewでbuild可能な構成である。
- secret scanningとgit diffでsecret本体が含まれないことを確認する。

**Completion Gate**

- Next.js + TypeScript + App Routerアプリがrepository内に存在し、ローカル起動可能。
- lint / typecheck / tests / production buildがすべてpass。
- Supabase client/server connection foundationが存在する。
- `.env.example`が存在し、secret本体はcommitされていない。
- Vercel Preview deploy可能な構成である。
- i18n基盤が日本語/英語を扱える。
- CIで最低限の品質チェックが走る。
- 基本layoutと汎用状態だけがあり、SF6固有Featureはまだ実装していない。
- Standard Phase Gateを完了している。

**Proceed to Phase 1 when**
上記Gateを証跡付きで満たし、PreviewをHuman Reviewし、Critical/High issueが0件である。

### Phase 1 — Data Foundation

**Goal**
後続vertical slicesが依存するmigration、RLS、domain transaction、generated types、local/test data workflowの共通基盤を確立する。

**Dependencies**
Phase 0、Supabase project link情報、Feature Specsのcanonical terminology。

**Data changes**
共有enum/domain types、profile identityの最小骨格、seasons、matches、participants、waiting、reports、rating history、events、disputes/restrictions/auditに必要なschemaを依存順に設計する。ただし各Featureの振る舞いは該当Phaseで完成させる。FK、unique/check constraint、index、RLS default-deny、migration/seed/reset手順を含む。

**API / UI changes**
generated DB typesとrepository/domain boundaryを用意する。migration状態を確認できる開発者向けhealth check以外のFeature UIは作らない。

**Security changes**
Automatic RLSを前提に全公開tableのpolicyを明示し、service roleはserver-onlyとする。blind result、private SF6 identity、admin dataを公開projectionから分離できるschemaにする。

**Risks / mitigation**
仕様間で同一概念が重複するため、canonical match fieldsを中心にERD/transition tableをreviewする。過剰な先行schema固定を避け、forward migrationで拡張可能にする。

**Verification**
empty DBからmigration/seed/reset、constraints、RLS permission matrix、generated types、transaction/idempotency harnessを検証する。

**Completion Gate**
後続Phaseの最小schema契約、RLS baseline、migration workflow、test fixturesがreview済みで、unauthorized accessと不正状態遷移を拒否できる。

**Proceed to Phase 2 when**
schema reviewとpermission testsがpassし、Account/Profileのblocking Open Questionsを実装前に解決または明示的なMVP設定値へ落とせる。

### Phase 2 — Account & Onboarding

Detailed plan: `docs/phase-2-account-onboarding-implementation-plan.md`
Detailed tasks: `docs/phase-2-account-onboarding-tasks.md`

**Goal**
Google、Discord、Email/Password認証と3-step onboardingを通じて、matching可能なProfileとPlacement開始状態を作る。

**Dependencies**
Phases 0–1、`account-profile.md`、`placement.md`、`phase-2-account-onboarding-decisions.md`、統合検証前のAuth provider環境設定。

**Data / API changes**
profile、SF6 identity、country / broad-region masters、initial rating inputs、placement progress、avatar metadata、change/deletion/reclaim metadataをforward migrationで実装する。Username NFKC + case-fold normalization、10桁SF6 User Code normalization、30日cooldown、Active Match identity gate、MR 1〜5000 validation、step save、trusted onboarding completion、resume/edit/delete domain actionsを用意する。

**UI changes**
Google / Discord / verified Email + Password、email verification/reset、3-step onboarding、「次へ」保存、resume、profile edit、avatar、validation/loading/error/mobile statesをja/enで実装する。独自Account Linking UIは作らない。

**Security changes**
owner/admin/public/active-opponent境界、private fields、Storage policy、OAuth callback、rate limit、Active Match中のPlayer Name / User Code変更gate、deletion pending gate、User Code reclaim権限を検証する。

**Dependency-ordered slices**

1. DB / Auth Foundation
2. Authentication Flow
3. Onboarding Step 1: Account
4. Onboarding Step 2: SF6 Player Info
5. Onboarding Step 3 + Placement Initialization
6. Avatar and Profile Editing
7. Account Deletion and Anonymization
8. Integration, Security, and UX Verification

**Risks / mitigation**
Unicode confusableはNFKC + case foldingとAdmin moderationで扱う。Avatar decodeは5 MB byte上限に加えpixel/decode上限とserver re-encodeで保護する。Account deletionはstate machine、idempotency receipt、retry、private reclaim ledgerで部分失敗とUser Code即時再利用を防ぐ。OAuth secretは環境管理する。

**Verification / Completion Gate**
全必須auth方式、途中再開、step単位保存、atomic completion、Unicode / User Code unique conflict、入力境界、owner/public/active-opponent visibility、Active Match identity gate、region master、avatar形式/容量/加工、MR 1〜5000、placement初期化、mobile UX、pending deletion / anonymization / reclaim safetyをFeature acceptance criteriaと統合testで確認する。Auth、RLS、Account deletion、SF6 Identity、onboarding completion transactionをHigh-riskとして、`Implementation → Self Verification → Independent Review → AI-fixable Critical/Important fixes → Re-verification`を完了する。

**Proceed to Phase 3 when**
onboarding完了ユーザーが一貫したmatching eligibilityを持ち、認証/公開範囲のHigh issueがない。

### Phase 3 — Matchmaking

**Goal**
同一Available PoolからQuick MatchとFind Opponentを提供し、競合時も1件だけMatchを成立させる。

**Dependencies**
Phases 0–2、`matchmaking.md`、active season、rating/placement eligibility。

**Data / API changes**
waiting entry、heartbeat/expiry、candidate projection、rated eligibility/cooldown、match creation transaction、audit eventsを実装する。candidate weights/region groupingは設定化する。

**UI changes**
start/cancel waiting、candidate list、empty/loading/error/reconnecting、global waiting、match-found transitionをmobile-first、ja/enで実装する。

**Security changes**
character情報のpre-match非公開、participant eligibilityのserver再検証、concurrent selection、multi-tab、duplicate request、rate limitを扱う。

**Risks / mitigation**
race conditionとstale availabilityはrow locking/unique constraints/idempotencyで防ぐ。Realtime欠落時はfocus/reconnect fetchで復元する。

**Verification / Completion Gate**
Quick/Manual双方、rating/region/elapsed expansion、10分expiry、24時間rated pair cooldown、season cutoff、placement/restriction gate、同時要求を統合/競合testとbrowser testで確認し、Standard Phase Gateを完了する。

**Proceed to Phase 4 when**
2ユーザーで再現可能に1件だけMatchが成立し、private pre-match dataが漏れない。

### Phase 4 — Match Room & FT3

**Goal**
成立済みMatchの参加者がSF6 Custom Roomへ合流し、60-second Round TimeのRated FT3を進行してreportingへ移れる。

**Dependencies**
Phases 0–3、`match-room.md`、`ft3-match.md`、canonical match state machine。

**Data / API changes**
host assignment/change、match events/preset messages、state transitions、active match recovery、forfeit/incident/cancellation entry boundaryをtrusted actionsとして実装する。

**UI changes**
role-specific guidance、SF6 identity、copy affordance、preset timeline、10分trouble guidance、resume/reconnect、reporting entryをja/en/mobileで実装する。Rated FT3 setupにはRound Time 60 secondsを明示する。

**Security changes**
参加者限定private view、event authorization、duplicate/rate-limit protection、clientからのstate改ざん防止を確認する。

**Risks / mitigation**
外部game状態は検証できないため、Web側は明示的なparticipant actionsとserver stateだけを正とする。Realtimeは通知専用とする。

**Verification / Completion Gate**
host偏り、host交代、preset、reload/sleep/multi-tab、無権限閲覧、invalid transition、60-second guidance、reporting遷移を確認し、Standard Phase Gateを完了する。

**Proceed to Phase 5 when**
2ユーザーがmatch成立からFT3案内、結果報告入口まで復元可能な状態で到達できる。

### Phase 5 — Result Reporting + Rating Core

**Goal**
blind dual reporting、mismatch、forfeit、mutual cancellation、incidentsを安全に処理し、Rated結果をAtomicにRating/Placement/statsへ反映する。

**Dependencies**
Phases 0–4、`result-reporting.md`、`rating-system.md`、`placement.md`、Admin/Dispute境界。

**Data / API changes**
result report/revision、normalization/comparison、finalization transaction、rating snapshots/history、Elo K=64、rounding、placement multiplier/cap/count、idempotency、active rated gate、5分/30分/24時間nonresponse flowを実装する。

**UI changes**
You/Opponent orientation、confirmation、blind pending、one-time mismatch revision、result、rating delta、forfeit/cancellation/incident flowsをja/en/mobileで実装する。

**Security changes**
相手reportの確定前非公開、participant-only writes、server-side time、duplicate/concurrent finalization、service authorizationを検証する。

**Risks / mitigation**
二重Rating、stale snapshot、誤ったscore orientationをtransaction、unique constraint、pure calculation tests、property/boundary testsで防ぐ。

**Verification**
normal 3-0/3-1/3-2、mismatch/revision/dispute、forfeit without fictional score、mutual/no-response no-rating、unrated、placement 1–10、simultaneous submit/retryを検証する。

**Completion Gate — Internal MVP Checkpoint**

- 新規ユーザー2人 → onboarding/Placement状態 → Match → Match Room → Rated FT3 guidance → blind Result reports → 一致 → Rating/Placement/stats更新、を実ブラウザ2 sessionのGolden Path E2Eで完走する。
- Match、Rating History、Current Rating、season recordが同一transactionの期待値と一致し、再試行しても二重更新しない。
- active rated gateが適切に解除される。
- Phases 0–5のregression suite、security review、Independent Review、Human Reviewが完了する。

**Proceed to Phase 6 when**
Golden Path E2Eが安定してpassし、Internal MVP CheckpointのCritical/High issueが0件である。

### Phase 6 — Public Profile + Ranking

**Goal**
確定済みの公開データだけからprofile、match history、active-season rankingを提供する。

**Dependencies**
Phases 0–5、`public-profile.md`、`ranking.md`。

**Data / API/UI changes**
public projections、paginated history、ranking query/ties/current-user context、Overview/History/Seasons shell、ranking table/search（MVP採否決定後）を実装する。

**Security changes**
SF6 user code、email、pending/disputed reports、admin/private fieldsを公開しない。invalidated resultを除外する。

**Risks / mitigation**
N+1や不安定paginationをindex/keyset等で防ぎ、rating snapshot欠損時は推測表示しない。

**Verification / Completion Gate**
guest/user双方、placement/ranked/deleted/empty states、ties、pagination、privacy、mobileを確認し、Standard Phase Gateを完了する。

**Proceed to Phase 7 when**
public data contractとactive rankingがrating sourceと整合し、private leakageがない。

### Phase 7 — Seasons

**Goal**
3か月Season、30分cutoff、不変snapshot、soft reset、placement引継ぎを安全に運用する。

**Dependencies**
Phases 0–6、`seasons.md`、具体的なseason schedule/name decision。

**Data / API/UI changes**
season lifecycle、match attribution、rollover progress、snapshot、soft reset、boundary no-rating close、current/past season表示、運営recovery pathを実装する。

**Security changes**
rolloverはserver/admin/scheduled boundaryに限定し、UTC、single active season、idempotent per player/seasonを保証する。

**Risks / mitigation**
result finalizationとの境界raceをtransaction/lockで直列化し、failure injectionとresume testを行う。

**Verification / Completion Gate**
cutoff/end同時刻、unfinished rated match、placement途中、0戦eligible、duplicate/concurrent rollover、immutable past snapshotをclock-controlled testで確認し、Standard Phase Gateを完了する。

**Proceed to Phase 8 when**
rollover dry run/retryとpast/current public viewsが一貫し、recovery手順がreview済みである。

### Phase 8 — Admin / Dispute

**Goal**
最小Admin UIと監査済みdomain actionsでdispute、incident、restriction、result invalidation/correctionを処理する。

**Dependencies**
Phases 0–7、`admin-dispute.md`、admin identity bootstrap、queue/SLA operating decision。

**Data / API/UI changes**
queue、structured incidents、three resolution types、progressive restrictions、30分manual/24時間auto no-rating close、completed-match correction、audit log、minimal admin viewsを実装する。

**Security changes**
deny-by-default admin authorization、reason required、append-only audit、private moderation data、self-service mutual resolution境界を検証する。

**Risks / mitigation**
権限昇格と不可逆な誤操作をseparate domain actions、confirmation、audit、idempotencyで抑える。completed season snapshotは変更しない。

**Verification / Completion Gate**
admin/non-admin permission matrix、全resolution、restriction progression/expiry/revoke、correction、duplicate action、audit completenessを確認し、Standard Phase Gateを完了する。

**Proceed to Phase 9 when**
すべてのadmin mutationが認可・監査・replay安全性を満たし、運営手順がHuman Review済みである。

### Phase 9 — Hardening & Launch

**Goal**
MVP全体をproduction運用可能な品質へ仕上げ、安全にlaunchする。

**Dependencies**
Phases 0–8、production Supabase/Vercel/OAuth configuration、運営判断。

**Data / API/UI changes**
必要な性能index、rate limits、observability、error reporting、analytics、accessibility/localization polish、runbooks、backup/recovery、seed removalを行う。新Featureは追加しない。

**Security changes**
RLS全表監査、secret rotation/readiness、dependency/security scan、abuse paths、privacy/log redaction、admin bootstrap、headersを確認する。

**Risks / mitigation**
free-tier limits、external provider障害、production migration失敗に対しload test、alerts、rollback/runbook、staged deployを用意する。

**Verification / Completion Gate**
全acceptance/regression/E2E、desktop/mobile、ja/en、accessibility、performance、security、production migration rehearsal、Preview smoke、rollback rehearsal、launch checklist、Independent Review、Human go/no-goを完了する。

**Proceed to launch when**
Critical/High issueが0件、Known Issuesが受容済み、monitoring/operations/rollback ownerが明確で、HumanがProduction deployを承認した場合のみ。

## 5. Cross-Phase Verification Strategy

- Unit: rating/placement formula、normalization、state guards、time boundaries。
- Database integration: constraints、RLS、transaction、idempotency、concurrency。
- Application integration: Auth/session、server actions/RPC、public/private projections、Realtime recovery。
- Browser E2E: 2-user flows、desktop/mobile、ja/en、reload/multi-tab/error states。
- Regression: 各Phase完了時に既完了Phaseのsuiteを再実行する。
- Production readiness: Preview smoke、migration rehearsal、observability、rollback。

## 6. Rollback Considerations

- codeはPhase単位のsmall PR/commitでrevert可能にする。
- migrationは原則forward-fixとし、破壊的変更前にbackup/compatibility windowを用意する。
- incomplete Featureはroute/operation単位で安全にdisable可能にする。
- Rating、season、adminの履歴は削除や上書きではなくappend/correctionを優先する。
- external provider設定変更はrunbookに記録し、ProductionとPreviewを分離する。

## 7. Open Questions and Decision Timing

Phase 2を開始できないOpen Questionはない。以下は該当PhaseのRepository Investigation完了までに決め、設定値・decision log・spec更新のいずれかへ記録する。

- Phase 3: nearby-country grouping、candidate weights、heartbeat interval、profile-change-during-waiting、rate-limit values。
- Phase 4–5: host assignment、event retention、forfeit termination score、unrated statistics、5/10分UX仮説の計測方法。
- Phase 6: history page size、username searchをMVPへ含めるか。
- Phase 7: season start/end dates、naming、rollover recovery UI。
- Phase 8–9: admin queue SLA/notification、restriction operational ranges、success metric targets。

設定可能なnon-blocking assumptionは初期値と検証方法を明示して進められる。Feature contract、security、data integrity、不可逆な運用を変える未決事項は該当Phaseのblocking questionとして解決する。

Phase 2の具体値、Closed Questions、AI-owned assumptions、Future / Out of Scopeは`docs/phase-2-account-onboarding-decisions.md`に記録した。詳細な実装順、Human Action Points、High-risk verificationは`docs/phase-2-account-onboarding-implementation-plan.md`に記録した。Google / Discord credentials、redirect URL、Email delivery等は統合検証前のenvironment prerequisiteであり、未解決Product Decisionではない。
