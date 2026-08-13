# Result Reporting — Feature Spec

Status: Draft  
Product: SF6-Rating  
Feature: Result Reporting

本書では、判断の由来を必要な箇所だけ次のラベルで示す。

- **Confirmed**: Product Specまたは人間レビューで確定した要件
- **Assumption**: MVPを前進させるための合理的な仮説。実利用で検証・変更できる
- **Derived Technical Decision**: 確定済み要件とArchitectureから導出される技術判断
- **Open Question**: 関連Featureで明示的に決める未解決事項

---

# 1. Feature Overview

## Feature Name

Result Reporting

## Summary

FT3終了後、両プレイヤーが独立して勝敗と最終Set Scoreを報告し、整合した結果だけをMatch・Rating・戦績へ安全に反映する。

## Purpose

一方的な虚偽報告や入力ミスによる誤確定を防ぎながら、正常な対戦結果を短時間で確定する。

本Featureの責務は以下までとする。

- 通常結果を双方から独立して受け取る
- 入力ミスを送信前確認と不一致時の再確認で減らす
- 一致した結果を一度だけ確定する
- Explicit Forfeit、Mutual Cancellation、Incidentを正しい終了経路へ送る
- 正常確定できないMatchをDisputeへ送る

証拠提出、Admin判定、制裁、過去結果修正はAdmin / Dispute Feature Specの責務とする。

---

# 2. User

## Target User

- FT3を終えたMatch参加者
- 自分からExplicit Forfeitする参加者
- 相手のDisconnect / Abandonment / Unresponsiveを報告する参加者
- Mutual Cancellationを提案または承認する参加者
- Disputeを処理するAdmin

## User Goal

- 自分と相手を取り違えず、最終結果を短時間で正確に報告したい
- 相手の申告に誘導されず、独立して結果を入力したい
- 正常なRated MatchのRatingを即時かつ正確に更新したい
- 入力ミスをDisputeへ進む前に修正したい
- 切断や放棄の疑いがある場合、根拠なく勝敗を自動確定せず運営確認へ送れるようにしたい

---

# 3. User Flow

## Normal Completion

1. FT3終了後、参加者がResult Reportingを開く
2. 画面はログインユーザーを常に **You**、相手を **Opponent** または相手名として表示する
3. ユーザーが大きな選択UIから自分と相手の勝利数を選ぶ
4. 画面が選択結果を大きく表示する
5. ユーザーが **Change** または **Submit** を選ぶ
6. Submit後、相手未提出中は自分の報告を修正できる
7. 相手には具体的な報告内容を見せず、**Opponent submitted their result** のみ表示する
8. 双方の報告を共通形式へ正規化して比較する
9. 一致した場合、Matchを確定する
10. RatedならAtomic TransactionでRatingと戦績を更新する
11. UnratedならRatingを変更せず結果と対象戦績を更新する
12. 両者へ、自分視点の結果とRated時のRating変動を表示する

## Result Mismatch

1. 双方の最初の報告が一致しない
2. 両者へ **Results don't match** を表示する
3. 各ユーザーへ自分自身の報告だけを表示する
4. 相手の報告内容は表示しない
5. 各ユーザーは一度だけ確認または修正して再提出する
6. 再提出後に一致した場合は通常どおり確定する
7. 再提出後も一致しない場合はMatchを `disputed` へ送る

## Explicit Forfeit

1. 本人が **Forfeit Match** を選ぶ
2. 敗北確定とRated時のRating影響を明示する
3. 本人が確認する
4. 相手の追加報告なしで、本人を敗者、相手を勝者として確定する
5. Completion Typeを `forfeit` として保存し、架空の (3-0) を作らない

## Mutual Cancellation

1. 一方がCancellationを申請する
2. 相手へ申請を表示する
3. 相手が明示的に同意した場合だけ `cancelled` として確定する
4. Ratingは変更しない
5. 相手が拒否または未回答の場合はCancellationを確定しない

## Disconnect / Abandonment / Unresponsive

1. 一方が相手の未応答等をIncidentとして報告する
2. Incidentを記録する
3. Incident報告だけでは勝敗・Rating・Penaltyを確定しない
4. 本人認否、双方一致、またはAdmin判断へ進める
5. 主張が食い違う場合はDisputeへ送る

---

# 4. Functional Requirements

## Requirement 1 — Independent Normal Reports

**Confirmed**

- 通常終了では両参加者が勝敗と最終Set Scoreを独立して報告する
- 有効な通常終了スコアは、自分視点で (3-0)、(3-1)、(3-2)、(0-3)、(1-3)、(2-3) とする
- 双方の報告が同じWinnerとSet Scoreへ正規化された場合だけ `completed` へ進む
- 一方だけの通常報告ではMatchを確定しない

## Requirement 2 — Blind Submission

**Confirmed**

- 片方が先に報告しても、相手には **Opponent submitted their result** のみ表示する
- 相手の勝敗・Set Score・Revision内容を、相手自身が有効な報告を確定する前に見せない
- UIで隠すだけでなく、RLSとServer側の読み取り制御でも保護する

## Requirement 3 — Clear Identity and Score Orientation

**Confirmed — UX Decision**

- 結果入力・確認・待機・確定の全段階で、自分と相手のIdentityを明示する
- UIでは内部のPlayer A / Player Bを使用せず、ログインユーザーを常に **You**、相手を **Opponent** または相手名として表示する
- 入力例は **Your wins: 3 / Opponent wins: 1** とする
- 確認例は **You won this FT3, 3–1** とする
- 敗北時も **You lost this FT3, 2–3** のように自分視点で表示する
- 内部DBがplayer_a / player_b形式でも、ユーザーに内部表現の理解を要求しない

## Requirement 4 — Confirmation Before Submission

**Confirmed — UX Decision**

- 通常結果の初回Submit前に必須のConfirmation Stepを設ける
- 選択した両者のIdentity、各勝利数、勝者、最終スコアを大きく表示する
- ユーザーは **Change** または **Submit** を選ぶ
- スマートフォンで押し間違えにくい大きな選択UIと十分なタップ領域を使用する

## Requirement 5 — Editing and Mismatch Correction

**Confirmed**

- 相手が未提出の間は、自分の有効Reportを修正できる
- 双方提出後は自由編集できない
- 最初の比較が不一致なら、各ユーザーは自分の報告を一度だけ確認・修正できる
- 再確認時にも相手の報告内容を見せない
- 再提出後も不一致なら `disputed` とする

## Requirement 6 — Atomic Finalization

**Confirmed / Derived Technical Decision**

双方の通常報告が一致した瞬間、Rated Matchでは1つのAtomic Transactionとして以下を行う。

- Matchをcompletedへ更新
- Winner / Loser / Final Set Score / Completion Typeを確定
- Ratingを計算
- 両プレイヤーのRating Historyを作成
- Current Ratingを更新
- 対象戦績を更新
- Match completion時刻を保存

Unrated MatchではRating計算、Rating History作成、Current Rating更新を行わない。履歴・戦績へ含める範囲は関連Feature Specのルールに従う。

## Requirement 7 — Explicit Forfeit

**Confirmed**

- 本人だけが自分のExplicit Forfeitを実行できる
- 敗北とRated時のRating影響を確認画面で明示する
- 本人の明示的な確認後は、相手の追加報告なしで本人敗北・相手勝利として確定できる
- Forfeitを通常終了の架空の (3-0) に変換しない
- Completion Type = `forfeit` を保存する
- 終了時点スコアを保存する場合もFinal Set Scoreとは分離する
- ユーザー自身による確定後の取消は不可とし、必要時はAdmin対応とする

## Requirement 8 — Incident Does Not Decide the Match

**Confirmed**

- Disconnect / Abandonment / Unresponsive Incidentだけでは自動勝敗を確定しない
- IncidentだけではRatingを変更しない
- IncidentだけではPenaltyを確定しない
- 本人認否、双方一致、またはAdmin判断を必要とする
- 不一致時はDisputeへ送る

## Requirement 9 — Mutual Cancellation

**Confirmed**

- Mutual Cancellationは双方の明示的な合意時だけ成立する
- 一方だけの申請ではMatchを取消さない
- 成立時はRating変動なしで `cancelled` とする
- 通常結果、Forfeit、Incidentと競合する場合は最新状態を検証し、必要ならDisputeへ送る

## Requirement 10 — Unresolved Rated Match Gate

**Confirmed — Product Critical**

- 未解決のRated Matchがあるユーザーは新しいRated Matchへ参加できない
- 対象は報告待ち、再確認待ち、Incident未解決、Disputed等の未解決Rated Matchとする
- Unrated Matchの利用とサイト閲覧は可能
- Rating処理の時系列を保ち、MVPで過去Matchを基準とした後続Rating再計算を不要にする
- Gate判定はServer / DB側で行う

## Requirement 11 — Unresponsive Report Entry Point

**Assumption**

- 最初のResult Reportから5分経過しても相手が報告しない場合、**Opponent hasn't submitted a result** と **Report as unresponsive** を表示する
- 5分経過だけでは自動勝敗、自動Penalty、自動Cancellation、Rating変更を行わない
- 時間値は実利用で検証・調整できる設定値とする

## Requirement 12 — Responsibility Boundary

**Confirmed**

- Result Reportingは正常確定、Forfeit確定、Mutual Cancellation確定、またはDisputeへの送出までを担当する
- Admin判定、証拠、制裁、異議申立て、過去Match修正はAdmin / Dispute Feature Specへ委譲する

---

# 5. Product Rules

1. **Confirmed:** 通常結果は双方の独立報告が一致した場合だけ確定する。
2. **Confirmed:** 相手のReport内容は通常確定前に公開しない。
3. **Confirmed:** 結果入力は常にYou / Opponent視点で表示する。
4. **Confirmed:** 通常結果のSubmit前に確認を必須とする。
5. **Confirmed:** 相手未提出中は自分のReportを修正できる。
6. **Confirmed:** 双方提出後は自由編集できない。
7. **Confirmed:** 不一致時の確認・修正は一度だけとする。
8. **Confirmed:** 二度目も不一致ならDisputeへ送る。
9. **Confirmed:** Rated / UnratedはMatch成立時の値を使用し、結果報告時に変更できない。
10. **Confirmed:** Explicit Forfeitは本人の確認だけで本人敗北として確定できる。
11. **Confirmed:** Forfeitを架空の通常Set Scoreへ変換しない。
12. **Confirmed:** Incident報告だけで勝敗・Rating・Penaltyを確定しない。
13. **Confirmed:** Mutual Cancellationは双方合意時だけ成立する。
14. **Confirmed:** 未解決Rated Matchがある間は新しいRated Matchへ参加できない。
15. **Confirmed:** Normal ResultのSet Scoreは戦績として保存するがRating変動量へ使用しない。
16. **Derived Technical Decision:** RatingをResult Reportから直接変更させない。
17. **Derived Technical Decision:** Match確定処理はIdempotentかつAtomicにする。
18. **Derived Technical Decision:** 1 user × 1 matchにつき有効Reportは1つとする。
19. **Derived Technical Decision:** ClientやRealtimeではなくDBの状態をTruthとする。

---

# 6. States

## Room Setup

- Match成立済みでResult未提出
- Start FT3操作や `playing` 状態は持たない
- 参加者は結果入力、Forfeit、Incident、Cancellationへ進める

## Reporting

- 少なくとも一方がResult Reportを提出済み
- 未提出側へ提出を促す
- 提出済み側には待機状態を表示する
- 相手の具体的なReport内容は表示しない

## Report Confirmation

- 初回Submit前に選択結果を確認している
- **Change / Submit** を表示する
- DB上のMatch確定状態ではなくUI入力状態とする

## Mismatch Review

- 双方の最初のReportが不一致
- 各ユーザーへ自分のReportだけを表示する
- 一度だけ確認・修正できる
- 相手Reportは非公開

## Incident Pending

- Disconnect / Abandonment / Unresponsive等のIncidentが未解決
- 自動勝敗・Rating変更・Penaltyなし
- 本人応答、双方一致、またはAdmin判断を待つ

## Mutual Cancellation Pending

- 一方がCancellationを申請済み
- 相手の明示的な同意待ち
- 合意前はMatchを取消さない

## Completed

- Normal CompletionまたはExplicit Forfeitとして結果確定済み
- RatedならRating処理済み
- 結果とRating変動を自分視点で表示する

## Disputed

- 再提出後も通常結果が不一致
- またはIncident・Cancellation・Forfeit等の主張が競合
- Rating確定を保留し、Admin / Disputeへ委譲する

## Cancelled

- Mutual Cancellationへ双方合意済み
- Rating変動なし
- Cancellation履歴を保持する

`playing` 状態は持たない。状態遷移の基本形は以下とする。

```text
room_setup → reporting → completed
                     ↘ disputed

room_setup / reporting → cancelled
```

---

# 7. Edge Cases

## Both Players Submit the Same Result Simultaneously

- 一度だけFinalizeする
- Rating、Rating History、戦績を二重更新しない

## Duplicate Submission or Retry

- 同じReportを重複作成しない
- 現在のReport revisionまたはFinalization状態を返す

## User Selects the Wrong Side or Score

- Submit前ConfirmationでYou / Opponentと各勝利数を表示する
- 相手未提出中は修正できる
- 比較後の不一致では一度だけ再確認できる

## Both Players Report Different Winners

- 相手内容を見せず再確認へ進める
- 再提出後も不一致ならDisputeへ送る

## Opponent Never Submits

- **Assumption:** 最初のReportから5分後にUnresponsive Report導線を表示する
- 自動勝敗、自動Penalty、Rating変更はしない
- 未解決Rated Match Gateを維持する
- Admin / Dispute側で解決可能にする

## User Forfeits While Opponent Submits a Normal Result

- Serverが現在状態を検証する
- 矛盾するCompletionを同時確定しない
- 先に有効確定した結果へ収束するか、競合時はDisputeへ送る

## Both Players Forfeit Concurrently

- 2人を同時に敗者として確定しない
- 必要に応じMutual CancellationまたはDisputeへ送る

## Mutual Cancellation Request Conflicts with Result or Incident

- 相手の合意なしでCancellationを確定しない
- 現在のMatch状態と既存申告を再取得する
- 解消できない競合はDisputeへ送る

## Browser Closed or Device Sleeps

- Active Match、自分のReport、相手提出済みフラグ、状態をDBから復元する
- 相手の非公開Report内容を復元時にも漏らさない

## Multiple Tabs

- 1 user × 1 matchの有効Report制約を維持する
- 古い画面からの操作は最新状態を再取得させる
- Finalizationを一度だけ実行する

## Unresolved Rated Match Exists

- Quick Match等の新規Rated参加を拒否する
- 未解決Matchへ戻る導線を表示する
- Unratedと閲覧は許可する

---

# 8. Error Handling

## Invalid Normal Score

- 通常終了として有効でないスコアを受け付けない
- You / Opponentの向きを維持して再選択させる
- MatchやRatingを変更しない

## Submission Failed

- 保存済みと誤表示しない
- 入力内容を可能な範囲で保持する
- 再試行を提供する
- 再試行で重複Reportを作らない

## Comparison or Finalization Failed

- Matchをcompletedとして表示しない
- Rating等の部分更新を残さない
- DBから最新状態を再取得する
- 安全に再試行できる

## Mismatch Revision Conflict

- Revision上限と現在状態をServer側で検証する
- 許可されない再編集を拒否する
- 現在の自分のReportとMatch状態を表示する

## Forfeit Confirmation Failed

- Forfeitを確定済みとして表示しない
- 現在状態を再取得して再試行できる
- Ratingを部分更新しない

## Incident Report Failed

- Incidentを保存済みとして扱わない
- 再試行を提供する
- 未保存報告から勝敗・Penaltyを発生させない

## Unauthorized Access

- Match参加者とAdmin以外へReport詳細を返さない
- 相手のReport内容を参加者へも通常確定前は返さない
- 汎用的な権限エラーを表示し、機密情報を含めない

---

# 9. Permissions

## Guest

- Result Reportingを利用できない
- Result Report、Incident、Cancellation等の非公開詳細を閲覧できない

## Logged-in User

- 自分が参加者であるMatchだけResult Reportingを利用できる
- 自分自身のReportを作成・許可範囲内で修正できる
- 自分自身を敗者とするExplicit Forfeitを実行できる
- Incidentを報告できる
- Mutual Cancellationを申請・承認・拒否できる
- 他人として報告できない
- Rating、Winner、Loser、Match status、相手Reportを直接変更・閲覧できない

## Owner

このFeatureではOwnerを対象Matchの参加者として扱う。

- 自分の有効Reportを相手未提出中だけ修正できる
- Mismatch時の一度のRevisionだけ実行できる
- 一方的にCancellationやIncident確定を成立させられない
- 確定済み結果をClientから取消できない

## Admin

- Dispute処理に必要な双方のReport、Revision、Incident、Match Eventsを閲覧できる
- Admin / Dispute Feature Specに従いMatchを解決できる
- Rating変更を伴う解決はAtomicかつ監査可能にする
- 通常ユーザーへ相手Reportを事前公開しない
- Admin操作と判断理由を監査履歴へ残す

---

# 10. Data

実際のDB設計ではなく、本Featureが必要とするプロダクトデータを示す。

## Match

- Match ID
- Player A
- Player B
- Rated / Unrated
- Match Status
- Winner / Loser
- Final Set Score
- Completion Type: Normal / Forfeit / Mutual Cancellation
- Completed / Cancelled / Disputed At
- Rating Finalization Status
- Resolution Versionまたは同等の同時更新制御情報

## Result Report

- Match
- Reporting Player
- Report Type: Normal Result / Forfeit
- Reported Winner
- Player A Score
- Player B Score
- Revision Number
- Submitted At
- Last Revised At
- Confirmation Status
- Idempotency Key

**Derived Technical Decision:** UI入力はYou / Opponent視点から、player_a / player_bを含むNormalized Resultへ変換する。

## Incident Report

- Match
- Reporting Player
- Reported Player
- Incident Type
- Reported At
- Confirmation / Resolution Status
- Dispute Reference

詳細な証拠・判定・制裁データはAdmin / Dispute Feature Specで定義する。

## Mutual Cancellation

- Match
- Requested By
- Requested At
- Counterparty Response
- Responded At
- Resolution

## Rating History

- Match
- Player
- Rating Before
- Rating Change
- Rating After
- Created At

Rated Matchの確定処理だけが作成する。

## UI Projection

- Current User = You
- Opponent
- Your Wins
- Opponent Wins
- Self-perspective Result Text
- Opponent Submitted flag（内容なし）
- Allowed Actions
- Current State

UI Projectionへ相手Reportの具体的内容を含めない。

---

# 11. Dependencies

- Product Spec
- Architecture
- Account / Profile Feature Spec
- Matchmaking / Waiting Pool Feature Spec
- Match Room Feature Spec
- FT3 Match Feature Spec
- Rating System Feature Spec
- Admin / Dispute Feature Spec
- Match state machine
- Rating History
- User Restrictions / Rated eligibility
- Supabase PostgreSQL
- Row Level Security
- Next.jsの信頼されたServer処理
- 日本語・英語のUI文言

---

# 12. Non-Functional Requirements

## Performance

- Result入力と確認画面をモバイル回線でも実用的な時間で表示する
- Report提出後の状態更新を速やかに反映する
- Rating確定処理で不要な全履歴走査を行わない
- 相手未提出状態を高頻度Pollingだけに依存しない

## Security

- 全参加者向けテーブル・View・RPCでRLSまたは同等の権限制御を適用する
- 相手Reportの内容を通常確定前にClientへ返さない
- Rating、Rating History、Winner、Loser、Match statusをClientから直接変更させない
- Server-side validationでMatch参加者、状態、Revision、Rated statusを検証する
- Service Role等の秘密情報をBrowserへ公開しない
- Admin閲覧・解決操作を監査可能にする

## Reliability

- **Derived Technical Decision:** FinalizationをAtomicかつIdempotentにする
- **Derived Technical Decision:** 1 user × 1 matchにつき有効Reportを1つに制限する
- **Derived Technical Decision:** Normal、Forfeit、Cancellation、Disputeを矛盾して同時確定できないよう状態遷移を保護する
- 通信Retry、連打、複数TabでRatingや戦績を二重適用しない
- Realtime通知をTruthにせず、DBから復元する
- 部分的なRating更新を残さない

## Accessibility

- You / Opponentを色だけで区別しない
- Identity、各勝利数、勝敗を文言でも明示する
- 大きな選択肢をKeyboardでも操作できる
- Confirmation DialogのFocusを管理する
- Submission、Mismatch、Completed、Disputedをスクリーンリーダーへ通知する
- エラー箇所と修正方法を明示する

## Mobile

- 主要操作を片手で完了できる
- スコア選択とChange / Submitに十分なタップ領域を確保する
- 誤タップしやすい小さなRadio Buttonだけに依存しない
- 画面幅が狭くてもYou / Opponentと各勝利数を取り違えない
- SleepやBrowser再起動後も状態を復元する
- PCブラウザでも同じ主要フローを利用できる

## Localization

- 主要フロー、確認、Mismatch、Forfeit、Incident、Cancellation、Dispute案内を日本語・英語で提供する
- You / Opponentの内部識別を言語非依存にする
- Score、Completion Type、Report Type、Stateは言語非依存の内部値とする

---

# 13. Acceptance Criteria

## Normal Reporting

- [ ] 両参加者が勝敗と最終Set Scoreを独立して報告できる
- [ ] 一方のReport内容が相手の報告前に表示・取得されない
- [ ] 相手提出済みの場合は **Opponent submitted their result** だけ表示される
- [ ] 双方のReportが同じNormalized Resultの場合だけcompletedになる
- [ ] 一方だけの通常Reportではcompletedにならない

## Identity and Input Safety

- [ ] 入力・確認・確定の全段階でログインユーザーがYouとして表示される
- [ ] 相手がOpponentまたは相手名として明示される
- [ ] **Your wins / Opponent wins** が明示される
- [ ] 確認画面に **You won/lost this FT3, X–Y** 相当の文言が表示される
- [ ] Player A / Bの内部表現をユーザーへ要求しない
- [ ] 初回Submit前にChange / SubmitのConfirmation Stepがある
- [ ] スマートフォンで押し間違えにくい大きな選択UIがある

## Revision and Mismatch

- [ ] 相手未提出中は自分のReportを修正できる
- [ ] 双方提出後は自由編集できない
- [ ] 不一致時に自分のReportだけを確認できる
- [ ] 不一致時も相手Reportを表示・取得できない
- [ ] 一度だけ確認・修正して再提出できる
- [ ] 再提出後も不一致ならdisputedになる

## Finalization

- [ ] Rated MatchのMatch確定、Rating計算、Rating History、Current Rating、戦績更新がAtomicに処理される
- [ ] Unrated MatchでRatingとRating Historyが変更されない
- [ ] 同じMatchを複数回FinalizeしてもRating・戦績が一度分だけ更新される
- [ ] ReportからRating数値を直接指定・変更できない
- [ ] 1 user × 1 matchにつき有効Reportが1つである

## Forfeit

- [ ] 本人だけが自分のExplicit Forfeitを実行できる
- [ ] Forfeit前に敗北・Rating影響を確認できる
- [ ] 本人の確認後、相手Reportなしで本人敗北・相手勝利として確定できる
- [ ] Forfeitが架空の (3-0) として保存されない
- [ ] Completion Type = Forfeitを保存できる
- [ ] ForfeitのRetryで二重確定されない

## Incident and Cancellation

- [ ] Incident報告だけで勝敗・Rating・Penaltyが確定しない
- [ ] **Assumption:** 最初のReportから5分後にUnresponsive Report導線を表示できる
- [ ] 5分経過だけで自動勝敗・自動Penaltyにならない
- [ ] Mutual Cancellationは双方合意時だけ成立する
- [ ] Mutual CancellationでRatingが変更されない
- [ ] 主張が競合する場合にDisputeへ進める

## Rated Match Gate

- [ ] 未解決Rated Matchがあるユーザーは新しいRated Matchへ参加できない
- [ ] 未解決Matchへ戻る導線が表示される
- [ ] Unrated利用とサイト閲覧は可能である
- [ ] GateがClient表示だけでなくServer / DB側でも検証される

## Quality

- [ ] Reload、Sleep、通信切断、複数Tab後にDBから状態を復元できる
- [ ] 主要フローを日本語・英語で利用できる
- [ ] スマートフォンとPCで主要操作を完了できる
- [ ] Keyboardとスクリーンリーダーで主要操作を利用できる
- [ ] RLS、Server-side validation、DB制約で重要データを保護する
- [ ] エラー時に部分成功や重複Ratingを残さない

---

# 14. Out of Scope

- Screenshotによる自動結果認識
- Replay取得・Replay解析
- SF6またはCAPCOM APIからの勝敗取得
- AIによるDispute判定
- 自動切断判定
- 自動退出判定
- 相手Report内容の通常確定前公開
- ユーザー同士の自由入力による結果交渉
- ゲームごとのLive Score入力
- 使用キャラクター・Round・Stage履歴
- 証拠提出UIの詳細
- Admin判定画面の詳細
- Penaltyの具体的閾値・期間
- 過去結果修正時のRating再計算方式

---

# 15. Open Questions

以下はResult Reportingの通常MVPフローを実装開始するBlockerではない。関連Feature Specで確定する。

## OQ-01 Historical Rating Correction

**Open Question — High Impact / Cross-feature**

Adminが過去のcompleted Rated Matchを無効化・変更した場合に、後続Matchを再計算するか、補正Transactionを追加するか。

Rating SystemおよびAdmin / Dispute Feature Specで明示的に決定する。未解決Rated Match Gateは、新規の通常フローでこの問題を発生させないために採用する。

## OQ-02 Unresponsive Resolution SLA

**Open Question — Cross-feature / Non-blocking**

- Unresponsive Report後、Adminまたは自動運用がいつまでに処理するか
- 悪意ある未提出で相手を長時間Rated停止させないための解除方法
- 一時的なRated Gate解除条件
- 通知方法

Admin / Dispute Feature Specで定義する。

## OQ-03 Five-Minute Threshold

**Assumption Validation — Non-blocking**

最初のResult Reportから5分後にUnresponsive Report導線を表示する仮説が適切か。MVPでは設定値として開始し、実利用データで検証する。

## OQ-04 Unrated Statistics

**Open Question — Low Impact**

Unrated Matchを公開戦績・勝率・対戦履歴へどこまで含めるか。Ratingは変更しないことのみ確定している。Profile / History Feature Specで決定する。

## OQ-05 Forfeit Score at Termination

**Open Question — Low Impact**

Forfeit時の終了時点スコア入力を必須、任意、または省略とするか。MVPではCompletion Type、Winner、Loserを中心とし、架空のFinal Set Scoreは作らない。
