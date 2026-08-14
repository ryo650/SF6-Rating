# Admin / Dispute — Feature Spec

Status: Reviewed
Product: SF6-Rating
Related Features: Result Reporting / Rating System / FT3 Match / Seasons

---

# 1. Feature Overview

## Feature Name

Admin / Dispute

## Summary

通常フローで確定できないMatchを運営が限定されたDomain Actionで解決し、対戦完了上の問題を記録して、繰り返すユーザーへ段階的なMatchmaking Restrictionを適用する。

## Purpose

- 正常に確定できないMatchを、人間の判断が必要な場合だけ安全に解決する
- 勝者を推測せず、Ratingの整合性を守る
- Match ResultとCompletion Responsibilityを分け、悪意ではなく正常完了できなかった責任を扱う
- 単発の申告だけで相手を処罰せず、確認済みの問題が繰り返された場合だけ段階的に制限する
- 後日修正でもMatch Historyとcompleted SeasonのFinal Snapshotを保持する

AdminがすべてのMatchを確認する仕組みにはしない。

---

# 2. User

## Target User

- Disputeまたは未提出Matchを抱えるプレイヤー
- Match completionに関するIncidentの対象となるプレイヤー
- Dispute、Incident、Restrictionを処理するAdmin

## User Goal

- プレイヤーは、相手の未提出や報告不一致によってRated Matchへ永久に参加できなくなることを避けたい
- プレイヤーは、根拠のない勝敗変更や制裁を受けず、公平に問題を解決したい
- Adminは、必要な情報を確認し、監査可能なDomain ActionだけでMatchとIncidentを一貫して処理したい

---

# 3. User Flow

## Dispute Resolution

1. MatchがDispute対象になる
2. Dispute Queueへ追加される
3. Adminが双方のreports、revisions、timestamps、match_events、predefined messages、incidents、過去のcompletion failures、restriction historyを確認する
4. AdminがPlayer A側Result採用、Player B側Result採用、`cancelled + admin_invalid_no_rating`のいずれかを選ぶ
5. 必要に応じてMatch Resultとは別にCompletion Responsibilityを記録する
6. 関連Incidentをconfirm、dismiss、またはresponsibility unknownとして処理する
7. Confirmed Reliability Incidentsに基づき、必要なWarningまたはRestrictionを適用する
8. すべてのAdmin操作をAudit Logへ記録する

## Result-reporting Nonresponse

1. 一方のプレイヤーが最初のResult Reportを提出する
2. 5分経過しても相手が提出しない場合、報告済みプレイヤーへ`Report as unresponsive`導線を表示する
3. first reportから30分経過後、報告済みプレイヤーは`Close this match without rating`を選択できる
4. 選択した場合、MatchをNo Ratingで終了し、両者を当該未解決Rated Matchによる参加制限から解放する
5. Non-response Incidentは記録として残す
6. first reportから24時間未解決なら、システムが自動的にNo Rating Closeする

## Mutual No-Rating Resolution

1. Result Mismatchとなった双方へ、No Ratingで終了する選択肢を提示できる
2. 双方が明示的に同意する
3. `Mutual No-Rating Resolution`としてAdminなしで終了する
4. Ratingを変更せず、新しいRated Matchへ参加可能にする

---

# 4. Functional Requirements

## Requirement 1 — Dispute Entry Conditions

以下をAdmin Review対象にできる。

- 双方のResult Reportが不一致で、1回の再確認後も不一致である
- Disconnect / Abandonmentについて双方の主張が食い違う
- Mutual Cancellationと別のResult Reportが競合する
- Completed Matchについて後から重大な問題が判明する

Result Mismatchは、再確認後も不一致の場合に`disputed`とする。

## Requirement 2 — Three Basic Match Resolutions

Adminの基本的なMatch解決は次の3種類に限定する。

1. Player A側のResultを採用し、Rated Matchとして確定する
2. Player B側のResultを採用し、Rated Matchとして確定する
3. Matchを`status=cancelled`、`resolution_type=admin_invalid_no_rating`として終了する

十分な根拠がない場合、Adminは勝者を推測せず、`cancelled + admin_invalid_no_rating`を選ぶ。

## Requirement 3 — Result and Responsibility Separation

- Match ResultとCompletion Responsibilityを独立して判定・保存する
- Matchを`cancelled + admin_invalid_no_rating`にしながら、合理的な根拠がある場合は特定プレイヤーへCompletion Responsibilityを記録できる
- 責任を合理的に特定できない場合は`unknown`とする
- Adminが判断するのは悪意の有無ではなく、Matchを正常完了できなかった責任を合理的に特定できるかである
- Completion Responsibilityだけで勝敗またはRatingを自動決定しない

## Requirement 4 — Structured Incident Record

- Match completion上の問題はStructured Incident Recordとして保存する
- Incidentは少なくとも`reported` / `confirmed` / `dismissed` / `responsibility_unknown`等の状態を持つ
- 実テーブル名と正確なschemaはImplementation Planningで決定する
- Incident Report単体では自動勝敗、Rating変更、Restrictionを発生させない
- Penalty計算の対象は`confirmed`のIncidentだけとする

## Requirement 5 — Nonresponse Escape Flow

- first reportから5分後、未提出が続く場合に`Report as unresponsive`を利用可能にする
- first reportから30分後、報告済みプレイヤーが`Close this match without rating`を選べる
- 選択時はNo Ratingで終了し、当該Matchを理由とする新規Rated参加Blockを解除する
- Non-response Incidentを残す
- 一度No Ratingで閉じたMatchをRated Matchとして復活させない
- first reportから24時間未解決の場合、MVPでは自動的にNo Rating Closeする
- 5分、30分、24時間の判定はserver-sideの時刻を正とし、処理はidempotentにする

## Requirement 6 — Mismatch Timeout and Mutual Resolution

- Result Mismatchは単純なtimeoutだけで自動Closeしない
- 双方がNo Ratingでの終了に明示同意した場合のみ、`Mutual No-Rating Resolution`としてAdminなしで終了できる
- 一方だけの同意ではMutual No-Rating Resolutionを成立させない
- Mutual No-Rating Resolution後にRated Matchとして復活させない

## Requirement 7 — Progressive Restriction

rolling 30 days内のConfirmed Reliability Incidents件数により、次の段階を適用する。

| Confirmed件数 | Action |
| --- | --- |
| 1回目 | Warning |
| 2回目 | Matchmakingを1時間停止 |
| 3回目 | Matchmakingを24時間停止 |
| 4回目以降 | Admin Reviewを行い、最大7日程度の一時停止 |

Reliability Incidentの対象例:

- confirmed no-show
- confirmed abandonment
- repeated result-reporting nonresponse
- confirmed match completion failure

rolling 30 daysは`incident.confirmed_at`を基準とする。同一Matchでは`1 user × 1 match`につき最大1 Reliability Strikeとする。MVP Incident Typesは`no_show | abandonment | result_nonresponse | match_completion_failure`とする。Confirmed Incidentが後から訂正または無効化された場合は今後のstrike countから除外し、既発行RestrictionはAdminの明示的なRevoke / Adjustでのみ変更する。

## Requirement 8 — Restriction Scope

Restriction中は以下を利用不可とする。

- Quick Match
- Find Opponent
- 新規Matchへの参加

Restriction中も以下を利用できる。

- Profile閲覧・利用
- Ranking閲覧
- History閲覧
- Account Settings閲覧・利用

本人にはRestrictionのexpiryと大まかなreasonを表示できる。

## Requirement 9 — Admin Domain Actions

AdminはRating値を自由入力して直接編集できない。Admin UIが許可するのは、少なくとも次のDomain Actionである。

- Confirm Match Result
- Invalidate Match
- Apply Rating Correction
- Confirm Incident
- Dismiss Incident
- Mark Responsibility Unknown
- Apply Restriction
- Revoke Restriction
- Adjust Restriction

各Actionはserver-sideの認可・検証を通し、状態遷移と副作用を一体として安全に実行する。

## Requirement 10 — Completed Match Invalidation

- Completed Rated Matchを後日無効化する場合、後続Matchを含む過去Rating全体を再計算しない
- 元結果を`result_validity=invalidated`として監査用に保持する
- Current SeasonではRating Systemが定義するCompensating Rating CorrectionとStats correctionを同じDomain Actionで処理する
- Rated W/L、Rated Match Count、Win Rate、3-0 / 3-1 / 3-2 breakdownから当該Matchを除外し、Rankingへ修正後Ratingを反映する
- Public Match Historyからは非表示にし、Admin audit historyは保持する
- Placement countは巻き戻さない
- completed SeasonのFinal Rating / Ranking / Stats Snapshotを変更しない
- `source_match_id + correction_type`等を一意にし、Correctionの二重適用を防ぐ

## Requirement 11 — Evidence Available in MVP

MVPではScreenshot、Video、Replayのevidence uploadを作らない。

Adminは少なくとも以下を確認できる。

- reports
- report revisions
- timestamps
- match_events
- predefined messages
- incidents
- past completion failures
- restriction history

確認可能な情報だけでは判断できない場合、Matchは`cancelled + admin_invalid_no_rating`とし、Completion Responsibilityは`unknown`にできる。

## Requirement 12 — Minimal Admin UI

MVPのAdmin UIは次の3領域を最小限提供する。

- Dispute Queue
- Incident Queue
- Restrictions

各Queueは対象、状態、経過時間、関連Match / User、処理に必要な詳細を確認でき、認可されたDomain Actionを実行できる。

## Requirement 13 — Audit Log

Admin操作はAudit Logへ少なくとも以下を記録する。

- Admin ID
- Action
- Target
- Before
- After
- Reason Category
- Timestamp

必要に応じて関連するMatch ID、Incident ID、Restriction ID、Rating Correction IDを関連付ける。

## Requirement 14 — Moderation Privacy

- Incident、Responsibility、Restriction history、Admin note等のModeration情報をPublic Profileへ表示しない
- Restriction対象本人にはexpiryと大まかなreasonを表示できる
- 相手プレイヤーが提出したreportの詳細とinternal noteを本人・第三者へ公開しない

---

# 5. Product Rules

- Admin Reviewは例外処理であり、全Matchを人手確認しない
- 十分な根拠がない場合は勝者を推測しない
- Match ResultとCompletion Responsibilityを分離する
- 悪意の証明を要件にしない
- Incident Report単体では勝敗、Rating、Restrictionを変更しない
- Confirmed IncidentだけをProgressive Restrictionの計算対象にする
- rolling 30 daysのConfirmed Reliability Incidentsを使用する
- No Rating Close後のMatchをRatedとして復活させない
- Result Mismatchはtimeoutだけで自動Closeしない
- Mutual No-Rating Resolutionには双方の明示同意を必要とする
- RestrictionはMatchmakingと新規Match参加へ限定し、閲覧・Account Settingsを妨げない
- AdminはRatingを自由入力編集しない
- 過去のMatch Historyを削除しない
- completed SeasonのFinal Ranking Snapshotを変更しない
- 重要な操作はserver-sideで実行し、Audit Logを残す
- Moderation情報をPublic Profileへ出さない

---

# 6. States

## Match Resolution States

### Awaiting Reports

- Result Reportの提出状況と経過時間を表示する
- 未解決Rated Matchとして次のRated参加をBlockする

### Unresponsive Eligible

- first reportから5分経過後、報告済みプレイヤーへ`Report as unresponsive`を表示する

### No-Rating Close Eligible

- first reportから30分経過後、報告済みプレイヤーへ`Close this match without rating`を表示する

### Reconfirmation Required

- Result Mismatchを確定せず、双方へ1回の再確認を要求する

### Disputed

- 再確認後も不一致、または他のDispute条件に該当する
- Ratingを変更せず、Dispute QueueでAdmin Reviewを待つ

### Resolved — Confirmed Result

- Player A側またはPlayer B側のResultが正式採用される
- Ratedの場合はRating Systemへ一度だけ反映する

### Resolved — Admin Invalid No Rating

- 勝敗をRatingへ反映しない
- 新しいRated Matchへ参加可能にする
- Ratedとして復活させない

### Resolved — Mutual No-Rating

- 双方の明示同意によってAdminなしでNo Rating終了する
- Ratedとして復活させない

## Incident States

### Reported

- 申告を受け付けた状態
- 自動勝敗、Rating変更、Restrictionを発生させない

### Confirmed

- Adminまたは定義済みの確定ルールによりReliability Incidentとして確認された状態
- rolling 30 daysのProgressive Restriction計算対象にできる

### Dismissed

- Incidentとして確認しない
- Penalty計算対象にしない

### Responsibility Unknown

- 問題の発生は扱うが、責任主体を合理的に特定できない
- 特定ユーザーのPenalty計算対象にしない

## Restriction States

### Warning

- Matchmakingを停止せず、本人へWarningを表示する

### Active

- expiryと大まかなreasonを本人へ表示する
- Quick Match、Find Opponent、新規Match参加を無効にする

### Expired

- 期限経過後、新規Match参加を再び許可する
- 履歴は保持する

### Revoked

- AdminがDomain Actionで解除する
- 解除理由とAudit Logを保持する

---

# 7. Edge Cases

- 5分、30分、24時間の境界で双方のReportまたはClose操作が同時に届いても、単一の終端状態だけを確定する
- No Rating Closeと相手のResult Reportが競合した場合、server-sideで先に確定した有効な終端Actionだけを採用し、Ratingを二重適用しない
- Mutual No-Ratingへの双方同意とAdmin Actionが競合しても、Matchを二重解決しない
- 同じIncident Reportが複数回送信されても、Confirmed件数を不当に増やさない
- 同一のcompletion failureから複数の報告が発生しても、同じ責任事象を重複Penaltyしない
- rolling 30-day windowの境界でIncidentが追加・dismiss・訂正された場合も、基準時刻と件数を一貫して計算する
- Restriction適用直前にMatchが成立済みの場合の扱いは、既存Matchの安全な完了を優先し、Implementation Planningで状態遷移を固定する
- Restrictionが期限切れになる瞬間に新規参加要求が届いた場合、server-sideの現在時刻で一貫して判定する
- Completed Rated MatchのCorrectionが再試行されても、両者へ二重Correctionを適用しない
- 対象Matchが旧Season所属でも、completed SeasonのFinal Snapshotを変更しない
- Adminが対象を開いている間に別Adminが解決した場合、古いBefore stateによる上書きを拒否する
- 必要情報が欠損・矛盾している場合、推測でResultを確定しない

---

# 8. Error Handling

- Admin Action失敗時はMatch、Incident、Restriction、Ratingの一部だけが更新された状態を残さない
- 同じActionの再送・再試行で重複Rating change、Correction、Incident confirmation、Restrictionを作らない
- staleな状態に対するAdmin Actionは拒否し、最新状態の再読込を促す
- No Rating Close失敗時は、終了済みと誤表示せず再試行できる
- Rating Correction失敗時は元Matchを削除せず、未完了状態を運営が追跡できる
- 監査記録を必要とするAdmin Actionは、Audit Logを残せない場合に成功扱いにしない
- 認可されていない操作は実行せず、公開情報から内部Reasonや相手のreportを漏らさない
- 判断材料が不十分な場合は`cancelled + admin_invalid_no_rating`を安全側の結果とする

---

# 9. Permissions

## Guest

- Admin UI、Dispute detail、Incident、Restriction detailを利用・閲覧できない
- Public ProfileからModeration情報を閲覧できない

## Logged-in User

- 自分が当事者であるMatchのResult Report、再確認、利用可能なNo Rating Close、Mutual No-Rating同意を操作できる
- 自分に適用中のRestriction expiryと大まかなreasonを確認できる
- 相手のreport詳細、internal note、相手のModeration historyを閲覧できない
- Incidentをconfirm、dismiss、またはRestrictionへ直接変換できない

## Owner

- 自分のReportまたは同意を、許可された状態遷移の範囲で提出できる
- 確定済みのResult、Incident status、Restriction、Audit Logを直接変更できない

## Admin

- Dispute Queue、Incident Queue、Restrictionsを閲覧できる
- 認可されたDomain Actionを実行できる
- Rating値を自由入力編集できない
- completed SeasonのFinal Ranking Snapshotを変更できない
- ActionごとにReason Categoryを選択し、Audit Logを残す

---

# 10. Data

以下はプロダクトとして必要な情報であり、実テーブル名とschemaはImplementation Planningで決定する。

## Dispute

- Dispute ID
- Match ID
- Entry Reason
- Status
- Player A Reports / Revisions
- Player B Reports / Revisions
- Related Events and Messages
- Assigned / Resolved Admin ID
- Resolution Action
- Resolution Reason Category
- Created At / Resolved At

## Match Resolution

- Match ID
- Result Status
- Adopted Result
- Rated / No Rating
- Resolution Source: player agreement / admin / timeout rule
- Finalized At
- Idempotency information

## Completion Responsibility

- Match IDまたはIncident ID
- Responsible User IDまたはUnknown
- Responsibility Category
- Decision Source
- Reason Category
- Decided At

## Incident

- Incident ID
- Match ID
- Reporter User ID
- Subject User IDまたはUnknown
- Incident Type
- Status: reported / confirmed / dismissed / responsibility_unknown等
- Occurred At / Reported At / Reviewed At
- Confirmed At
- Related evidence references available within MVP
- Review Admin ID
- Reason Category

## Restriction

- Restriction ID
- User ID
- Restriction Type
- Source Confirmed Incident IDs
- Starts At
- Expires At
- Status: active / expired / revoked
- Reason Category
- Applied / Revoked Admin ID
- Created At / Revoked At

## Rating Correction

- Correction ID
- Source Match ID
- User ID
- Compensating DeltaまたはRating Systemが定義するCorrection情報
- Applied At
- Idempotency information

## Admin Audit Log

- Audit ID
- Admin ID
- Action
- Target Type / Target ID
- Before
- After
- Reason Category
- Related Entity IDs
- Timestamp

---

# 11. Dependencies

- [Product Spec](../product-spec.md)
- [Architecture](../architecture.md)
- Result Reporting
- Rating System
- FT3 Match
- [Seasons](./seasons.md)
- Matchmaking / Waiting Pool
- Match Room / predefined messages
- Authentication / Admin authorization
- Match History / Public Profile
- server-side scheduling / job execution

---

# 12. Non-Functional Requirements

## Reliability

- Match resolution、Rating反映、Compensating Rating Correction、Incident confirmation、Restrictionはidempotentであること
- 競合操作によって複数の終端状態または二重Rating変動を作らないこと
- 24時間の自動No Rating Closeは再試行可能であること

## Consistency

- Match Result、Completion Responsibility、Incident、Restrictionを独立した概念として一貫して関連付けること
- Rating変更はRating SystemのDomain Actionを通してのみ行うこと
- completed SeasonのFinal SnapshotをCorrectionで変更しないこと

## Security

- Admin UIとDomain Actionは認可されたAdminだけが利用できること
- クライアントからRating値、Incident status、Restriction status、Audit Logを直接変更できないこと
- 相手のreport詳細、internal note、Moderation historyを権限のないユーザーへ返さないこと

## Auditability

- Admin Actionの実行者、対象、変更前後、理由、時刻を追跡できること
- 元のMatch History、Incident history、Restriction historyを削除せず追跡できること

## Privacy

- Moderation情報をPublic Profileへ表示しないこと
- 本人向けRestriction表示はexpiryと大まかなreasonに限定できること

## Localization

- Player向けのDispute、No Rating、Warning、Restriction表示を日本語・英語で理解できること
- Admin向けReason Categoryは一貫した定義を持つこと

## Mobile

- プレイヤーはモバイルでもUnresponsive報告、No Rating Close、Mutual No-Rating同意、Restriction確認を行えること
- Admin UIは最小限の主要処理をPCで確実に行えることを優先し、モバイル最適化の範囲はImplementation Planningで決定する

---

# 13. Acceptance Criteria

- [ ] 再確認後も不一致のResult Mismatchが`disputed`になる
- [ ] Disconnect / Abandonmentの主張不一致、Mutual Cancellationとの競合、Completed Matchの重大問題をAdmin Reviewへ送れる
- [ ] Adminの基本解決がPlayer A Result、Player B Result、`cancelled + admin_invalid_no_rating`の3択に限定される
- [ ] 根拠不足時に勝者を推測せず`cancelled + admin_invalid_no_rating`にできる
- [ ] Match ResultとCompletion Responsibilityを別々に記録できる
- [ ] Responsibilityを合理的に特定できない場合にUnknownとできる
- [ ] Incident Report単体で勝敗、Rating、Restrictionが変化しない
- [ ] Incidentがreported / confirmed / dismissed / responsibility_unknown等の状態を持つ
- [ ] Confirmed IncidentだけがPenalty計算対象になる
- [ ] first reportから5分後にUnresponsive導線が表示される
- [ ] first reportから30分後に報告済みユーザーがNo Rating Closeを選べる
- [ ] No Rating Close後に新しいRated Matchへ参加でき、Non-response Incidentが残る
- [ ] No Rating Close済みMatchがRatedとして復活しない
- [ ] first reportから24時間未解決のMatchが自動No Rating Closeされる
- [ ] Result Mismatchがtimeoutだけでは自動Closeされない
- [ ] 双方の明示同意時だけMutual No-Rating Resolutionが成立する
- [ ] rolling 30 daysのConfirmed Reliability Incidentsに1回目Warning、2回目1時間、3回目24時間、4回目以降Admin Reviewで最大7日程度の制限が適用される
- [ ] Restriction中にQuick Match、Find Opponent、新規Match参加ができない
- [ ] Restriction中もProfile、Ranking、History、Account Settingsを利用できる
- [ ] AdminがRating値を自由入力編集できず、許可されたDomain Actionだけを実行できる
- [ ] Completed Rated Match無効化時に両者へCompensating Rating Correctionが一度だけ適用される
- [ ] 後日無効化でも元のHistoryが削除されず、後続Matchの全Rating再計算を行わない
- [ ] Rating Correctionでcompleted SeasonのFinal Ranking Snapshotが変更されない
- [ ] MVPにScreenshot / Video / Replay evidence uploadが含まれない
- [ ] Adminがreports、revisions、timestamps、match_events、predefined messages、incidents、past completion failures、restriction historyを確認できる
- [ ] Admin UIにDispute Queue、Incident Queue、Restrictionsがある
- [ ] Admin ActionにAdmin ID、Action、Target、Before / After、Reason Category、Timestampを含むAudit Logが残る
- [ ] Structured Incident Recordを保持する
- [ ] Moderation情報がPublic Profileへ表示されない
- [ ] 本人にはRestriction expiryと大まかなreasonだけを表示でき、相手のreport詳細とinternal noteを公開しない
- [ ] 二重送信、再試行、競合操作でMatch解決、Rating、Correction、Incident、Restrictionが重複しない

---

# 14. Out of Scope

- AIによる自動裁定
- 自動不正検知
- Replay解析
- Screenshot evidence system
- Video / Replay evidence upload
- Permanent Ban
- 複雑なBAN管理
- 複雑なAppeal process
- Trust / Reputation score
- Shadow ban
- Adminによる自由なRating編集
- 過去の全Rating再計算

---

# 15. Open Questions

- Incidentの実テーブル名、schema、event model
- 4回目以降の一時停止期間をAdminが選択できる範囲とReason Category
- Completed Matchを重大問題として再審査できる期限
- Restriction適用時にすでに成立しているMatchの具体的な継続・終了ルール
- Admin Queueの優先順位、SLA、通知方法
