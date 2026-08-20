# Placement — Feature Spec

Status: Reviewed — Phase 2 Decisions Formalized
Product: SF6-Rating
Feature: Placement
Related Decision: `docs/phase-2-account-onboarding-decisions.md`

---

# 1. Feature Overview

## Feature Name

Placement

## Summary

新規ユーザーの自己申告したSF6ランク / MRをStarting Ratingへ変換し、最初の10件のCompleted Rated FT3でRatingを通常より速く調整して、適正Ratingへ近づける。

## Purpose

全ユーザーを同じRatingから開始させることで生じる大きな実力差を避け、初回から比較的近い実力の相手とFT3を成立させる。

Placementは「10戦後に初めてRatingを決める」方式ではない。オンボーディング完了時から暫定Ratingを持ち、Completed Rated FT3ごとに更新する。

---

# 2. User

## Target User

- オンボーディングを完了した新規ユーザー
- SF6の現在のメインキャラクターとRank、Masterの場合はMRを登録するユーザー

## User Goal

- 自分のSF6実力を大まかに反映したStarting Ratingから開始したい
- 最初の10件のRated FT3でSF6-Rating内の適正Ratingへ早く近づきたい
- Placementの進行状況と現在Ratingを理解したい
- Placement完了後にランキングへ参加したい

---

# 3. User Flow

1. ユーザーがオンボーディングでMain Character、SF6 Rank、必要に応じてSubrankまたはMRを入力する
2. システムが入力値を検証する
3. システムがStarting Ratingを算出してユーザーへ表示する
4. ユーザーが入力内容とStarting Ratingを確認する
5. 最初のRated Match成立時にStarting RatingとPlacement開始情報がLockされる
6. ユーザーが通常Matchmakingへ参加する
7. Completed Rated FT3が確定する
8. システムがBase Elo Changeへ当該ユーザーのPlacement Multiplierを適用する
9. システムがPlacement本人の変動量へ±96 Capを適用し、最後に整数化する
10. Rating、Rating History、Placement進行数を同一Transactionで更新する
11. ユーザーがCurrent RatingとPlacement進行を確認する
12. 10件目のCompleted Rated FT3が確定するとPlacementを完了する
13. 同じTransactionでRanking eligibilityを付与する
14. ユーザーへPlacement Completeと確定時点のRatingを表示する

---

# 4. Functional Requirements

## Requirement 1 — Placement Eligibility

- **[Confirmed / Product Critical]** Placementは新規アカウントにつき原則1回だけ実施する
- オンボーディング完了時にPlacement対象となる
- 新シーズン開始時に再Placementしない
- ユーザー自身によるPlacementのやり直しを提供しない

## Requirement 2 — Non-Master Starting Rating

- **[Confirmed / Product Critical]** Starting Ratingの基準値は次のとおりとする

| SF6 Rank | Base Rating |
| --- | ---: |
| Rookie | 900 |
| Iron | 1000 |
| Bronze | 1100 |
| Silver | 1200 |
| Gold | 1300 |
| Platinum | 1450 |
| Diamond | 1650 |

- 1〜5のSubrankがある場合、基準値へ次の補正を加える

| Subrank | Adjustment |
| --- | ---: |
| 1 | -40 |
| 2 | -20 |
| 3 | 0 |
| 4 | +20 |
| 5 | +40 |

## Requirement 3 — Master Starting Rating

- **[Confirmed / Product Critical]** MasterのStarting Ratingは次の式で算出する

```text
calculated_rating = 1850 + 0.75 × (MR - 1500)
starting_rating = min(2200, max(1800, calculated_rating))
```

- Minimumは`1800`
- Maximumは`2200`
- 1800〜2200のBoundsはStarting Ratingだけへ適用する
- Placement開始後のSF6-Rating本体には、このBoundsを適用しない
- SF6-Rating本体には人工的なRating上限・下限を設けない

## Requirement 4 — Placement Progress

- **[Confirmed / Product Critical]** Placementは最初の10件のCompleted Rated FT3とする
- 次のMatchはPlacement進行へ数える
  - 双方の結果が一致してCompletedになったRated FT3
  - Explicit Forfeit等により正式なRated Win / Lossとして確定したMatch
  - Admin判断により正式なRated Win / Lossとして確定したMatch
- 次のMatchまたは状態はPlacement進行へ数えない
  - Unrated Match
  - Cancelled Match
  - Unresolved Dispute
  - Disconnect ReportだけのMatch
  - Abandonment IncidentだけのMatch
  - Invalid Match

## Requirement 5 — Placement Multiplier

- **[Confirmed / Product Critical]** Placement進行数に応じて次のMultiplierを使う

| Completed Rated FT3 | Multiplier |
| --- | ---: |
| 1〜3件目 | ×2.0 |
| 4〜7件目 | ×1.5 |
| 8〜10件目 | ×1.25 |
| 11件目以降 | ×1.0 |

- 計算順序は次のとおりとする

```text
Base Elo Change
→ Placement Multiplier
→ ±96 Cap
→ Round
```

- Round方式はRating System Feature Specに従う
- 11件目以降はPlacement調整を行わず通常Rating計算を使う

## Requirement 6 — Per-Player Adjustment

- **[Confirmed / Product Critical]** Placement Multiplierと±96 CapはPlacement本人だけに適用する
- Established Playerには通常Elo変動だけを適用する
- Placement PlayerとEstablished Playerの対戦は意図的に非ゼロサムになり得る
- 両者がPlacement中の場合、各自のPlacement進行段階に対応するMultiplierとCapを独立して適用する

例:

```text
Base Elo Change:
Placement Player A +46
Established Player B -46

A is in Placement stage ×2.0:
Player A +92
Player B -46
```

## Requirement 7 — Matchmaking Participation

- **[Confirmed]** Placement専用Poolを作らない
- Placement中も通常のQuick Match / Find Opponentへ参加できる
- 現在の暫定Ratingを検索範囲、候補評価、カテゴリ分類に使用する
- Matchmaking候補には`Placement 4/10`等の進行状況を表示する

## Requirement 8 — Ranking Eligibility

- **[Confirmed / Product Critical]** Placement中はランキング対象外とする
- Current Rating自体はプロフィール等へ表示できる
- 10件目のCompleted Rated FT3確定と同時にPlacementを完了する
- 同時にRanking eligibilityを付与する
- 新シーズンではPlacementを再開せず、Season Soft Reset後もRanking eligibilityを維持する

## Requirement 9 — Placement UX

- オンボーディングでStarting Ratingと「最初の10件のRated FT3がPlacementである」ことを表示する
- ProfileでCurrent RatingとPlacement進行を明示する
- Result確定画面でRating変動とPlacement進行更新を明示する
- 10件目完了時にPlacement Complete、現在Rating、ランキング参加資格獲得を表示する
- Starting Ratingをユーザーが直接編集することはできない

## Requirement 10 — Source Data Lifecycle

- **[Confirmed]** Main Character / Rank / MRはStarting Rating決定専用とする
- Placement開始後にMain Character / Rank / MRを変更してもRatingを再計算しない
- Starting Rating確定前、かつ最初のRated Match成立前なら入力ミスを修正できる
- 最初のRated Match成立時にStarting RatingとPlacement開始情報をLockする
- Lock後はユーザー自身による再計算、再入力によるRating変更、Placementやり直しを許可しない

## Requirement 11 — Master MR Validation

- **[Confirmed]** Master MRは自己申告とする
- **[Confirmed]** 明らかな入力ミスや異常値を防ぐsanity validation rangeをversioned / configurableにする
- **[Confirmed]** MVP初期値は1〜5000（inclusive）とする
- 範囲外はWarningだけで通さずvalidation errorとし、Starting Ratingを確定しない
- SF6側のMR環境が変化した場合、設定変更で対応できるようにする
- MVPではSF6 APIによる所有確認やMR自動取得を必須にしない

## Requirement 12 — Atomic Finalization

- **[Derived Technical Decision]** Placement進行数、Multiplier、Starting Ratingはサーバー側で決定する
- **[Derived Technical Decision]** 10件目のFinalizationでは次を同一Transactionで処理する
  - Match Result finalization
  - Rating更新
  - Rating History作成
  - Placement completed count更新
  - Placement complete更新
  - Ranking eligibility更新
- Transaction途中の部分成功を許可しない
- 再送やRetryでも同じMatchをPlacement進行へ複数回数えない

## Requirement 13 — Rating Audit Data

- **[Derived Technical Decision]** rating_historyへ少なくとも次を保存する
  - Rating Before
  - Base Elo Change
  - Placement Multiplier
  - Multiplier適用後の変動値
  - Cap適用有無
  - Cap適用前の変動値
  - Cap適用後の変動値
  - Round前の変動値
  - Final Rating Change
  - Rating After
  - Placement match number
  - MatchおよびSeasonへの参照
- 後から当時の計算を再現・監査できる情報を保持する

## Requirement 14 — Invalidated Placement Match

- **[Confirmed / Product Critical]** Placement Matchが後から無効化されても、MVPではPlacement進行数を巻き戻さない
- Placement Complete済みのユーザーを`9/10`等へ戻さない
- 後続Matchを再計算しない
- Rating System Feature Specで確定したCompensating CorrectionをRating Historyへ追加する
- 元の履歴を書き換えず、Correctionを監査可能な別イベントとして残す

---

# 5. Product Rules

1. **[Confirmed]** Placementは新規アカウントにつき原則1回だけ実施する
2. **[Confirmed]** 新シーズンでは再Placementしない
3. **[Confirmed]** Starting RatingはRank / SubrankまたはMaster MRから算出する
4. **[Confirmed]** Master Starting Ratingだけを1800〜2200へClampする
5. **[Confirmed]** Placement開始後のSF6-Rating本体には人工的な上限・下限を設けない
6. **[Confirmed]** Placementは最初の10件のCompleted Rated FT3である
7. **[Confirmed]** Unrated、Cancelled、Unresolved Dispute、未確定IncidentはPlacement進行へ数えない
8. **[Confirmed]** 正式なRated Win / Lossとして確定したForfeitはPlacement進行へ数える
9. **[Confirmed]** Multiplierは`×2.0 → ×1.5 → ×1.25 → ×1.0`の順に適用する
10. **[Confirmed]** Placement本人の変動量だけを±96へCapする
11. **[Confirmed]** Established Playerへ相手のPlacement Multiplierを波及させない
12. **[Confirmed]** Placement期間は意図的に非ゼロサムになり得る
13. **[Confirmed]** Placement専用Poolを作らない
14. **[Confirmed]** Placement中はランキング対象外とする
15. **[Confirmed]** 10件目確定と同時にRanking eligibilityを得る
16. **[Confirmed]** Main Character / Rank / MRの変更でPlacement開始後のRatingを再計算しない
17. **[Confirmed]** 最初のRated Match成立後はユーザー自身によるStarting Rating修正やPlacementやり直しを認めない
18. **[Derived Technical Decision]** Placement計算と進行更新は信頼されたサーバー / DB処理だけが行う
19. **[Confirmed]** 後からMatchを無効化してもPlacement進行を巻き戻さずCompensating Correctionを使う
20. **[Confirmed]** Master MR sanity validationは設定可能とし、MVP初期値1〜5000（inclusive）を使う

---

# 6. States

## Not Started

オンボーディング未完了、またはStarting Rating算出前。

表示:

- Rank / MR入力
- 入力Validation
- Starting Rating確認へ進む導線

## Starting Rating Preview

Starting Ratingは算出済みだが、最初のRated Match成立前。

表示:

- 入力したRank / SubrankまたはMR
- 算出されたStarting Rating
- Placementが10件である説明
- 入力を修正する導線

## Active

Placement進行中。

表示:

- Current Rating
- `Placement N/10`
- 次のCompleted Rated FT3に適用されるMultiplier
- ランキング対象外であること

## Match Pending

Rated Matchが成立または結果確定待ち。

表示:

- 現在のMatch状態
- そのMatchが確定するまでPlacement進行が増えないこと
- 未解決Rated Match中は次のRated Matchへ参加できないこと

## Complete

10件目のCompleted Rated FT3が確定済み。

表示:

- Placement Complete
- Current Rating
- Ranking eligibility獲得
- Ranking / Profileへの導線

## Error

Starting Rating算出またはPlacement更新に失敗。

表示:

- 失敗した操作
- Current Ratingや進行が変更されていないこと
- 安全に再試行する導線

Placement完了後、通常ユーザーを再びActiveへ戻さない。

---

# 7. Edge Cases

## Rank Input Corrected Before First Rated Match

Starting Rating Preview中なら入力を修正し、Starting Ratingを再算出できる。

## Rank or MR Changes After Placement Starts

プロフィール情報だけ更新できる。Starting Rating、Current Rating、Placement進行を再計算しない。

## Invalid Master MR

設定値（MVP初期値1〜5000 inclusive）から判定し、範囲外はValidationエラーを表示してStarting Ratingを確定しない。

## Master Formula Below or Above Bounds

MR式の結果を1800〜2200へClampする。ClampはStarting Ratingへだけ適用する。

## Unrated Match During Placement

履歴上必要なら保存するが、Placement進行とMultiplier stageを変更しない。

## Match Is Disputed

正式なRated Win / Lossが確定するまでPlacement進行を増やさない。

## Explicit Forfeit

正式なRated Win / Lossとして確定した場合、Placementの1件として数え、Rating計算へPlacement調整を適用する。

## Both Players Are in Placement

各プレイヤーのPlacement match numberに対応するMultiplierと±96 Capを独立して適用する。

## One Player Is Established

Placement PlayerだけへMultiplierとCapを適用し、Established Playerには通常Elo変動を適用する。

## Tenth Match Finalization Retry

Idempotentに処理し、Placement count、Rating History、Rating、Ranking eligibilityを一度だけ更新する。

## Tenth Match Finalization Fails

TransactionをRollbackし、Ratingだけ更新済み、またはRanking eligibilityだけ付与済みの状態を作らない。

## Placement Match Later Invalidated

Placement進行やRanking eligibilityを巻き戻さず、Compensating Correctionを追加する。後続Matchを再計算しない。

## New Season During Placement

Placement中ユーザーはPlacementを継続する。新しいPlacementを開始しない。Season切替とRating Snapshotの詳細はSeason Feature Specに従う。

## Multiple Tabs or Duplicate Requests

DB状態へ同期し、同一Matchを複数回Placement進行へ加算しない。

---

# 8. Error Handling

## Invalid Rank / MR Input

- 不正な項目と修正方法を表示する
- Starting Ratingを確定しない
- ユーザーの入力可能な範囲を日本語・英語で案内する

## Starting Rating Calculation Failed

- Starting Ratingを推測値で保存しない
- 再試行できるようにする
- 一部だけPlacement開始済みの状態を残さない

## Rating Finalization Failed

- Match Result、Rating、Rating History、Placement進行、Ranking eligibilityを一括Rollbackする
- Current RatingとPlacement進行をDBから再取得する
- 同じ確定処理を安全に再試行できるようにする

## Duplicate Finalization

- 既存のRating HistoryとMatch finalizationを返す
- RatingやPlacement countを二重更新しない

## Stale Client State

- クライアント表示ではなくDB上のPlacement countを優先する
- 最新状態を再取得して表示を修正する

## Unauthorized Update

- Starting Rating、Multiplier、Placement count、Completion、Ranking eligibilityの直接変更を拒否する
- 内部情報を露出しない一般的なエラーを表示する
- 必要な監査ログを残す

---

# 9. Permissions

## Guest

- 公開プロフィール上で許可されたCurrent RatingとPlacement表示を閲覧できる
- Starting Ratingを作成・変更できない
- Placementへ参加できない

## Logged-in User

- 自分のオンボーディングでRank / MRを入力できる
- 最初のRated Match成立前まで入力ミスを修正できる
- 自分のStarting Rating Preview、Current Rating、Placement進行を確認できる
- Placement中に通常Matchmakingへ参加できる
- Starting Rating、Multiplier、Cap、Placement count、Ranking eligibilityを直接指定できない

## Owner

- 自分のStarting Rating入力元をLock前だけ修正できる
- Lock後にPlacementをやり直せない
- 自分のPlacement状態をCompleteへ直接変更できない
- 自分のRating Historyを改変できない

## Admin

- 運営上必要な範囲でStarting Rating入力、Placement進行、Rating Historyを確認できる
- Dispute解決やMatch無効化に伴うCorrectionを信頼された管理処理から実行できる
- MVPでは任意にPlacement進行を巻き戻す一般操作を提供しない

すべての権限はRLS、Server-side validation、Database制約で保護する。Service Role等の秘密鍵をBrowserへ公開しない。

---

# 10. Data

実際のDBスキーマではなく、Placementに必要なプロダクトデータを示す。

## Player Placement

- User
- Starting Rating
- Starting Rating Source: Rank / MR
- Source Rank
- Source Subrank
- Source MR
- Formula Version
- Master Minimum Bound
- Master Maximum Bound
- Started At
- Starting Rating Locked At
- Completed Rated FT3 Count
- Current Placement Stage
- Current Multiplier
- Placement Status
- Completed At
- Ranking Eligible
- Ranking Eligible At

## Rating Calculation

- Match
- Player
- Rating Before
- Opponent Rating Snapshot
- Base Elo Change
- Placement Match Number
- Placement Multiplier
- Change After Multiplier
- Cap Value
- Cap Applied
- Change Before Cap
- Change After Cap
- Change Before Round
- Final Change
- Rating After
- Calculation Rule Version
- Season
- Calculated At

## Starting Rating Rules

- Rank Base Ratings
- Subrank Adjustments
- Master MR Formula Parameters
- Master Starting Rating Minimum
- Master Starting Rating Maximum
- MR Validation Range
- Rule Version
- Effective From

## Placement Completion

- Tenth Completed Rated Match
- Completion Timestamp
- Final Placement Rating
- Ranking Eligibility Granted At

## Rating Correction

- Correction ID
- User
- Source Match
- Original Rating Change
- Compensating Change
- Reason
- Admin / Trusted Process
- Created At
- Audit Reference

---

# 11. Dependencies

- Account / Profile Feature
- Authenticationおよびオンボーディング
- Rating System Feature Spec
- Matchmaking Feature Spec
- Result Reporting Feature Spec
- FT3 Match Feature Spec
- Ranking / Season
- Admin / Dispute
- SF6 Rank / Subrank / MRの設定データ
- PostgreSQL Transaction
- Rating History
- Row Level Security
- 日本語・英語のUI文言

---

# 12. Non-Functional Requirements

## Performance

- Starting Rating算出はオンボーディング中に即時フィードバックできる
- Placement Finalizationは通常Rating Finalizationと同等の時間内に完了する
- Profile / MatchmakingでPlacement進行を表示するために全Rating Historyを再集計しない
- Placement countとStatusは効率的に取得できる

## Security

- Starting Rating、Multiplier、Cap、Placement count、Ranking eligibilityをクライアントが任意指定できない
- Master MR入力をサーバー側でもValidationする
- Formulaと設定値の改ざんを防ぐ
- Rating FinalizationとCorrectionを監査可能にする
- 自己申告したMain Character / Rank / MRの公開範囲はAccount / Profile Feature Specに従う

## Reliability

- **[Derived Technical Decision]** PostgreSQLをPlacement進行とRatingのSource of Truthとする
- **[Derived Technical Decision]** Rating更新、Rating History、Placement count、Completion、Ranking eligibilityを同一Transactionで処理する
- **[Derived Technical Decision]** 一意制約とIdempotencyにより同じMatchを一度だけ数える
- 再接続、Reload、複数Tabでも最新Placement状態を復元する
- Rule Versionを保存し、過去計算を再現できる

## Accessibility

- Starting Rating、Current Rating、Placement進行、Multiplierを色だけで区別しない
- Placement完了をスクリーンリーダーへ通知する
- Rank / MR入力と修正をKeyboardで完了できる
- 数式を理解しなくてもPlacementの意味が分かる説明を提供する

## Mobile

- スマートフォンでRank / MR入力、Starting Rating確認、進行確認を完了できる
- Result画面でRating変動とPlacement進行を読みやすく表示する
- Placement Complete表示を小さい画面でも確認できる
- PCブラウザでも同じ情報を利用できる

## Localization

- Placement、Starting Rating、Progress、Complete、Validation Errorを日本語・英語で提供する
- 数値、日時、Rank表示をLocaleに応じて表示する
- 内部のRule IDと表示文言を分離する

---

# 13. Acceptance Criteria

## Starting Rating

- [ ] RookieのBase Ratingが900になる
- [ ] IronのBase Ratingが1000になる
- [ ] BronzeのBase Ratingが1100になる
- [ ] SilverのBase Ratingが1200になる
- [ ] GoldのBase Ratingが1300になる
- [ ] PlatinumのBase Ratingが1450になる
- [ ] DiamondのBase Ratingが1650になる
- [ ] Subrank 1〜5へ`-40 / -20 / 0 / +20 / +40`が適用される
- [ ] Masterへ`1850 + 0.75 × (MR - 1500)`が適用される
- [ ] Master MR 1〜5000（inclusive）を受け付け、範囲外をValidation errorにする
- [ ] Master Starting Ratingが1800未満にならない
- [ ] Master Starting Ratingが2200を超えない
- [ ] Starting Rating BoundsがPlacement後のCurrent Ratingを制限しない
- [ ] 最初のRated Match成立前なら入力を修正できる
- [ ] 最初のRated Match成立後はStarting Ratingを再計算できない

## Progress

- [ ] Placementが新規アカウントにつき原則1回だけ開始される
- [ ] 最初の10件のCompleted Rated FT3だけがPlacement進行になる
- [ ] Unrated Matchで進行が増えない
- [ ] Cancelled Matchで進行が増えない
- [ ] Unresolved Disputeで進行が増えない
- [ ] 未確定Disconnect / Abandonment Incidentで進行が増えない
- [ ] 正式Rated Win / LossのExplicit Forfeitで進行が1増える
- [ ] 新シーズン開始時にPlacementを再実施しない

## Rating Adjustment

- [ ] 1〜3件目へ×2.0が適用される
- [ ] 4〜7件目へ×1.5が適用される
- [ ] 8〜10件目へ×1.25が適用される
- [ ] 11件目以降へ×1.0が適用される
- [ ] 計算順序がBase Elo Change、Multiplier、±96 Cap、Roundになる
- [ ] Placement本人の変動だけが±96へCapされる
- [ ] Established Playerへ通常Elo変動だけが適用される
- [ ] 両者Placementの場合に各自のstageが独立して適用される
- [ ] Placement対Establishedで非ゼロサム結果を正しく保存できる
- [ ] rating_historyへMultiplierとCap前後の値が保存される

## Matchmaking and Ranking

- [ ] Placement専用Poolが存在しない
- [ ] Placement中ユーザーが通常Matchmakingへ参加できる
- [ ] 暫定Ratingが検索とカテゴリ分類へ使われる
- [ ] 候補に`Placement N/10`が表示される
- [ ] Placement中はランキング対象外である
- [ ] 10件目確定と同時にPlacement Completeになる
- [ ] 10件目確定と同時にRanking eligibilityを得る
- [ ] 10件目Finalizationが部分成功しない
- [ ] RetryでRating、進行、Ranking eligibilityが二重更新されない

## UX and Correction

- [ ] OnboardingでStarting RatingとPlacementの説明を確認できる
- [ ] ProfileでCurrent RatingとPlacement進行を確認できる
- [ ] Result画面でRating変動とPlacement進行更新を確認できる
- [ ] 10件目完了時にPlacement Completeが表示される
- [ ] Main Character / Rank / MR変更でPlacement開始後のRatingが再計算されない
- [ ] 後からPlacement Matchを無効化しても進行を巻き戻さない
- [ ] 後続Matchを再計算せずCompensating Correctionを記録できる
- [ ] 主要フローを日本語・英語で利用できる
- [ ] 主要フローをスマートフォンとPCブラウザで確認できる

---

# 14. Out of Scope

- Placement専用Matchmaking
- Placement専用Pool
- Placementのやり直し
- ユーザー自身によるStarting Rating再設定
- Seasonごとの再Placement
- SF6 APIによるRank / MR自動取得
- SF6ユーザーコードとRank / MRの厳格な所有確認
- Placement Match無効化時のPlacement進行巻き戻し
- 後続Rating Historyの全再計算
- 高度なSmurf検知
- AIによるRank / MR真偽判定
- Placement専用の対戦相手
- Placement後のRating上限 / 下限

---

# 15. Open Questions

現時点でPlacement実装を停止するBlockerはない。

## Resolved — Master MR Validation Range

**[Resolved by Phase 2 Decision]**

Master MRは自己申告とし、versioned / configurableなsanity rangeを使う。MVP初期値は1〜5000（inclusive）で、範囲外はValidation errorとしてStarting Ratingを確定しない。Starting Rating自体は既存式に従い1800〜2200へClampする。

## OQ-02 Placement Formula Validation

**[Assumption — Needs Validation]**

- Rank / MR別Starting Ratingが実際のFT3実力へ十分近いか
- 10件で適正Ratingへ十分収束するか
- ×2.0 / ×1.5 / ×1.25と±96 Capが強すぎないか、弱すぎないか

実装前シミュレーションと公開後のPlacement完了データで検証し、Rule Versionを更新可能にする。

## Resolved — New Season During Active Placement

**[Resolved by Seasons]**

Season境界でPlacement進捗とCurrent Ratingをそのまま引き継ぎ、Soft Resetは適用しない。新Seasonで10/10に到達した直後からそのSeasonのRanking eligibleとする。過去Seasonの表示は確定済みSnapshotのみを使用する。
