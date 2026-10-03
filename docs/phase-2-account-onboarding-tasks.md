# Phase 2 — Account & Onboarding Tasks

Status: Implementation Complete — Final Local DB Re-verification Pending
Related plan: `docs/phase-2-account-onboarding-implementation-plan.md`
Decision: `docs/phase-2-account-onboarding-decisions.md`

## 1. Execution Rules

- Planning順に実行し、前sliceのDone Criteriaを満たしてから次へ進む。
- 既存Phase 1 migrationを編集しない。schema変更はforward migrationだけで行う。
- Browser direct writeを追加せず、重要なstate transitionはtrusted Server / Database境界に置く。
- 各Taskでtestsを同時に追加し、Phase末にまとめて後付けしない。
- Secret値、OAuth credential、service-role keyをtracked file、test log、screenshotへ残さない。
- Phase 2.8では `Implementation → Self Verification → Independent Review → AI-fixable Critical/Important fixes → Re-verification` を完了する。

## 2. Phase 2.1 — DB / Auth Foundation

### P2.1-T01 — Reconfirm repository contract and freeze test matrix

- [x] **Purpose:** 実装開始時点のschema、package、Supabase公式contractを再確認し、planning driftを防ぐ。
- **Changes:** Decision / Feature traceability、RLS permission matrix、Auth callback matrix、high-risk failure / concurrency cases、予定fileを実構成に合わせて更新する。
- **Dependencies:** Phase 1 Complete、Phase 2 Decision Finalized。
- **Done Criteria:** Blocking Human Decision 0、各acceptance criteriaの実装先とtest先が明確、既存user変更と競合がない。
- **Verification:** documentation diff、migration history、current branch / status、official Supabase Auth / SSR / Storage guidance review。

### P2.1-T02 — Add account masters and forward schema

- [x] **Purpose:** Country / Broad Region、Profile constraints、Avatar、deletion / reclaim、rate-limitの永続契約を作る。
- **Changes:** ISO country / managed region masterとseed、日本7区分、canonical 10-digit User Code check、timestamps / indexes、avatar assets、private deletion job / keyed-digest reclaim ledger、named rate-limit stateをforward migrationで追加する。
- **Dependencies:** P2.1-T01。
- **Done Criteria:** stable master codes、all-country fallback、history-safe inactive state、one active identity/account、private ledger、5 MB Avatar metadata contractがDBで表現される。
- **Verification:** empty reset、Phase 1 upgrade、pgTAP constraints / FK / unique / privacy、seed idempotency、schema diff。

### P2.1-T03 — Add Auth user provisioning and starting-rating-v2

- [x] **Purpose:** Supabase Auth userとapplication Profileを一対一に安全に紐付け、MR contractをversion化する。
- **Changes:** idempotent `auth.users` trigger、Profile / account / identity / private skeleton、既存unmapped user backfill、MR 1〜5000の`starting-rating-v2`、v1 active flag transitionを追加する。
- **Dependencies:** P2.1-T02。
- **Done Criteria:** duplicate eventでも1 Profileだけ作られ、Auth user IDは一意にmappingされ、v1 snapshotを壊さずv2がactiveになる。
- **Verification:** sign-up fixture、trigger retry、backfill、parameter immutability / active-version pgTAP、generated types diff。

### P2.1-T04 — Implement trusted boundary and normalization primitives

- [x] **Purpose:** Clientからnormalized valueやactorを偽装できない共通domain基盤を作る。
- **Changes:** server-only admin client、session / actor helper、NFKC + pinned Unicode full case-fold、grapheme / category / reserved name、Player Name / User Code validators、safe redirect、cooldown、rate-limit helper、typed domain errorsを追加する。
- **Dependencies:** P2.1-T03。
- **Done Criteria:** normalization結果がdeterministicで、service-role moduleがClientからimport不能、DB unique / checkが最終guardになる。
- **Verification:** Unicode vectors、full-width / separator User Code、boundary / invalid category tests、client bundle/import test、secret scan。

### P2.1-T05 — Establish RLS, projections, Storage policy, and action skeletons

- [x] **Purpose:** 後続sliceが同じdefault-deny認可とidempotency patternを使えるようにする。
- **Changes:** owner / public / active-opponent / admin projection、Storage bucket / object policies、actor再検証付きtrusted RPC skeleton、domain action receipt integrationを追加する。
- **Dependencies:** P2.1-T04。
- **Done Criteria:** guest / owner / other user / active opponent / admin / serviceのmatrixが仕様どおりで、Browser roleに直接write grantがない。
- **Verification:** positive / negative pgTAP、two-session query、actor spoof test、Storage folder ownership / list / write tests。

## 3. Phase 2.2 — Authentication Flow

### P2.2-T01 — Complete SSR session and Auth callback flow

- [x] **Purpose:** Local / Previewで安全にsessionを確立・更新し、onboardingへ復帰できるようにする。
- **Changes:** PKCE callback route、code exchange、relative `next` allowlist、locale preservation、Profile provisioning check、protected-route helper、sign-out、callback error statesを実装する。
- **Dependencies:** P2.1-T05。
- **Done Criteria:** valid callbackは保存済みonboarding stepまたはappへ遷移し、missing / replayed codeやexternal redirectを拒否する。
- **Verification:** unit / Route integration、cookie refresh、open-redirect vectors、expired / replayed code、build。

### P2.2-T02 — Implement Email / Password lifecycle

- [x] **Purpose:** verified Emailだけでapplication onboardingを開始でき、passwordを安全にresetできるようにする。
- **Changes:** sign-up、sign-in、verification pending / resend、forgot password、reset callback、update password、generic enumeration-safe errors、local confirmation configを実装する。
- **Dependencies:** P2.2-T01。
- **Done Criteria:** unverified userはprotected onboardingを完了できず、verification後にProfileへ紐付き、reset linkからpassword更新できる。
- **Verification:** local Supabase + Mailpit integration、invalid / expired link、duplicate submit、sign-out / re-login、ja/en UI tests。

### P2.2-T03 — Implement Google and Discord OAuth entry

- [x] **Purpose:** MVP必須social providersを同じcallback / session contractへ接続する。
- **Changes:** provider buttons、OAuth start params、cancel / deny / collision errors、approved redirect、provider avatar candidate extractionを実装する。独自linking UIは追加しない。
- **Dependencies:** P2.2-T01。実provider verificationはHuman credentialsに依存。
- **Done Criteria:** provider開始とcallback後のprovisioning / resumeが共通contractを使い、errorがaccount existenceやtokenを漏らさない。
- **Verification:** mocked provider / URL contract tests、LocalまたはPreviewでGoogle / Discord各1回のHuman-assisted smoke evidence。

## 4. Phase 2.3 — Onboarding Step 1: Account

### P2.3-T01 — Implement Username availability and save action

- [x] **Purpose:** Unicode Usernameを正規化、一意化し、step単位でserverへ確定する。
- **Changes:** 3〜20 grapheme validation、reserved names、availability feedback、unique-race handling、pre-completion edit、idempotent Account step saveを実装する。
- **Dependencies:** P2.2-T02、P2.1-T04。
- **Done Criteria:** 日本語、数字、`_`、`-`を受け付け、normalized collisionとinvalid characterを拒否し、保存成功後だけStep 2へ進む。
- **Verification:** normalization unit vectors、concurrent same-name integration、reload / resume、double-click / retry browser tests。

### P2.3-T02 — Implement Avatar upload pipeline

- [x] **Purpose:** Ownerだけが安全な静止Avatarを保存できるようにする。
- **Changes:** JPEG / PNG / WebP decode、5 MB / pixel limit、animation / SVG拒否、orientation、metadata strip、1:1 crop、最大512、WebP re-encode、owner path、pointer swap、cleanup retryを実装する。
- **Dependencies:** P2.1-T05。
- **Done Criteria:** malformed / spoofed / oversized / animated inputを拒否し、成功時にcurrent Avatarを壊さず置換できる。
- **Verification:** fixture matrix、resource-limit test、owner / non-owner Storage tests、replace race、orphan cleanup retry。

### P2.3-T03 — Build Account step UI and resume behavior

- [x] **Purpose:** UsernameとAvatarをja/en・mobileで理解可能に設定できるようにする。
- **Changes:** step progress、field help、provider/default/upload preview、loading / error / retry、Client draft、back / resume、accessible file inputを実装する。
- **Dependencies:** P2.3-T01、P2.3-T02。
- **Done Criteria:** server saveを確認してからStep 2へ進み、reload時は保存済み値から復元し、未送信draftをSoTにしない。
- **Verification:** component / browser tests、keyboard、screen-size、ja/en、network failure / retry。

## 5. Phase 2.4 — Onboarding Step 2: SF6 Player Info

### P2.4-T01 — Implement SF6 identity and region save action

- [x] **Purpose:** searchable Player Name、canonical User Code、managed locationをprivate contractどおり保存する。
- **Changes:** Player Name validation、10-digit User Code canonicalization / uniqueness、Country / Broad Region FK、privacy-safe typed result、idempotent step saveを実装する。
- **Dependencies:** P2.3-T03、P2.1-T02。
- **Done Criteria:** duplicate Player Nameを許可し、normalized duplicate User Code、invalid country-region pair、free-text regionを拒否する。
- **Verification:** boundary / normalization unit、concurrent User Code pg integration、master inactive / mismatch、reload / retry。

### P2.4-T02 — Build SF6 Player Info step UI

- [x] **Purpose:** Player NameとUser Codeの用途差、公開範囲、地域選択を迷わず入力できるようにする。
- **Changes:** separated fields、10-digit input affordance、Country-dependent managed region select、privacy explanation、loading / field / conflict errors、back / resumeを実装する。
- **Dependencies:** P2.4-T01。
- **Done Criteria:** save成功後だけStep 3へ進み、public profileへprivate valuesを描画・prefetchしない。
- **Verification:** ja/en component / browser、mobile keyboard / touch、invalid / duplicate / offline、public payload inspection。

## 6. Phase 2.5 — Onboarding Step 3 + Placement Initialization

### P2.5-T01 — Implement Rating Setup validation and preview

- [x] **Purpose:** self-reported rank / MRからserver-owned Starting Rating previewを一貫して計算する。
- **Changes:** Character / Rank / tier / MR validation、MR 1〜5000、active parameter lookup、Placement Spec式、1800〜2200 clamp、typed previewを実装する。
- **Dependencies:** P2.4-T02、P2.1-T03。
- **Done Criteria:** Client-supplied ratingを信用せず、boundary / null combinationsがversioned ruleどおりになる。
- **Verification:** table-driven formula / clamp、parameter version、invalid MR、stale preview tests。

### P2.5-T02 — Implement atomic and idempotent onboarding completion

- [x] **Purpose:** Profile公開、Rating、Placement、account active化の部分成功と二重初期化を防ぐ。
- **Changes:** row lock、step completeness / email verification再検査、parameter snapshot、placement row、profile / account state、eligibility、idempotency receiptを1 transactionへ実装する。
- **Dependencies:** P2.5-T01。
- **Done Criteria:** retry / concurrent requestでも同じ結果を返し、failure injection時は全変更がrollbackされる。
- **Verification:** duplicate / two-session concurrency、failure injection、unverified email、missing step、stale parameter、single placement row pg tests。

### P2.5-T03 — Build Rating Setup and completion UX

- [x] **Purpose:** Starting Rating / Placementを理解して安全にonboardingを完了できるようにする。
- **Changes:** inputs、preview、privacy note、confirmation、pending / retry / success、completed-user redirectをja/en・mobileで実装する。
- **Dependencies:** P2.5-T02。
- **Done Criteria:** repeated submitやreloadで二重作成せず、完了後にmatching eligibilityを持つapp entryへ移る。
- **Verification:** browser e2e full onboarding、mobile / keyboard / announcements、disconnect before/after commit、resume。

## 7. Phase 2.6 — Avatar and Profile Editing

### P2.6-T01 — Implement profile mutation actions and policy gates

- [x] **Purpose:** Onboarding後の編集をcooldown、Active Match、privacy contractの内側で許可する。
- **Changes:** Username 30日、User Code 30日、Player Name cooldownなし、Country / Region、Character / Rank / tier / MR、Avatar replace / deleteのtrusted actionsを実装する。Rating / placement snapshotは再計算しない。
- **Dependencies:** P2.5-T03。
- **Done Criteria:** server time、last-confirmed timestamp、active-match state、owner authorizationをtransactionで検査し、private changeがpublic payloadへ漏れない。
- **Verification:** cooldown boundary / clock、active-match lock、other-user mutation、parallel update、public / owner projection regression tests。

### P2.6-T02 — Build Profile settings and public baseline

- [x] **Purpose:** Public / private項目、編集可否、次回変更可能日を明確に表示する。
- **Changes:** Profile settings forms、Avatar controls、cooldown / active-match disabled reason、delete entry、public profile baselineをja/en・mobileで実装する。
- **Dependencies:** P2.6-T01。
- **Done Criteria:** PublicはUsername / Avatar / Country / Current Rating / Placementだけを基本表示し、private fieldをresponseにも含めない。
- **Verification:** owner / guest / other user / active opponent browser sessions、payload inspection、a11y、responsive。

## 8. Phase 2.7 — Account Deletion and Anonymization

### P2.7-T01 — Implement deletion request and blocking-state gate

- [x] **Purpose:** active dependencyを壊さず削除意思を永続化し、新規matchmakingを止める。
- **Changes:** recent-auth check、Active Match / unresolved Result / Dispute query、pending transition、blocking reason、idempotent request、eligibility denialを実装する。
- **Dependencies:** P2.6-T02。
- **Done Criteria:** blockersありでは匿名化せず`deletion_pending`、blockerなしではfinalizationへ進め、duplicate requestが安全。
- **Verification:** state matrix、concurrent request、other user、stale session、new matchmaking denial contract tests。

### P2.7-T02 — Implement anonymization and Auth deletion finalizer

- [x] **Purpose:** PIIを消しつつMatch / Rating Historyを匿名参照で保持し、部分失敗を再試行可能にする。
- **Changes:** dependency recheck、Storage cleanup、private keyed-digest reclaim ledger、Profile / identity / private anonymization、access revoke、server-only `auth.admin.deleteUser`、durable job / retryを実装する。
- **Dependencies:** P2.7-T01。
- **Done Criteria:** raw User Code / PII / Auth accountを最終的に削除し、immutable Public User IDとhistory invariantを保持し、codeは自動再利用されない。
- **Verification:** duplicate / concurrent finalizer、Storage / DB / Auth failure injection、retry after partial failure、history snapshot、reclaim denial、secret / PII log scan。

### P2.7-T03 — Build deletion UX and recovery state

- [x] **Purpose:** 不可逆操作、blocking reason、pending stateを誤解なく扱えるようにする。
- **Changes:** confirmation / recent-auth flow、blocker summary、pending restriction、retry / support guidance、completed sign-outをja/en・mobileで実装する。
- **Dependencies:** P2.7-T02。
- **Done Criteria:** duplicate confirmationを安全に扱い、解消操作を妨げず、匿名化完了後に旧sessionでappへ戻れない。
- **Verification:** browser state matrix、keyboard / focus、back / refresh、多tab、post-delete token / session behavior。

## 9. Phase 2.8 — Integration, Security, and UX Verification

### P2.8-T01 — Run full local Supabase and automated verification

- [ ] **Purpose:** Phase 2全体を再現可能なlocal環境で一括検証する。
- **Changes:** 原則review fixesだけ。test evidenceを記録する。
- **Dependencies:** P2.1〜P2.7 complete。
- **Done Criteria:** format、lint、typecheck、unit、production build、db reset、pgTAP、Auth / Mailpit integration、two-session concurrency、browser e2eがpass。
- **Verification:** clean local runとCI-equivalent commands、test output、migration / generated type clean diff。

### P2.8-T02 — Verify Auth providers and Vercel Preview

- [ ] **Purpose:** Local mocksでは検出できないprovider / hosted callback / cookie / env問題を確認する。
- **Changes:** Human Action完了後に環境設定そのものはHumanが行い、CodexはPreview smokeとevidence整理を行う。
- **Dependencies:** P2.8-T01、Human credentials / Dashboard settings。
- **Done Criteria:** Google、Discord、verified Email、reset、callback、session、onboarding、Avatar、public privacy、deletion requestがPreviewで確認済み。
- **Verification:** provider別checklist、approved redirect / error path、server-only env非露出、ja/en mobile Preview review。

### P2.8-T03 — Perform independent high-risk review

- [x] **Purpose:** 実装者のblind spotをPhase 3へ持ち越さない。
- **Changes:** 別AI contextがSpec compliance、Auth、RLS、deletion、SF6 identity、completion transaction、abuse、UX、rollbackをreviewし、severity付きfindingを残す。
- **Dependencies:** P2.8-T01。Preview evidenceがあれば併用。
- **Done Criteria:** Critical / Important findings、根拠、再現、影響範囲が明確で、非blocking suggestionと分離される。
- **Verification:** review artifactとcoverage traceability。

### P2.8-T04 — Fix AI-addressable Critical / Important findings

- [x] **Purpose:** Human往復を必要としない重大問題を一括で解消する。
- **Changes:** scoped code / migration / test / docs fixesのみ。Product intent変更やcredential操作はHumanへ戻す。
- **Dependencies:** P2.8-T03。
- **Done Criteria:** AI-addressable Critical / Importantが0件。残るHuman itemはownerとevidence requirementが明確。
- **Verification:** findingごとのregression test、targeted commands。

### P2.8-T05 — Re-verify and close Phase 2 gate

- [ ] **Purpose:** fixes後の回帰を含め、Phase 3へ進める証跡を確定する。
- **Changes:** completion evidence、docs status、global plan / tasksだけを必要に応じ更新する。
- **Dependencies:** P2.8-T04、required Human verification。
- **Done Criteria:** full self-verification pass、High-risk path検証済み、Critical / Important 0、secret 0、onboarding完了userが一貫したmatching eligibilityを持つ。
- **Verification:** full command rerun、Preview smoke、Independent Review disposition、Human Review sign-off。

## 10. Human Action Checklist

- [ ] Google OAuth consent / client credentialsを準備しSupabaseへ登録する。
- [ ] Discord application / OAuth credentialsを準備しSupabaseへ登録する。
- [ ] Supabase Auth providers、Email verification、password / rate-limit policyを設定・確認する。
- [ ] Local / Preview / ProductionのSite URL、redirect allowlist、provider callback URLを設定する。
- [ ] SMTP senderとverification / reset Email templates / expiryを設定する。
- [ ] Vercelへ公開envとserver-only secretsを環境別に設定する。
- [ ] Preview用Supabase environment / data isolationを確認する。
- [ ] Google / Discord / Email実accountでProvider / Preview smokeと最終mobile UX reviewを行う。

Secret値は本checklist、commit、issue本文、test evidenceへ書かない。
