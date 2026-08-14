# SF6-Rating — FT3 Match Feature Spec

Status: Draft  
Feature: FT3 Match  
Product: SF6-Rating

判断ラベル:

- **Confirmed**: 会話および上位仕様で確定したプロダクト判断
- **Assumption**: MVPを前進させるための合理的な仮説。実利用や関連Feature Specで検証・変更可能
- **Open Question**: 関連機能との調整または追加判断が必要な未決事項
- **Derived Technical Decision**: 確定したプロダクト要件から導出される技術上の判断

---

# 1. Feature Overview

## Feature Name

FT3 Match

## Summary

マッチした2人がStreet Fighter 6のCustom Roomで1回のFT3（3先）を行うための共通ルール、通常終了・棄権・切断・放棄時の扱い、および結果報告へ渡す情報を定義する。

## Purpose

SF6-Ratingはゲーム自体を実行・監視しない。そのため、外部ゲーム内で行われるFT3について、両者が同じ終了条件を理解し、正常終了だけでなく切断や途中放棄が起きてもRatingと履歴を不正・不整合から守れる共通ルールが必要である。

本Featureは次を実現する。

- 1 Matchにつき1回のFT3を行う
- ゲーム中はSF6へ集中し、終了後に最終結果だけを報告する
- キャラクター変更を含むFT3全体をプレイヤーの実力として扱う
- 一時的な通信事故と、明示的な棄権・未完遂Incidentを区別する
- 悪意を推測するのではなく、Matchを完遂できなかった責任と確認可能な状況を扱う
- 証拠不足のまま自動敗北やRating変更を行わない
- 繰り返されるConfirmed Incidentを段階的ペナルティへ接続できる履歴を残す

---

# 2. User

## Target User

- SF6-RatingでMatchが成立し、SF6のCustom RoomでFT3を行うログインユーザー
- FT3の途中終了や通信問題を解決するAdmin

## User Goal

ユーザーは、ゲームごとにWebアプリを操作せずSF6内でFT3へ集中し、通常終了・棄権・通信問題のいずれでも、公平かつ明確な方法でMatchを終了して結果報告へ進みたい。

---

# 3. User Flow

## Normal Completion

1. MatchmakingでRatedまたはUnratedのMatchが成立する
2. 両者がMatch Roomを使ってSF6のCustom Roomへ合流する
3. 両者がSF6内でFT3を行う
4. 必要に応じてゲーム間でキャラクターを変更する
5. 先に3ゲーム勝利したプレイヤーがセット勝者になる
6. FT3終了後、両者が独立して最終スコアをResult Reportingへ入力する
7. 通常終了結果として (3-0)、(3-1)、(3-2) のいずれかが記録される
8. Result Reporting側で双方の報告を照合し、結果を確定する

## Explicit Forfeit

1. 一方がFT3を続行しないことを自ら決める
2. 本人がWebアプリ上で明示的にForfeitを実行する
3. Forfeitした本人を敗者、相手を勝者として扱う
4. Rated Matchなら通常のWinner / LoserとしてRating計算へ渡す
5. 架空の (3-0) は作らず、Completion TypeをForfeitとして記録する
6. 把握できる場合は終了時点スコアを別データとして保存する

## Temporary Connection Issue and Resume

1. FT3中に一時的な通信問題が発生する
2. 両者が続行に合意する
3. 同じMatch・同じFT3としてCustom Roomへ再合流する
4. 双方が合意した中断時点のスコアからFT3を続行する
5. 新しいRated Matchや24時間Cooldownを追加生成しない

## Disconnect / Abandonment Incident

1. 一方がCustom Roomから退出したと相手が認識する、またはWebアプリ内でも応答がない
2. 残ったユーザーが定型連絡等で復帰を促す
3. 一定時間応答がない場合、Abandonment / Unresponsive Incidentを報告できる
4. Incident報告だけでは自動敗北・自動Rating変更を行わない
5. 相手の復帰、本人の認否、双方の報告、必要に応じたAdmin判断で解決する
6. 報告が食い違う場合はDisputeへ進む
7. 証拠不足で責任不明の場合はMatchを`cancelled + admin_invalid_no_rating`にできるが、Incident履歴は保持する

## Mutual Cancellation

1. 両者がFT3を続行できない、または成立していないと判断する
2. 両者がWebアプリ上でCancellationに合意する
3. MatchをMutual Cancellationとして終了する
4. Ratingを変更しない
5. 片方だけの操作ではMutual Cancellationを確定できない

---

# 4. Functional Requirements

## Requirement 1 — FT3 Rules

**Confirmed**

- 1 Matchは1 FT3 Setを表す
- 先に3ゲーム勝利したプレイヤーをセット勝者とする
- 通常終了の有効スコアは (3-0)、(3-1)、(3-2) と、その対戦相手視点の逆方向だけとする
- 1セットは最大5ゲームとする
- その他のゲーム内設定は原則としてSF6標準設定に従う

## Requirement 2 — Character Changes

**Confirmed**

- セット中のゲーム間でキャラクター変更を自由に認める
- 勝者側固定、敗者側のみ変更可能等の独自制限を設けない
- キャラクター選択を含むFT3全体をプレイヤー単位Ratingの対象とする

## Requirement 3 — No Live Game Entry

**Confirmed**

- ゲームごとの勝敗をリアルタイム入力させない
- 現在スコア、ゲーム番号、Round、使用キャラクターを試合中に入力させない
- 通常終了後に最終スコアだけをResult Reportingへ入力する
- 外部ゲーム内の開始状態を別のMatch statusとして持たない

## Requirement 4 — Rated Status

**Confirmed**

- Rated / UnratedはMatch成立時に固定する
- FT3中、Forfeit時、結果報告時にRated / Unratedを変更できない
- 24時間Cooldown等のRated eligibilityを本Featureから上書きできない

## Requirement 5 — Disconnect Handling

**Confirmed**

- 切断を自動敗北にしない
- SF6-RatingはSF6内の通信切断やCustom Room退出を自動検知したと主張しない
- 一時的な通信問題後、双方合意で続行可能なら同じFT3として続行できる
- 技術問題により双方が成立していないと合意したゲームはやり直せる
- FT3そのものにシステム上の自動Timeoutを設けない

## Requirement 6 — Explicit Forfeit

**Confirmed**

- Explicit Forfeitは、本人がWebアプリ上で明示的に棄権した場合だけ成立する
- Forfeitした本人を敗者、相手を勝者とする
- Rated Matchなら通常どおりWinner / LoserをRating計算へ渡す
- Forfeitを架空の (3-0) として保存しない
- Completion TypeをForfeitとして保存できる
- 把握できる場合は終了時点スコアを通常のFinal Set Scoreとは別に保存できる
- Forfeit操作は結果とRatingに影響するため、実行前に明確な確認を要求する

## Requirement 7 — Abandonment / Unresponsive Incident

**Confirmed**

- Custom Roomから退出したと相手が認識した場合や、Webアプリ内でも一定時間連絡が取れない場合にIncident報告を可能にする
- IncidentはForfeitと同一視しない
- Incident報告だけで敗者・勝者を確定しない
- Incident報告だけでRatingを変更しない
- 悪意や故意を直接推定する入力を中心にせず、完遂できなかった状況と責任に関する申告を記録する
- 虚偽申告または主張の食い違いはDisputeとして扱う

**Assumption A-01**

- MVPでは、相手が応答しない状態が5分継続したことをAbandonment / Unresponsive Incident報告導線の表示目安とする
- 5分経過だけでIncident確定、自動敗北、自動キャンセルは行わない
- 具体時間は実利用で検証し、設定可能な値として扱う

## Requirement 8 — Incident Confirmation and Penalties

**Confirmed**

次のいずれかを満たすものをConfirmed Incidentとして扱える。

- 本人が放棄または完遂不能の責任を認めた
- 双方の報告が一致した
- Adminが証拠・履歴・双方の申告を確認して放棄または完遂失敗を確定した
- 関連Feature Specで定める同等の確認条件を満たした

Confirmed Incidentは履歴へ残し、繰り返し回数や期間に応じて次の段階的対応へ利用できる。

1. 記録
2. Warning
3. 一時的なMatchmaking制限
4. 繰り返し時の制限延長またはAdmin対応

具体的な閾値、集計期間、制限時間、異議申立て方法はAdmin / Dispute Feature Specで確定する。

## Requirement 9 — Unknown Responsibility

**Confirmed**

- 証拠不足でどちらに責任があるか判断できない場合、Ratingを変更しない
- Matchを`cancelled + admin_invalid_no_rating`へ解決できる
- Match結果を無効または未解決としてもIncident報告履歴を削除しない
- 単なる未確認報告をConfirmed Incidentのペナルティ回数へ自動加算しない

## Requirement 10 — Mutual Cancellation

**Confirmed**

- Mutual Cancellationは双方合意時のみ成立する
- Ratingを変更しない
- 片方だけの申告ではMutual Cancellationを確定しない
- 合意が得られない場合はDisputeまたはIncident解決フローへ進む

## Requirement 11 — Result Boundary

**Confirmed**

- 通常終了ではWinner / LoserとFinal Set ScoreをResult Reportingへ渡す
- ForfeitではWinner / Loser、Completion Type、任意のScore at Terminationを渡す
- Incidentでは未確認の申告と解決状態を渡し、確定前にRating計算を実行しない
- Set Scoreは統計に使用し、Rating計算はWinner / Loserだけを使用する

---

# 5. Product Rules

1. **Confirmed:** 1 Matchにつき1 FT3 Setだけを行う。
2. **Confirmed:** 先に3ゲーム勝利したプレイヤーがセット勝者となる。
3. **Confirmed:** 通常終了スコアは (3-0)、(3-1)、(3-2) に限定する。
4. **Confirmed:** セット途中のキャラクター変更は自由とする。
5. **Confirmed:** ゲームごとのリアルタイム入力を要求しない。
6. **Confirmed:** Rated / UnratedはMatch成立時に固定し、途中変更できない。
7. **Confirmed:** 切断やWebアプリの非接続を自動敗北にしない。
8. **Confirmed:** Explicit Forfeitは本人による明示操作だけで成立する。
9. **Confirmed:** Forfeitは通常終了スコアへ偽装せず、Completion Typeを分ける。
10. **Confirmed:** Abandonment / Unresponsive報告だけでは勝敗・Ratingを確定しない。
11. **Confirmed:** Confirmed Incidentだけを段階的ペナルティの根拠にできる。
12. **Confirmed:** 悪意の推定ではなく、完遂失敗の状況・責任・確認状態を扱う。
13. **Confirmed:** 責任不明ならRatingを変更せず、Incident履歴は保持する。
14. **Confirmed:** Mutual Cancellationは双方合意時のみ成立し、Ratingを変更しない。
15. **Confirmed:** 一時的な通信問題後の続行は同じMatch・同じFT3として扱う。
16. **Confirmed:** 双方が不成立に合意したゲームはやり直せる。
17. **Confirmed:** FT3自体を時間経過だけで自動終了しない。
18. **Confirmed:** Set Scoreは統計データであり、Rating変動量へ使用しない。

---

# 6. States

FT3の外部ゲーム内進行を専用のMatch statusでは表さない。Match全体の主要状態はMatch Room、Result Reporting、Dispute仕様と共通の状態モデルへ従う。

## Active / Awaiting Outcome

- Matchは成立済みで、通常結果、Forfeit、Cancellation、Incidentのいずれも未確定
- UIではActive Matchへ戻る導線とResult Reporting / trouble導線を提供する
- SF6内で現在何ゲーム目かは表示・保存しない

## Normal Result Reported

- 一方または双方が通常終了スコアを報告済み
- 相手の報告待ち、照合、確定はResult Reporting Featureで扱う

## Forfeit Pending Confirmation

- 本人が明示的Forfeitを実行中
- 確認前はRatingへ影響しない
- 確定後はCompletion Type = Forfeitとして結果処理へ進む

## Incident Reported

- Disconnect / Abandonment / Unresponsiveの申告が存在する
- 自動敗北・自動Rating変更は行わない
- 相手の応答、双方一致、本人認否、Admin判断を待つ

## Disputed

- 双方の主張が食い違う、または結果・責任判断にAdmin確認が必要
- Rating確定を保留する
- Dispute / Admin Feature Specに従う

## Mutual Cancellation Pending

- 一方がMutual Cancellationを申請済み
- 相手が合意するまで確定しない

## Cancelled by Mutual Agreement

- 双方がCancellationへ合意済み
- Rating変動なし
- Matchは完了済みの取消結果として履歴へ残す

## Completed

- 通常終了またはConfirmed Forfeitとして結果が確定済み
- RatedならRating処理、Unratedなら履歴処理へ進む

## Cancelled — Admin Invalid No Rating

- 証拠不足等により責任・勝敗を確定できない
- Rating変動なし
- Incident、申告、Admin判断履歴を保持する

---

# 7. Edge Cases

## Temporary Disconnect, Both Players Resume

同じFT3として続行する。新しいMatchを作成せず、Rated eligibilityや24時間Cooldownを二重適用しない。

## Technical Failure During One Game

双方がそのゲームは成立していないと合意した場合、ゲームをやり直せる。SF6-Ratingはゲーム単位の勝敗を保存・強制しない。

## One Player Claims Disconnect, Other Claims Intentional Abandonment

自動判定せずDisputeへ進める。未確認のIncident報告だけでRatingやペナルティを確定しない。

## User Intentionally Leaves but Denies Responsibility

悪意を証明することを必須にしない。双方の申告、過去のConfirmed Incidents、提出可能な証拠、Admin判断を用いる。責任を確定できなければRatingを変更せず`cancelled + admin_invalid_no_rating`とし、Incident履歴は残す。

## Repeated “Connection Issue” Claims

個々の未確認報告だけで処罰しない。本人認否、双方一致、Admin判断等によりConfirmed Incidentとなったものを集計し、Warningや一時Matchmaking制限へ利用する。

## Both Players Explicitly Agree to Stop

Mutual CancellationとしてRating変動なしで終了できる。

## Only One Player Requests Cancellation

Mutual Cancellationを成立させない。相手の応答待ち、Forfeit、Incident、Disputeのいずれかへ進む。

## Forfeit at 0-0

Completion Type = Forfeit、Score at Termination = 0-0として扱える。通常スコア (3-0) を作らない。

## Forfeit at 2-2

Completion Type = Forfeit、Score at Termination = 2-2として扱える。Winner / LoserはForfeitした本人と相手から決定する。

## Both Players Attempt Forfeit Concurrently

Server側で現在状態を検証し、矛盾する2件のForfeit結果を確定しない。必要ならMutual CancellationまたはDisputeへ誘導する。

## Result Report and Incident Report Arrive Concurrently

Server側でMatch状態と既存申告を検証し、通常完了とIncident解決を同時確定しない。食い違う場合はDisputeへ進める。

## Browser Closed During FT3

SF6内では継続可能。再ログイン・再表示時にActive MatchをDBから復元し、結果報告またはIncident対応へ進める。

## Long FT3

時間経過だけでMatchを自動キャンセル・自動敗北にしない。異常に長いActive Matchの運営上の扱いはAdmin / Dispute Feature Specで決める。

---

# 8. Error Handling

## Normal Score Is Invalid

- (2-2)、(4-1)、(3-3) 等を通常終了結果として受け付けない
- 有効な最終スコアを選び直せる
- 不正入力でMatch状態やRatingを変更しない

## Forfeit Submission Failed

- Forfeitを確定済みとして表示しない
- 現在のMatch状態を再取得する
- 再試行できる
- Idempotencyにより二重Forfeit・二重Rating処理を防ぐ

## Incident Report Failed

- 未保存の報告を保存済みとして扱わない
- 再試行を提供する
- 同じIncidentのRetryで重複件数を作らない
- 相手へ未確定の敗北表示をしない

## Mutual Cancellation Conflict

- 相手の合意がない限り取消を確定しない
- 相手が通常結果、Forfeit、Incidentを提出済みなら最新状態を表示する
- 食い違う場合はDisputeへ案内する

## State Cannot Be Confirmed

- DBから最新Match状態を取得できるまで重要操作を抑止する
- Clientの一時状態だけで結果・Rating・Penaltyを確定しない
- 復旧後にDBの状態へ収束する

## Admin Resolution Fails

- 部分的なRating変更やIncident確定を残さない
- 監査可能な失敗記録を残す
- 再試行前に現在の解決状態を検証する

---

# 9. Permissions

## Guest

- FT3 Matchの操作を実行できない
- Active Match、Forfeit、Incident、Cancellationの非公開詳細を閲覧できない

## Logged-in User

- 自分が参加者であるActive MatchのFT3関連操作だけを利用できる
- 通常結果を自分の報告として提出できる
- 自分自身のExplicit Forfeitを実行できる
- 相手のDisconnect / Abandonment / Unresponsive Incidentを報告できる
- Mutual Cancellationを提案または同意できる
- 相手になりすましてForfeit・同意・結果報告できない
- MatchのRated / Unrated、Winner / Loser、Rating、Confirmed Incidentを直接書き換えられない

## Owner

このFeatureではOwnerを対象Matchの参加者として扱う。

- 自分の申告と許可された応答だけを操作できる
- 自分の未確認Incident報告をAdmin確定として扱えない
- 一方的にMutual Cancellationを成立させられない
- 自分に対するConfirmed IncidentやRating処理をClientから取消できない

## Admin

- 双方の報告、Incident履歴、Match Events、必要な証拠を確認できる
- 関連ルールに基づきForfeit、Abandonment、`cancelled + admin_invalid_no_rating`、Mutual Cancellation等を解決できる
- Confirmed Incidentを確定または否認できる
- Rating変更を伴う解決はAtomicかつ監査可能な処理で行う
- 段階的ペナルティをAdmin / Dispute Feature Specの範囲で付与・解除できる
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
- Created At
- Resolution Type: `normal | forfeit | mutual_cancel | admin_invalid_no_rating`
- Winner（確定時）
- Loser（確定時）
- Final Set Score（Normal Completion時）
- Score at Termination（Forfeit時・任意）
- Completed / Cancelled / Disputed / Resolved At
- Resolution Source
- Resolution Versionまたは同等の同時更新制御情報

## FT3 Result Report

- Match
- Reporting Player
- Report Type: Normal Result / Forfeit / Mutual Cancellation Request / Incident
- Reported Winner / Loser（該当時）
- Reported Final Set Score（該当時）
- Score at Termination（該当時）
- Submitted At
- Idempotency Key
- Current Resolution Status

## Incident Report

- Incident ID
- Match
- Reporting Player
- Reported Player
- Incident Type: Disconnect / Abandonment / Unresponsive / Other allowed type
- Situation / Responsibility Code
- Reported At
- Unresponsive Since（把握可能な場合）
- Reporter’s Statement Type
- Counterparty Response
- Confirmation Status: Reported / Acknowledged / Agreed / Admin Confirmed / Rejected / Unresolved
- Confirmed At
- Confirmed By
- Resolution
- Dispute Reference
- Penalty Eligibility
- Audit Metadata

自由入力の詳細や証拠保存の要否はDispute / Admin Feature Specで定義する。

## Mutual Cancellation

- Match
- Requested By
- Requested At
- Counterparty Response
- Agreed At
- Resolution

## Completion Failure History

- User
- Match
- Confirmed Incident
- Incident Category
- Confirmed At
- Resolution Source
- Warning / Restriction Reference

未確認報告とConfirmed Incidentを区別して集計する。

## Analytics Events

- Normal FT3 Completed
- Explicit Forfeit Submitted / Confirmed
- Incident Reported / Confirmed / Rejected / Unresolved
- Mutual Cancellation Requested / Confirmed
- FT3 Result Validation Failed
- Repeated Completion Failure Warning / Restriction Applied

分析イベントへSF6ユーザーコード、メール、詳細地域、不要な証拠内容を含めない。

---

# 11. Dependencies

- Product Spec
- Architecture
- Account / Profile Feature Spec
- Matchmaking / Waiting Pool Feature Spec
- Match Room Feature Spec
- Result Reporting / Rating Feature Spec
- Dispute / Admin Feature Spec
- User Restrictions
- Match state machine
- Atomic transactionとIdempotency
- Rating History
- Match Events / Audit Log
- 日本語・英語のUI文言
- Supabase PostgreSQL
- Row Level Security
- Next.jsの信頼されたServer処理

---

# 12. Non-Functional Requirements

## Performance

- FT3中にゲーム単位の高頻度書込やRealtime更新を要求しない
- 結果報告、Forfeit、Incident、Cancellation操作をモバイル回線でも実用的な時間で処理する
- Completion Failure HistoryをMatchmaking時に全件走査しない
- Admin確認に必要なIncident履歴をページング可能にする

## Security

- 参加者だけが自分のMatchへ結果・Forfeit・Incident・Cancellation操作を送信できる
- Winner / Loser、Rated / Unrated、Rating、Confirmed IncidentをClientから直接確定できない
- ForfeitとMutual Cancellationへ明確な確認を設ける
- 未確認Incident報告を公開プロフィールや公開履歴で確定事実として表示しない
- Admin解決・Rating変更・Penalty付与を監査可能にする
- RLS、Server-side validation、Database制約で保護する
- Service Role等の秘密鍵をBrowserへ公開しない

## Reliability

- **Derived Technical Decision:** FT3の結果確定、Rating History作成、現在Rating更新を必要に応じ1 Transactionで処理する
- **Derived Technical Decision:** Forfeit、Incident、Cancellation、Resultの重複送信をIdempotentにする
- **Derived Technical Decision:** 通常完了、Forfeit、Mutual Cancellation、Admin Invalid No Ratingを同時確定できないよう状態遷移を保護する
- **Derived Technical Decision:** ブラウザやRealtimeをTruthとせず、DBのMatch・Report・Resolution状態から復元する
- 通信Retryや複数TabでRating・Incident・Penaltyを二重適用しない
- 未確認IncidentとConfirmed Incidentをデータ上で混同しない

## Accessibility

- 結果報告、Forfeit、Incident報告、Mutual CancellationをKeyboardで操作できる
- Forfeitが敗北とRating変動につながることを色以外の文言で明示する
- Incidentが即敗北ではないことを明示する
- エラー、相手の応答、Dispute移行をスクリーンリーダーへ通知する
- 重要な確認DialogでFocus管理を行う

## Mobile

- ゲーム中の継続操作を要求しない
- FT3終了後に片手で最終スコアを入力できる
- Forfeit、Incident、Cancellationを誤操作しにくくする
- スマートフォンSleepやBrowser再起動後もActive Matchと申告状態を復元する
- PCブラウザでも同じ主要操作を利用できる

## Localization

- 主要ルール、結果、Forfeit警告、Incident、Cancellation、Dispute案内を日本語・英語で提供する
- Completion Type、Incident Type、Reason Code、Resolution Statusは言語非依存の内部値とする
- 「棄権」「切断」「未応答」「放棄の疑い」「確認済みIncident」を翻訳上も区別する

---

# 13. Acceptance Criteria

## FT3 Rules

- [ ] 1 Matchにつき1 FT3 Setとして扱われる
- [ ] 先に3ゲーム勝利したプレイヤーをセット勝者として報告できる
- [ ] 通常終了スコアとして (3-0)、(3-1)、(3-2) だけを受け付ける
- [ ] セット途中のキャラクター変更を禁止しない
- [ ] ゲームごとのLive Score入力が存在しない
- [ ] FT3終了後に最終スコアだけを報告できる
- [ ] 外部ゲーム内の開始状態を別のMatch statusとして持たない

## Rated / Rating Boundary

- [ ] Rated / UnratedがMatch成立時に固定される
- [ ] FT3中・Forfeit時・結果報告時にRated / Unratedを変更できない
- [ ] Set ScoreがRating変動量へ使用されない
- [ ] Rating計算がWinner / Loserを使用する
- [ ] Unrated MatchでRatingが変更されない

## Disconnect and Resume

- [ ] 切断だけで自動敗北にならない
- [ ] SF6内の切断やCustom Room退出を自動検知済みとして扱わない
- [ ] 双方合意で同じFT3を続行できる
- [ ] 続行時に新しいRated Matchが作成されない
- [ ] 双方が不成立に合意したゲームをやり直せる
- [ ] FT3が時間経過だけで自動終了しない

## Explicit Forfeit

- [ ] 本人だけが自分のExplicit Forfeitを実行できる
- [ ] Forfeit前に敗北・Rating影響を明示して確認する
- [ ] Forfeitした本人が敗者、相手が勝者になる
- [ ] Rated Forfeitで通常のWinner / LoserとしてRating処理できる
- [ ] Forfeitを架空の (3-0) として保存しない
- [ ] Completion Type = Forfeitを保存できる
- [ ] Score at TerminationをFinal Set Scoreと分けて保存できる
- [ ] ForfeitのRetryで結果・Ratingが二重適用されない

## Incident and Dispute

- [ ] Disconnect / Abandonment / Unresponsive Incidentを報告できる
- [ ] MVPでは5分をIncident報告導線の表示目安として扱える
- [ ] 5分経過だけで自動敗北・自動キャンセル・自動Rating変更されない
- [ ] Incident報告だけで勝敗・Rating・Penaltyが確定しない
- [ ] 本人認否、双方一致、Admin判断等によりConfirmed Incidentへ変更できる
- [ ] 主張が食い違う場合にDisputeへ進める
- [ ] 責任不明の場合にRatingを変更せず`cancelled + admin_invalid_no_rating`へ解決できる
- [ ] `cancelled + admin_invalid_no_rating`でもIncident履歴が保持される
- [ ] 未確認報告とConfirmed Incidentが別に扱われる
- [ ] Repeated Confirmed IncidentsをWarning・一時Matchmaking制限へ接続できる
- [ ] 具体的なPenalty閾値を本Featureで固定しない

## Mutual Cancellation

- [ ] 一方がMutual Cancellationを提案できる
- [ ] 相手が明示的に合意した場合だけCancellationが確定する
- [ ] 片方だけの操作でMutual Cancellationが成立しない
- [ ] Mutual CancellationでRatingが変更されない
- [ ] 申告が食い違う場合にDisputeへ進める

## Data Boundary

- [ ] SF6-RatingがゲームごとのLive ScoreをTruthとして保存しない
- [ ] 使用キャラクター、Round、Connection status、Custom Room内部状態をTruthとして保存しない
- [ ] `normal | forfeit | mutual_cancel | admin_invalid_no_rating`を区別できる
- [ ] Admin操作、Incident確定、Rating変更が監査可能である
- [ ] Reload・Sleep・複数Tab後にDBからActive Matchと申告状態を復元できる

## Quality

- [ ] 主要フローを日本語・英語で利用できる
- [ ] スマートフォンとPCブラウザで主要操作を完了できる
- [ ] Keyboardとスクリーンリーダーで主要操作を利用できる
- [ ] RLS、Server-side validation、Database制約で重要操作を保護する
- [ ] エラーやRetryで部分成功・重複Rating・重複Penaltyを残さない

---

# 14. Out of Scope

- ゲームごとのLive Score入力・表示
- 使用キャラクター追跡
- Character別勝敗・Rating
- Round履歴
- Stage履歴・Stageルール管理
- Replayの自動取得
- Replay映像の自動判定
- SF6またはCAPCOM APIとの直接連携
- Custom Room内部状態の取得
- 自動切断検知
- 自動退出検知
- Lag測定・Lag判定
- Ping測定
- ゲーム画面認識
- 自動勝敗取得
- Tournament Rule管理
- Spectator機能
- GameごとのRating
- 悪意・故意をAI等で自動推定する機能
- 高度な不正検知
- Disputeの証拠提出・審査UIの詳細
- Admin解決画面の詳細

---

# 15. Open Questions

以下はFT3 Matchの実装開始を止めるBlockerではない。関連Feature Specで確定する。

## Resolved — Confirmed Incident Criteria

**Resolved by Admin / Dispute Feature Spec**

- 本人認否・双方一致・Admin判断以外にConfirmed Incidentとする条件
- 証拠の種類と信頼度
- Incident報告へ自由記述または画像証拠を含めるか
- Admin判断の監査・異議申立て方法

Dispute / Admin Feature Specで定義する。

## Resolved — Progressive Penalty Thresholds

**Resolved by Admin / Dispute Feature Spec**

- 集計期間
- WarningまでのConfirmed Incident回数
- 一時Matchmaking制限までの回数
- 制限時間と段階的延長
- 制限解除・異議申立て方法
- 回線品質問題と意図的放棄を運用上どこまで区別するか

具体値はAdmin / Dispute Feature Specで定義する。悪意の証明ではなくRepeated Match Completion Failuresを基準にする。

## Resolved — Canonical Match Status Naming

**Resolved by Architecture / Admin / Dispute:** 勝敗なしは`cancelled`とし、理由を`resolution_type`で表す。

## OQ-04 Score at Termination

**Open Question — Low Impact**

- Forfeit時の終了時点スコア入力を必須または任意にするか
- 双方でScore at Terminationが食い違う場合の扱い
- Forfeit統計で終了時点スコアを公開するか

MVPでは任意データとし、Winner / LoserとCompletion Typeを結果確定の中心とする。

## OQ-05 Incident Report Timing

**Assumption Validation — Non-blocking**

- 5分がIncident報告導線の表示目安として適切か
- Match Roomの10分trouble目安との関係
- Webアプリ上の応答をどのイベントで判断するか

MVPでは5分をAssumptionとして開始し、実利用データで検証する。

## Resolved — Historical Rating Correction

**Resolved by Rating System / Admin / Dispute:** 後続履歴を再計算せずCurrent SeasonではCompensating Correction、completed Season Snapshotは固定とする。
