# Rating System — Feature Spec

Status: Draft  
Feature: Rating System  
Product: SF6-Rating

---

# 1. Feature Overview

## Feature Name

Rating System

## Summary

確定したRated FT3の勝敗から、相手とのRating差を強く反映したプレイヤー単位のRatingを計算し、監査可能な履歴と現在値を安全に更新する。

## Purpose

- 3先におけるプレイヤーの実力を継続的に表す
- 格上への勝利と格下への敗北を大きく評価する
- Ratingの計算根拠を追跡・再現できるようにする
- 二重更新や部分更新によるRating破損を防ぐ

---

# 2. User

## Target User

- Rated FT3へ参加するログインユーザー
- Rating・ランキング・履歴を確認するユーザー
- Dispute解決や過去Match無効化を行うAdmin

## User Goal

- FT3結果に応じた公平で理解可能なRating変動を受ける
- 対戦前に想定変動量を確認する
- 対戦後にRatingのBefore / Change / Afterを確認する

---

# 3. User Flow

1. Rated Match成立時に両者の現在Rating Snapshotを保存する
2. Find Opponentでは同じ計算ロジックでWin / Loss時の変動Previewを表示する
3. FT3終了後、Result Reportingで正式なWinner / Loserを確定する
4. Rating CalculatorがSnapshotと確定結果から変動値を計算する
5. Placement対象なら倍率と上限を適用する
6. 変動値を一度だけ整数へ丸める
7. Match確定、Rating History作成、Current Rating更新を同一Transactionで行う
8. 結果画面・Profile・Rankingへ更新値を反映する
9. 過去Matchを後から無効化する場合は、後続Matchを再計算せず補正履歴を追加する

---

# 4. Functional Requirements

## Requirement 1 — Elo Formula

プレイヤーAの期待勝率と基本変動を次で計算する。

```text
E_A = 1 / (1 + 10^((R_B - R_A) / 250))
Δ_A = 64 × (S_A - E_A)
R'_A = R_A + Δ_A
```

- Rating中心値: `1500`
- Expected score scale: `250`
- K: `64`
- Win: `S = 1`
- Loss: `S = 0`
- 同Rating同士の通常変動: `±32`

## Requirement 2 — Rating Input

- Rating計算にはMatch成立時の両者のRating Snapshotを使用する
- Current Ratingが画面表示後に変化しても、当該Matchの計算入力はSnapshotへ固定する
- Previewと本計算は同じRating CalculatorとParameterを使用する

## Requirement 3 — Result Input

- Rating計算はWinner / Loserだけを使用する
- `3-0`、`3-1`、`3-2`のSet ScoreはRating変動へ影響しない
- Set Scoreは戦績・表示用データとして別に保持する
- Explicit ForfeitはForfeitした側のLoss、相手のWinとして通常Formulaを適用する
- Forfeitを架空のSet Scoreへ変換しない

## Requirement 4 — No-change Outcomes

以下ではRatingを変更しない。

- Unrated Match
- Mutual Cancellation
- Cancelled Match
- Nonterminal Match
- Disputedで未解決のMatch
- Disconnect / Abandonment / Incidentの報告のみ

## Requirement 5 — Rounding

- 小数精度で基本変動を計算する
- 通常Ratedでは変動値を最後に一度だけ四捨五入する
- 同一の整数値 `N` をWinnerへ `+N`、Loserへ `-N` として適用する
- Rating Before / Afterを両者別々に丸めて差分を作らない

## Requirement 6 — Clamp and Bounds

- 通常Rated MatchにはFormula以外の追加Clampを設けない
- Matchmakingの最大Rating差±500では通常変動がおおむね±1〜±63に収まる
- MVPでは人工的なRating上限・下限を設けない
- Placementの変動上限は通常RatedのClampとは分離する

## Requirement 7 — Placement Connection

Placement対象では次の順序で計算する。

```text
base change
→ placement multiplier
→ placement cap
→ round once
→ final integer change
```

- Placement倍率とCapの具体値はPlacement Feature Specを正とする
- Product Spec上の前提は、1〜3セット目×2.0、4〜7セット目×1.5、8〜10セット目×1.25、最大±96
- Placement終了後は通常倍率×1.0とする

## Requirement 8 — Atomic Finalization

Rated結果確定時に、次を一つのAtomic Transactionとして処理する。

- Match finalization
- Rating calculation
- 各プレイヤーのRating History作成
- 各プレイヤーのCurrent Rating更新
- 必要な戦績更新

一部だけ成功した状態を残さない。

## Requirement 9 — Idempotency

- 同一MatchのRating確定は一度だけ実行できる
- Retry、連打、複数Tab、同時SubmitでRatingを重複適用しない
- 1 Rated Match × 1 Playerにつき通常のRating Historyを1件だけ作成する

## Requirement 10 — Centralized Parameters

- Center、Scale、K、Placement multiplier、Placement cap、丸め規則を一元管理する
- Preview、Finalization、検証、シミュレーションで同じParameter setを使用する
- 使用したParameter versionを履歴から追跡できるようにする

## Requirement 11 — Rating Preview

- Find OpponentでSnapshot候補に基づくWin / Loss時の概算変動を表示できる
- Previewは情報表示であり、実際の確定値は保存済みSnapshotと確定結果からServer側で計算する
- Quick Matchでは具体的なPreview表示を必須としない

## Requirement 12 — Historical Invalidation

過去のCompleted Rated Matchが後から無効化された場合、MVPでは後続MatchのRatingを全再計算しない。

- 無効化対象Matchで適用したRating変動を相殺するCompensating Rating Correctionを追加する
- CorrectionをRating Historyの独立した監査可能イベントとして保存する
- 過去の通常Rating Historyを削除・上書きしない
- Correction適用とCurrent Rating更新をAtomicかつIdempotentにする
- `source_match_id + correction_type`等を一意にして二重適用を防止する
- Current Seasonでは同じDomain Action内でseason stats correctionも行う
- completed SeasonのFinal Rating / Ranking / Stats Snapshotは変更しない
- 詳細なAdmin操作と承認フローはAdmin / Dispute Feature Specで定義する

---

# 5. Product Rules

1. Ratingはキャラクター単位ではなくプレイヤー単位で管理する。
2. Ratingは確定したRated FT3のWinner / Loserだけから計算する。
3. Set ScoreはRating変動へ影響しない。
4. Explicit Forfeitは通常のWin / Lossとして計算する。
5. `status=cancelled`、Incidentのみ、UnratedではRatingを変更しない。
6. Match成立時のRating Snapshotを計算入力として固定する。
7. Previewと本計算は同じFormula・Parameterを使用する。
8. 通常変動は小数計算後に一度だけ四捨五入し、Winner +N / Loser -Nとする。
9. 通常Ratedに追加Clampを設けない。
10. MVPでは人工的なRating上限・下限を設けない。
11. Placementはbase change → multiplier → cap → roundの順に適用する。
12. Rating確定処理はAtomicかつIdempotentにする。
13. Rating Parameterを一元管理し、計算履歴から再現可能にする。
14. 過去Match無効化時はMVPでは後続Matchを再計算せず、補正Rating Historyを追加する。
15. ClientはRating値、Rating Change、Current Rating、Rating Historyを直接指定・変更できない。

---

# 6. States

## Preview

- Match成立前に想定Win / Loss変動を表示できる
- 確定Rating変更ではない

## Snapshotted

- Rated Match成立済み
- 両者のRating SnapshotとParameter versionを保存済み
- 結果未確定

## Pending Result

- Winner / Loserが未確定
- Rating変更なし

## Finalizing

- 確定結果からRatingをTransaction内で計算・保存中
- Client上の一時状態をTruthとしない

## Applied

- Rating HistoryとCurrent Ratingを一度だけ更新済み
- Before / Change / Afterを表示可能

## No Rating Change

- Unrated、`status=cancelled`、Nonterminal、Incidentのみ
- Match状態は更新され得るがRating処理なし

## Correction Pending

- 過去Completed Rated Matchの無効化が承認済み
- Compensating Correction未適用

## Corrected

- Correction HistoryとCurrent Rating更新済み
- 後続Matchの再計算なし

## Error

- FinalizationまたはCorrectionが完了していない
- 部分更新なし
- 安全にRetry可能

---

# 7. Edge Cases

## Equal Ratings

- Expected scoreは0.5
- 通常変動はWinner +32 / Loser -32

## Maximum Matchmaking Difference

- ±500の範囲でもFormulaをそのまま使用する
- 通常Ratedに人工的な最低変動・最大変動を追加しない

## Result Finalization Retry

- 同一MatchへRatingを二重適用しない
- 適用済みなら既存結果を返す

## Simultaneous Result Submission

- 一つのFinalizationだけ成功させる
- 両者のRating Historyを各1件だけ作成する

## Stale Client Rating

- Client表示値ではなくMatch Snapshotを使用する
- Clientから送られたRating値を信用しない

## Placement Change Exceeds Cap

- Multiplier適用後の小数変動へPlacement capを適用する
- Cap適用後に一度だけ丸める

## No-change Match Finalized

- Unrated等ではMatch完了と戦績更新が起こり得る
- Rating HistoryとCurrent Ratingは変更しない

## Completed Match Invalidated Twice

- 同じ無効化に対するCorrectionを一度だけ適用する
- 二重相殺を防止する

## Correction Crosses Any Conventional Bound

- MVPには人工的な上下限がないためCorrectionをそのまま適用する
- 監査履歴を残す

## Parameter Changes

- 新Parameterは原則として今後のMatchへ適用する
- 過去Match履歴には当時のParameter versionを保持する
- 過去Matchを自動再計算しない

---

# 8. Error Handling

## Missing Snapshot

- Rated Matchを確定しない
- Ratingを推測して補完しない
- 運営調査可能なエラーとして記録する

## Invalid Winner / Loser

- Match参加者以外を受け付けない
- WinnerとLoserが同一の場合は拒否する
- Rating変更を行わない

## Calculation Failure

- MatchをRating適用済みにしない
- Rating HistoryとCurrent Ratingの部分更新を残さない
- 安全なRetryを可能にする

## Duplicate Finalization

- 既存のApplied結果を返す
- 新しいRating Historyを追加しない

## Preview Failure

- Match成立を不正に妨げない
- Previewを表示できない旨を示す
- Server側の最終計算へ影響させない

## Correction Failure

- 無効化とCorrectionの状態を混同しない
- Current Ratingだけを変更しない
- Adminへ未完了状態を表示しRetry可能にする

## Unauthorized Request

- Ratingの具体的な内部情報を不要に漏らさない
- Clientからの直接更新を拒否する
- 監査用ログを残す

---

# 9. Permissions

## Guest

- 公開プロフィール・ランキングで公開Ratingを閲覧できる
- Rating Preview、History詳細、更新処理を直接実行できない

## Logged-in User

- 自分のCurrent Ratingと許可されたRating Historyを閲覧できる
- Find Opponentで許可されたPreviewを確認できる
- Rating値や変動値を指定・更新できない
- Correctionを実行できない

## Owner

このFeatureではOwnerをRating対象プレイヤー本人として扱う。

- 自分の公開・非公開範囲に応じたRating情報を閲覧できる
- 自分のRating Historyを削除・改変できない
- Match結果報告を通じてのみRating確定の前提を提供できる

## Admin

- Dispute解決に必要なRating Snapshot、計算根拠、履歴を閲覧できる
- Admin / Dispute Feature Specに従いMatch無効化とCorrectionを開始できる
- Correction理由と操作履歴を監査可能に残す
- 通常履歴を直接削除・上書きしない

---

# 10. Data

## Rating Profile

- Player
- Current Rating
- Placement Status
- Placement Match Count
- Season
- Updated At

## Match Rating Snapshot

- Match
- Player A Rating
- Player B Rating
- Rated / Unrated
- Parameter Version
- Placement State / Multiplier eligibility
- Created At

## Rating History

- Player
- Match（Correctionでは元Match参照を含む）
- Season
- Entry Type: Match Result / Compensating Correction / Season Reset / Initial Placement
- Rating Before
- Opponent Rating（該当時）
- Expected Score（該当時）
- Raw Base Change
- Placement Multiplier
- Applied Cap
- Rounded Final Change
- Rating After
- K
- Scale
- Parameter Version
- Reason / Correction Reference
- Created At
- Idempotency / Finalization Reference

## Rating Parameter Set

- Center
- Scale
- K
- Rounding Rule
- Placement Multipliers
- Placement Cap
- Version
- Effective From

## Match Result Input

- Match
- Winner
- Loser
- Completion Type
- Rated / Unrated
- Finalization Status

---

# 11. Dependencies

- Product Spec
- Architecture
- Matchmaking / Waiting Pool Feature Spec
- FT3 Match Feature Spec
- Result Reporting Feature Spec
- Placement Feature Spec
- Profile / Ranking / History Feature Spec
- Admin / Dispute Feature Spec
- Match state machine
- Season management
- PostgreSQL Transaction・一意制約
- 信頼されたServer / Database処理
- Row Level Security

---

# 12. Non-Functional Requirements

## Performance

- Rating Previewと通常確定をユーザーが実用的と感じる時間内に返す
- 通常確定で全Rating Historyを走査しない
- Ranking取得に毎回履歴全件の再計算を要求しない

## Security

- Rating計算と更新をServer / DB側の信頼された処理だけが行う
- Client入力のRating、Change、Parameterを信用しない
- RLSと権限検証で他人の非公開履歴を保護する
- Admin Correctionを監査可能にする

## Reliability

- FinalizationとCorrectionをAtomicかつIdempotentにする
- DBをTruthとし、RealtimeやClient stateへ依存しない
- Retry、連打、複数Tabで重複変更しない
- 使用ParameterとSnapshotから計算を再現できる

## Accessibility

- Rating変動を色だけで表現しない
- Before / Change / Afterをテキストでも明示する
- 勝敗と増減の意味をスクリーンリーダーで理解できる

## Mobile

- Result確定後のRating変動を小画面でも読み取れる
- Previewと確定値を混同しないラベルを付ける
- Sleep・再接続後もDBから確定結果を復元する

## Localization

- Rating数値・Formula・内部状態は言語非依存とする
- Preview、Unrated、Correction等の説明を日本語・英語で提供する

---

# 13. Acceptance Criteria

## Formula

- [ ] Scale 250、K 64のElo Formulaを使用する
- [ ] 同Rating同士で通常Winner +32 / Loser -32になる
- [ ] Set Score差がRating変動へ影響しない
- [ ] Explicit Forfeitを通常Win / Lossとして計算できる
- [ ] Unrated、`status=cancelled`、Nonterminal、IncidentのみではRatingが変化しない

## Snapshot and Preview

- [ ] Rated Match成立時に両者のRating Snapshotを保存する
- [ ] Previewと本計算が同じCalculator・Parameterを使用する
- [ ] 本計算がClient表示値ではなくSnapshotを使用する
- [ ] Preview失敗がRating整合性を壊さない

## Rounding, Clamp, and Bounds

- [ ] 小数変動を最後に一度だけ四捨五入する
- [ ] 通常RatedでWinner +N / Loser -Nを適用する
- [ ] 通常Ratedに追加Clampを適用しない
- [ ] MVPで人工的なRating上限・下限を適用しない

## Placement Connection

- [ ] base change → multiplier → cap → roundの順で処理する
- [ ] Placement倍率・CapをPlacement Feature Specの設定から取得する
- [ ] Placement後は通常倍率×1.0になる

## Atomicity and Idempotency

- [ ] Match確定、Rating History、Current Rating、戦績更新がAtomicである
- [ ] 途中失敗時に部分更新が残らない
- [ ] Retryや同時送信でRatingを二重適用しない
- [ ] 1 Rated Match × 1 Playerにつき通常Rating Historyが1件である

## History and Parameters

- [ ] Rating Before / Change / Afterを保存する
- [ ] Expected Score、K、Scale、Parameter Version等から計算を再現できる
- [ ] Parameterが一元管理される
- [ ] 過去履歴が新Parameter適用時に自動改変されない

## Historical Correction

- [ ] Completed Rated Match無効化時に後続Matchを全再計算しない
- [ ] 元変動を相殺するCompensating Rating Correctionを追加できる
- [ ] Correctionが独立したRating Historyとして監査可能である
- [ ] 同じCorrectionを二重適用しない
- [ ] CorrectionとCurrent Rating更新がAtomicである
- [ ] 元の通常Rating Historyを削除・上書きしない

## Quality

- [ ] 日本語・英語でRating結果を理解できる
- [ ] モバイル・PCでBefore / Change / Afterを確認できる
- [ ] Rating変動を色だけに依存せず表示する
- [ ] 一般ユーザーがRatingを直接改変できない

---

# 14. Out of Scope

- Set Score差によるRating補正
- キャラクター別Rating
- ゲームごとのRating
- AI / MLによるRating計算
- 通常Rated Matchへの追加Clamp
- MVPでの人工的Rating上限・下限
- 過去Match無効化後の後続Match全再計算
- ClientによるRating値・変動値の指定
- リアルタイムのゲーム内戦況からのRating予測
- Tournament固有のRating Rule
- Character Practice固有のRating Rule

---

# 15. Open Questions

Rating Systemの通常MVPフローをBlockするOpen Questionはない。

以下は関連Feature Specで詳細化する。

## OQ-01 Placement Details

- Placement倍率・Capの設定管理
- Placement Match Countの確定タイミング
- Initial Ratingとの接続
- Product Specの暫定値を実装前シミュレーションで検証する

## Resolved — Admin Correction Workflow

- Admin / Dispute Feature Specの認可済みDomain ActionのみがMatchを無効化できる
- Current SeasonではRating correction、Stats correction、Ranking更新、Public History非表示を同じidempotent Domain Actionで行う
- completed SeasonのFinal Snapshotは変更しない
- Correction理由、User通知、監査履歴の詳細はAdmin / Dispute Feature SpecをSource of Truthとする

## OQ-02 Unrated Statistics

- Unrated MatchをProfile戦績へどこまで含めるか
- Ratingは変更しないことのみ確定している
