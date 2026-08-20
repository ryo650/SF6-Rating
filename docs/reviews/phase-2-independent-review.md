# Phase 2 — Independent Review

Review date: 2026-08-20
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
- Human Action Points: Google / Discord provider credentials、hosted Email、redirect allowlist、Vercel Previewは未実施。いずれも外部environmentのHuman Actionであり、local Completion Gate blockerではない。
- PR readiness: **Ready**。Critical / Important 0、Minor 2、全local Completion GateがPASSした。

## 5. Review Boundary

実Google / Discord account、hosted Email delivery、Vercel Preview、Hosted Supabase設定はreview対象codeの静的contractまで確認した。credential / Dashboard / Preview evidenceはHuman Actionであり、未実施をcode defectとして数えていない。
