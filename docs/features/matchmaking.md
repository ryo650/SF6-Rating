# SF6-Rating — Matchmaking / Waiting Pool Feature Spec

Status: Draft  
Feature: Matchmaking / Waiting Pool  
Product: SF6-Rating

---

## Decision Labels

テンプレート構造を維持しながら、仕様の根拠とレビュー優先度を次のラベルで示す。

- **Confirmed**: 会話または上位仕様で明示的に確定した事項
- **Assumption**: MVPを前進させるために置く、後から検証・変更可能な合理的仮説
- **Open Question**: 影響が大きい、または情報不足により未決定の事項
- **Derived Technical Decision**: 確定したプロダクト要件・Architectureから技術的に導出される事項

---

# 1. Feature Overview

## Feature Name

Matchmaking / Waiting Pool

## Summary

Quick Matchによる自動マッチングとFind Opponentによる手動選択を、共通のAvailable Pool上で提供し、実力と通信地域が適切な相手とのFT3を素早く成立させる。

## Purpose

SF6-Ratingの中心価値である「実力の近い相手を短時間で見つけ、すぐ3先を始められること」を実現する。

- 人口を自動マッチと一覧へ分断しない
- 何も考えず早く対戦したいユーザーと、同格・格上・格下から能動的に選びたいユーザーの両方を支える
- Rated対戦の公平性、24時間制限、二重マッチ防止をサーバー側で保証する
- 通信切断やスマートフォンのスリープ後も、Databaseから待機・成立状態を復元できるようにする

---

# 2. User

## Target User

- オンボーディングを完了したログインユーザー
- Placement中または正式Ratingを持つSF6プレイヤー
- スマートフォンまたはPCブラウザでSF6を遊びながら対戦相手を探すユーザー

## User Goal

- Quick Matchで、条件の良いRated対戦相手を自動的かつ短時間で見つける
- Find Opponentで、同格・格上・大幅な格上・格下から対戦可能な相手を自分で選ぶ
- 自分も対戦受付中にして、他ユーザーから選ばれる
- Rated / Unrated、検索範囲、Placement状態、予想Rating変動を理解したうえで対戦を開始する

---

# 3. User Flow

## Quick Match

1. ユーザーがQuick Matchを開始する。
2. システムが参加資格、既存の待機状態、進行中Match、制限状態を確認する。
3. ユーザーは10分間のQuick Match待機状態となり、共通Available Poolへ入る。
4. ユーザーはQuick Match同士の自動マッチ候補となり、同時にFind Opponent一覧からも選択可能になる。
5. システムはRating差・地域・待機時間を考慮して候補を評価する。
6. 条件に合うQuick Matchユーザーが見つかると、サーバーが両者の状態とRated資格を再確認し、MatchをAtomicに作成する。
7. 両者をAvailable Poolから除外する。
8. UIに短いMATCH FOUND演出を表示する。
9. 両者をMatch Roomへ自動遷移させる。
10. 10分以内に成立しなければ待機を終了し、Continue Searchingで新しい10分を開始できる。

## Find Opponent — Browse and Select

1. ユーザーがFind Opponentを開く。
2. 閲覧するだけではユーザー自身はAvailable Poolへ入らない。
3. 同じ国および近隣国にいる、Rating差±500以内のAvailableユーザーを表示する。
4. ユーザーはRecommended、Higher Rated、Challengers、Lower Ratedのカテゴリから相手を探す。
5. 候補カードまたは公開プロフィールを確認する。
6. 「対戦する」を選ぶ。
7. サーバーが双方のAvailability、進行中Match、制限状態、Rated / Unrated資格を再確認する。
8. 条件を満たせば追加承認なしで即MatchをAtomicに作成する。
9. MATCH FOUND演出後、Match Roomへ自動遷移する。

## Find Opponent — 対戦受付中

1. ユーザーがFind Opponent内の「対戦受付中」をONにする。
2. ユーザーは10分間Available Poolへ入り、Find Opponent一覧に表示される。
3. 自動マッチ対象にはならない。
4. サイト内の別ページへ移動しても受付状態を維持する。
5. 他ユーザーから選ばれた場合、サーバーが状態を再確認して即Matchを成立させる。
6. MATCH FOUND演出後、Match Roomへ自動遷移する。
7. 10分経過時は自動終了し、必要なら受付を再開できる。

---

# 4. Functional Requirements

## FR-01 Quick Match

**Confirmed**

- Quick MatchはRated対戦専用とする。
- Quick Match開始時に自動マッチングを有効化する。
- Quick MatchユーザーはFind Opponent一覧にも表示する。
- 自動マッチの相手はQuick Match中のユーザーに限定する。
- 24時間Rated cooldown中の相手は自動候補から除外する。
- 候補が確定した時点で追加承認なしにMatchを成立させる。

## FR-02 Find Opponent

**Confirmed**

- Find OpponentではAvailableな相手をユーザー自身が選択できる。
- 一覧の閲覧だけでは自分をAvailable Poolへ追加しない。
- Find Opponent内で「対戦受付中」をONにした場合のみ、自分を一覧へ掲載する。
- 対戦受付中ユーザーは自動マッチ対象外とする。
- 相手を選択した場合、相手側の追加承認なしで即Match成立を試みる。
- 相手の公開プロフィールを開けるが、閲覧による予約・Lockは行わない。

## FR-03 Common Available Pool

**Confirmed**

- Quick MatchとFind Opponentは共通のAvailable Poolを使用する。
- Available PoolにはQuick Match中または対戦受付中のユーザーだけを含める。
- Quick Match entryは`auto_match_eligible=true`かつ一覧表示可能とする。
- Find Opponent受付中entryは一覧表示のみで`auto_match_eligible=false`とする。
- Find Opponentを閲覧しているだけのユーザー、期限切れユーザー、進行中Matchを持つユーザー、制限中ユーザーは含めない。
- Match成立、手動キャンセル、期限切れ、アカウント制限時にPoolから除外する。

## FR-04 Quick Match Rating Range

**Confirmed**

Quick MatchのRating許容幅は次のとおり段階的に拡張する。

| 経過時間 | Rating許容幅 |
| --- | ---: |
| 0〜60秒 | ±100 |
| 60〜90秒 | ±150 |
| 90〜120秒 | ±200 |
| 120秒以降 | 30秒ごとに±50拡張 |
| 最大 | ±500 |

- 最大±500到達後はそれ以上広げない。
- 最大条件のまま10分の期限まで検索を継続する。
- 相手が見つからない場合はFind Opponentへの導線を表示する。

## FR-05 Regional Expansion

**Confirmed**

Quick Matchの地域範囲は時間経過に応じて拡張する。

| 経過時間 | 対象地域 |
| --- | --- |
| 0〜60秒 | 同じ大地域 |
| 60〜120秒 | 同じ国 |
| 120秒以降 | 近隣国を含む |

- Find Opponentは待ち時間による解放を必要とせず、最初から同じ国および近隣国を表示する。
- Find Opponentでは同じ大地域、同じ国、近隣国の順に優先表示する。
- **Assumption:** 国・大地域・近隣国は設定データとして管理し、実利用データに基づき変更可能とする。

## FR-06 Candidate Ranking

**Confirmed**

Quick MatchとFind Opponentの候補評価では、次の順序を重視する。

1. Rating差
2. 地域の近さ
3. 待機時間

**Assumption**

- 正確な重みは設定可能な値として実装し、利用データに基づいて調整する。
- 単純な固定順位ではなく総合スコアを用いるが、ユーザーへ複雑な数式は表示しない。

## FR-07 Find Opponent Categories

**Confirmed**

自分とのRating差により、重複なしで次のカテゴリへ分類する。

| カテゴリ | Rating差 |
| --- | ---: |
| Recommended | -100〜+100 |
| Higher Rated | +101〜+400 |
| Challengers | +401〜+500 |
| Lower Rated | -101〜-500 |

- Challengersは明確な格上へ挑戦する特別枠としてHigher Ratedから分離する。
- Find Opponentの表示対象はRating差±500以内とする。
- Lower RatedはMVPでは細分化しない。
- **Assumption:** Challengersには通常候補より挑戦感のあるVisual Treatmentを適用するが、過剰な演出はMVP必須としない。

## FR-08 Candidate Card

**Confirmed**

Find Opponentの候補カードには次を表示する。

- SF6-Ratingユーザー名
- プロフィールアイコン
- 現在Rating
- 自分とのRating差
- 国
- 待機時間
- Rated / Unrated
- Placement進行状況
- 所属カテゴリ

次は表示しない。

- 使用予定キャラクター
- メインキャラクター
- キャラクター使用率
- その他のキャラクター情報
- 勝率
- 詳細戦績

勝率や詳細戦績は公開プロフィールを開いた場合のみ確認できる。

## FR-09 Rated / Unrated Eligibility

**Confirmed**

- Quick MatchはRatedのみ成立させる。
- 同じ2プレイヤー間の直近Rated結果確定時刻から24時間以内は、両者間をRated対象外とする。
- Find Opponentではcooldown中の相手も表示し、Unratedと明示する。
- Unrated相手を選択した場合は最初からUnrated Matchとして作成する。
- Unrated対戦を行っても24時間期限を延長またはリセットしない。
- 24時間の判定はMatch作成直前にサーバー側で再確認する。
- Player pairは順序非依存canonical pair keyで識別する。
- Match作成Transaction内でpair単位Lockまたは同等の直列化を行い、cooldown判定とMatch作成を同一Transactionで処理する。
- Rated / Unrated判定はClient指定だけに依存させない。

## FR-10 Rating Change Preview

**Confirmed**

- Find OpponentではRated候補に対し、勝利時・敗北時の概算Rating変動を表示する。
- 例: `Win: +61 / Loss: -3`
- Quick Matchでは具体的な増減予測を表示しない。
- Challengersでは増減予測を視覚的に強調できる。
- Unrated候補にはRatingが変動しないことを表示する。
- **Derived Technical Decision:** 概算値とMatch確定時の計算が同じRatingルールを使用し、表示差異を防ぐ。

## FR-11 Placement Players

**Confirmed**

- Placement専用Poolは作成しない。
- Placement中のユーザーも通常ユーザーとマッチ可能とする。
- 候補カードでは `Placement 4/10` のように進行状況を表示する。
- Placement Ratingを通常のRating検索・カテゴリ分類に使用する。
- Placement中であることだけを理由に自動マッチから除外しない。

## FR-12 Availability Expiration

**Confirmed**

- Quick Matchと対戦受付中は1回につき最大10分とする。
- 10分経過後は必ず自動終了する。
- ユーザー操作があっても自動延長しない。
- Continue Searchingまたは受付再開により、新しい10分を開始できる。
- 手動キャンセルはいつでも可能で、Match成立前のキャンセルにはペナルティを課さない。
- **Assumption:** 再開時は新しいWaiting Entryとし、前回の待機時間を候補優先度へ引き継がない。

## FR-13 Global Waiting Experience

**Confirmed**

- Quick Matchおよび対戦受付中は、サイト内のページ遷移後も継続する。
- グローバルUIで現在のモード、残り時間、検索状況、キャンセル操作を確認できる。
- Quick Matchでは現在のRating検索幅と地域範囲を簡潔に表示する。
- 地域範囲が拡張された場合はユーザーに通知する。
- ブラウザタブを閉じる、バックグラウンド化する、スマートフォンがスリープする場合でも、DB上の有効期限までは状態を復元できる。
- **Assumption:** 対応ブラウザでは待機中のScreen Wake Lock利用を将来検討できるが、MVPの成立条件には含めない。

## FR-14 Match Found

**Confirmed**

- Matchはサーバー側で即成立させる。
- 成立後はキャンセル確認を挟まず、MATCH FOUND演出後にMatch Roomへ自動遷移する。
- 演出中に相手情報を見てMatchを拒否する操作は提供しない。
- サイト内のどのページにいても成立を通知する。
- **Assumption:** 演出時間は約3秒とし、2〜4秒の範囲でUX検証により調整可能とする。

## FR-15 Matchmaking Restrictions

**Confirmed**

- オンボーディング未完了、アカウント制限中、削除処理中、または進行中Matchを持つユーザーは待機開始・相手選択を行えない。
- Match成立後の単発離脱・通信事故には即時の重いペナルティを課さない。
- 短期間にMatch成立後の離脱・無反応を繰り返す場合は履歴を記録し、一時的なマッチング制限の対象にできる。
- ペナルティの具体値と判定はDispute / AdminまたはMatch Room Feature Specで定義する。

## FR-16 Candidate Loading and Refresh

**Assumption**

- Find Opponentは初期20件を取得し、必要に応じて追加読み込みする。
- Realtime通知でAvailability変化を反映し、画面Focus時または一定間隔でDatabaseから再取得する。
- Realtimeだけを候補一覧のSource of Truthにしない。
- 表示件数と再取得間隔は実利用データに基づき変更可能とする。

---

# 5. Product Rules

1. **Confirmed:** Quick MatchはRated専用である。
2. **Confirmed:** Quick MatchとFind Opponentは共通Available Poolを使用する。
3. **Confirmed:** Quick Matchユーザーは自動マッチ対象であり、Find Opponentからも選択可能である。
4. **Confirmed:** 対戦受付中ユーザーはFind Opponentから選択可能だが、自動マッチ対象ではない。
5. **Confirmed:** Find Opponentの閲覧だけではAvailable状態にならない。
6. **Confirmed:** Find Opponentからの選択は追加承認なしで即Match成立を試みる。
7. **Confirmed:** Match成立前にキャラクター情報を表示しない。
8. **Confirmed:** Quick MatchのRating範囲は±100から開始し、最大±500まで拡張する。
9. **Confirmed:** Quick Matchの地域範囲は同じ大地域、同じ国、近隣国の順に拡張する。
10. **Confirmed:** Find Opponentでは最初から同じ国および近隣国を表示する。
11. **Confirmed:** 同一相手とのRated対戦は、直近Rated結果確定時刻から24時間に1セットまでである。
12. **Confirmed:** 24時間以内の再戦はFind OpponentからUnratedとして成立可能である。
13. **Confirmed:** Unrated対戦は24時間期限を変更しない。
14. **Confirmed:** Placementユーザーを通常Poolから分離しない。
15. **Confirmed:** Availabilityは1回10分で終了し、自動延長しない。
16. **Confirmed:** Match成立前の手動キャンセルはペナルティなしとする。
17. **Confirmed:** 1ユーザーは同時に1つのWaiting状態と1つ以下の進行中Matchだけを持てる。
18. **Derived Technical Decision:** Match作成時に全資格を再検証し、AtomicにMatch作成とWaiting解除を行う。
19. **Derived Technical Decision:** DatabaseをWaiting / Match状態のSource of Truthとし、RealtimeとClient Stateは通知・表示用途に限定する。

---

# 6. States

## User Matchmaking State

### Idle

- Quick Matchでも対戦受付中でもない。
- Find Opponentを閲覧できる。
- Available Poolには表示されない。

### Starting

- 待機開始要求を送信し、参加資格を検証している。
- 重複操作を防ぐため開始操作を一時無効化する。

### Quick Match Searching

- 自動マッチングON。
- Available PoolおよびFind Opponent一覧に表示される。
- 現在の検索Rating幅、地域範囲、残り時間を表示する。
- サイト内を移動可能。

### Accepting Challenges

- Find Opponent内の対戦受付中がON。
- 自動マッチングOFF。
- Available PoolおよびFind Opponent一覧に表示される。
- 残り時間とキャンセルを表示する。
- サイト内を移動可能。

### Matching

- 候補とのMatch作成Transactionを処理中。
- 重複操作を受け付けない。

### Match Found

- MatchはすでにDB上で成立している。
- MATCH FOUND演出を表示する。
- Match Roomへ自動遷移する。

### Expired

- 10分の有効期限が終了した。
- Available Poolから除外されている。
- Continue Searchingまたは受付再開を表示する。

### Cancelled

- ユーザーがMatch成立前に待機を解除した。
- Available Poolから除外されている。
- ペナルティはない。

### Restricted

- 一時的なマッチング制限等により待機・選択ができない。
- 理由と解除予定時刻を、公開すべき範囲で表示する。

### Reconnecting

- 通信またはRealtime接続が切れ、DBから状態を再取得している。
- 復元完了まで新規操作を抑止する。

## Candidate State

- Loading
- Available Rated
- Available Unrated
- Placement
- Unavailable
- Empty
- Error

Unavailableになった候補は対戦ボタンを無効化し、一覧更新後に除外する。

---

# 7. Edge Cases

## Concurrent Selection

複数ユーザーが同じ候補を同時に選択した場合、最初にAtomic Match作成へ成功した1件だけを成立させる。他の要求には相手が利用不可になったことを返す。

## Quick Match and Manual Selection Collision

Quick Matchの自動成立処理とFind Opponentからの選択が同じユーザーへ同時に発生した場合も、1件だけを成立させる。成立したMatchをDBから取得し、もう一方の処理は新しいMatchを作らない。

## Candidate Becomes Unavailable While Viewing Profile

公開プロフィール閲覧では候補をLockしない。対戦選択時に再検証し、利用不可なら一覧へ戻して更新する。

## Expiration During Match Creation

Waiting Entryの期限とMatch作成が競合した場合、Transaction内のサーバー時刻で有効性を判定する。期限後のEntryからMatchを作成しない。

## Cooldown Changes While Viewing

一覧表示後に別処理でRated資格が変わった場合、Match作成時の最新サーバー判定を優先する。表示と異なる場合はRated / Unrated状態をユーザーへ明示して、不意に別種別のMatchへ確定させない。

## Browser Closed or Device Sleep

Waiting EntryはDBに保持し、有効期限内に復帰した場合は現在状態を復元する。期限切れならExpiredとして扱う。Matchが成立済みなら進行中Matchを復元しMatch Roomへ案内する。

## Realtime Event Missed

Realtime通知が届かなくても、画面Focus、再接続、定期再取得によりDB上の最新状態へ同期する。

## Duplicate Start or Cancel

二重クリック、再送、ネットワーク再試行で複数のWaiting Entryを作らない。既に終了済みのEntryへのキャンセルは安全に同じ結果を返す。

## User Opens Multiple Tabs

すべてのTabは同じDB状態へ同期する。複数Tabから異なる待機状態を作れない。Match成立時は各Tabが進行中Matchを認識する。

## No Candidates

一覧が空の場合は空状態を表示し、Quick Match開始または対戦受付中への導線を提供する。Quick Match中なら検索を継続する。

## Rating or Region Changes While Waiting

待機開始時の検索Snapshotを保持するか最新Profileへ追随するかは実装時に一貫させる。MVPでは待機中のProfile変更を制限するか、待機を終了して再開させる。

## Account Restricted While Waiting

制限付与時にWaiting Entryを無効化し、以後のMatch作成を拒否する。

## Match Found Then User Leaves

Matchは成立済みのためWaitingへ戻さない。単発では即時の重いペナルティを課さず、繰り返しはNo-show履歴として扱う。

---

# 8. Error Handling

## Start Failed

- 参加資格を満たさない理由を表示する。
- 既存の有効WaitingまたはMatchがある場合、その状態へ復帰する導線を出す。
- 不明なエラーでは再試行を提供する。
- 失敗時に部分的なWaiting Entryを残さない。

## Candidate Load Failed

- 一覧の取得失敗を表示し、再試行できるようにする。
- 直前の候補を表示し続ける場合は古い可能性を明示する。
- Quick Match状態自体はDB上の有効期限まで維持する。

## Opponent No Longer Available

- 「このプレイヤーはすでにマッチしました」等の明確なメッセージを表示する。
- 新しいMatchを作成しない。
- 一覧を再取得する。

## Match Creation Failed

- Transaction全体をRollbackし、片方だけMatchedになる状態を作らない。
- 両者の現在状態を再取得する。
- 既に成立したMatchがある場合はそのMatchへ復帰させる。
- 安全に再試行できる場合だけ再試行を案内する。

## Reconnection Failure

- Realtime切断自体をMatch失敗とはしない。
- DB取得に失敗した場合は再試行し、状態不明のまま新規待機を開始させない。

## Expired Session

- 期限切れを明示し、Continue Searchingを表示する。
- 自動的に新しい10分を開始しない。

## Localization

- エラーメッセージは日本語・英語で提供する。
- 内部エラーや機密情報をユーザーへ露出しない。

---

# 9. Permissions

## Guest

- 公開プロフィールや公開ランキングは閲覧できる。
- Find OpponentのAvailable一覧、Quick Match、対戦受付中、相手選択は利用できない。

## Logged-in User

- オンボーディングおよびメール認証等の参加条件を満たす場合にMatchmakingを利用できる。
- Find Opponentを閲覧できる。
- 自分のQuick Matchまたは対戦受付中を開始・終了できる。
- Availableな他ユーザーを選択できる。
- 自分の待機状態、残り時間、進行中Matchを確認できる。
- 他人のWaiting状態、Rating、制限、Matchを直接変更できない。

## Owner

- 自分のWaiting Entryだけを開始・キャンセルできる。
- 自分のAvailability modeを変更できる。
- 自分のMatching状態を直接Matchedへ書き換えることはできない。
- Rating、Rated資格、cooldown結果を直接指定できない。

## Admin

- 運営上必要な範囲でWaiting、Match成立失敗、No-show、制限状態を確認できる。
- ユーザー制限の付与・解除によりMatchmaking資格へ影響を与えられる。
- 一般ユーザー向けClientからAdmin権限を利用できない。

すべての書き込みはRLS、Server-side validation、Database制約で保護する。Service Role等の秘密鍵をBrowserへ公開しない。

---

# 10. Data

実際のDB設計ではなく、このFeatureが必要とするプロダクトデータを示す。

## Waiting Entry

- Waiting Entry ID
- User
- Mode: Quick Match / Accepting Challenges
- Status
- Rating Snapshot
- Placement Status / Completed Sets
- Country
- Broad Region
- Started At
- Expires At
- Last Active At
- Cancelled At
- Matched At
- Versionまたは同時更新制御情報

## Available Candidate View

- User
- Public Username
- Avatar
- Current Rating
- Rating Difference
- Country
- Waiting Duration
- Mode
- Rated Eligibility
- Placement Progress
- Category
- Regional Proximity
- Candidate Score

## Matchmaking Eligibility

- Onboarding Completed
- Account Status
- Matchmaking Restriction
- Active Match
- Active Waiting Entry
- Rated Cooldown Between Players
- Placement Status

## Match

- Match ID
- Player A
- Player B
- Rated / Unrated
- Creation Source: Quick Match / Find Opponent
- Status
- Created At
- Rating Snapshot for Both Players
- Placement Snapshot for Both Players
- Regional Match Tier
- Waiting Entry References

## Rated Cooldown

- Canonical Player Pair Key（Player順序に非依存）
- Last Rated Result Confirmed At
- Next Rated Eligible At

24時間の基準はRated Match作成時ではなく、直近Rated結果の確定時刻とする。
pair単位の直列化、cooldown再判定、Match作成は同一Transactionで行う。

## Matchmaking Event / Audit

- Waiting Started
- Search Range Expanded
- Candidate Selected
- Match Creation Succeeded / Failed
- Waiting Cancelled / Expired
- Match Found
- No-showまたは成立後離脱への参照
- Timestamp
- User / Match / Waiting Entry Reference
- Failure Reason Code

分析イベントへSF6ユーザーコード、Email、詳細地域等の不要な個人情報を含めない。

---

# 11. Dependencies

- Account / Profile Feature
- Authenticationおよびメール認証状態
- Placement / Rating System
- 24時間Rated制限
- Match Room
- User Restrictions / Admin
- Country / Broad Region / Nearby Country master data
- Supabase PostgreSQL
- Supabase Realtime
- Next.jsの信頼されたServer処理
- Row Level Security
- Rating change preview calculation
- 日本語・英語のUIおよびエラー文言
- ArchitectureのAtomic transaction、DB as truth、idempotency方針

---

# 12. Non-Functional Requirements

## Performance

- 初期1,000〜10,000登録ユーザー、同時接続100〜300人程度を初期設計目標とする。
- Waiting候補検索に使用するStatus、Rating、Region、Expires At等へ適切なIndexを利用できる。
- Find Opponentは候補をページングまたは追加読み込みし、全Availableユーザーを一括取得しない。
- Ranking、Rating History等の不要なデータを候補一覧で読み込まない。
- Match作成処理は短時間で完了し、長いClient-side lockに依存しない。
- Realtimeは必要な変化だけを通知し、全世界の全待機イベントを全Clientへ配信しない。

## Security

- Waiting、Rated eligibility、Match作成、Restriction判定をサーバー側で検証する。
- ClientがRating、地域、cooldown、Match種別を任意指定して不正なMatchを作れない。
- 1ユーザー1有効Waiting、1ユーザー1以下の進行中MatchをDatabase制約でも保護する。
- Match要求、待機開始、一覧更新等へ通常利用を妨げないRate Limitを適用する。
- キャラクター情報、SF6ユーザーコード、詳細地域、Email、認証情報を候補一覧へ含めない。
- Matchmaking関連の監査ログへSecretや不要な個人情報を保存しない。

## Reliability

- **Derived Technical Decision:** PostgreSQLをWaiting / Match状態のSource of Truthとする。
- **Derived Technical Decision:** Match作成、両Waiting解除、Match参照の設定を1 Transactionで行う。
- **Derived Technical Decision:** 同じ要求の再送で複数Matchを作らないようIdempotencyと一意制約を使用する。
- Realtime切断後はDBから状態を再取得する。
- Waiting expirationはClient timerではなくServer時刻でも強制する。
- ブラウザ閉鎖、Sleep、複数Tab、通信再試行後も状態を復元できる。
- 部分成功により一方だけMatched、または成立後もAvailableに残る状態を作らない。

## Accessibility

- Quick Match、対戦受付中、キャンセル、Continue SearchingをKeyboardで操作できる。
- 検索開始、検索範囲拡張、期限切れ、MATCH FOUND、エラーをスクリーンリーダーへ通知する。
- Rated / Unrated、Placement、カテゴリを色だけで区別しない。
- 残り時間表示を視覚情報だけに依存させない。
- MATCH FOUND演出は過剰な点滅を避け、Reduced Motion設定を尊重する。

## Mobile

- スマートフォンでQuick Match開始、Find Opponent閲覧、相手選択、受付ON/OFF、キャンセルを完了できる。
- ページ遷移・バックグラウンド復帰後もグローバル待機状態を表示する。
- 小さい画面でも主要候補情報とRated / Unratedが欠けない。
- タップ対象をモバイル利用に適した大きさにする。
- Wake LockやPush通知がなくてもDatabaseから正しい状態を復元できる。
- PCブラウザでも同じ機能を利用できる。

## Localization

- 主要UI、状態、カテゴリ、エラー、検索範囲、期限切れ、MATCH FOUNDを日本語・英語で提供する。
- 国・地域・カテゴリは内部IDと表示名を分離する。
- 10分・24時間の判定はServer上の絶対時刻で行い、表示をLocale / Timezoneに合わせる。

## Future Client Compatibility

- **Derived Technical Decision:** Matchmaking、Rated eligibility、Rating preview、Match creationの重要ロジックをNext.js画面コンポーネントへ密結合しない。
- 将来React Native / Expoクライアントが同じBackend処理を利用できる境界を維持する。

---

# 13. Acceptance Criteria

## Quick Match

- [ ] 条件を満たすユーザーがQuick Matchを開始できる
- [ ] Quick Match開始後、10分間自動マッチ対象になる
- [ ] Quick MatchユーザーがFind Opponent一覧にも表示される
- [ ] Quick Match同士だけが自動マッチする
- [ ] 初期Rating範囲が±100である
- [ ] 60秒後から仕様どおりRating範囲が拡張される
- [ ] Rating範囲が±500を超えない
- [ ] 地域範囲が同じ大地域、同じ国、近隣国の順に拡張される
- [ ] 現在のRating範囲と地域範囲を確認できる
- [ ] 24時間cooldown中の相手が自動候補から除外される
- [ ] 最大条件到達後も±500・近隣国を超えずに検索を継続する
- [ ] 相手が見つからない場合にFind Opponentへの導線が表示される

## Find Opponent

- [ ] 一覧を閲覧するだけでは自分がAvailable Poolへ入らない
- [ ] 対戦受付中をONにすると10分間一覧へ表示される
- [ ] 対戦受付中ユーザーが自動マッチ対象にならない
- [ ] 同じ国および近隣国の±500以内の候補が表示される
- [ ] Recommended、Higher Rated、Challengers、Lower Ratedが仕様どおり重複なく分類される
- [ ] 候補カードに必須情報が表示される
- [ ] 候補カードにキャラクター情報、勝率、詳細戦績が表示されない
- [ ] 公開プロフィールを開いても候補が予約されない
- [ ] Rated候補に勝敗時の概算Rating変動が表示される
- [ ] Unrated候補にRatingが変動しないことが表示される
- [ ] cooldown中の相手をUnratedとして選択できる
- [ ] 相手選択後に追加承認なしでMatch成立を試みる

## Availability and Waiting UX

- [ ] Quick Matchと対戦受付中が同じAvailable Poolを使用する
- [ ] 1ユーザーが同時に複数Waiting Entryを持てない
- [ ] 待機中にサイト内の別ページへ移動できる
- [ ] どのページでも現在モード、残り時間、キャンセルを確認できる
- [ ] 10分経過時に自動終了する
- [ ] ユーザー操作があっても自動延長されない
- [ ] Continue Searchingで新しい10分を開始できる
- [ ] Match成立前の手動キャンセルにペナルティがない
- [ ] Match成立、期限切れ、キャンセル、制限時にPoolから除外される
- [ ] ブラウザ復帰時にDBからWaiting / Match状態を復元できる

## Match Creation

- [ ] 相手選択時にAvailability、進行中Match、制限、Rated資格を再検証する
- [ ] Match作成と両者のWaiting解除がAtomicに行われる
- [ ] 同じ相手を複数ユーザーが同時に選択しても1Matchだけ成立する
- [ ] Quick Matchと手動選択が競合しても1Matchだけ成立する
- [ ] 同一ユーザーが同時に複数Matchへ参加しない
- [ ] 重複要求や再送で重複Matchが作成されない
- [ ] 失敗時に一方だけMatchedになる状態が残らない
- [ ] Match成立後にMATCH FOUND演出が表示される
- [ ] Match成立後にMatch Roomへ自動遷移する
- [ ] 演出中に相手を見て拒否する確認操作が存在しない

## Placement and Rating Eligibility

- [ ] Placementユーザーが通常Poolへ参加できる
- [ ] Placement専用Poolが存在しない
- [ ] 候補カードにPlacement進行状況が表示される
- [ ] Placement Ratingで検索範囲とカテゴリを判定する
- [ ] Rated cooldownをServer時刻で判定する
- [ ] Unrated Matchが24時間期限を延長・リセットしない

## Quality

- [ ] Guest、Logged-in User、Owner、Adminの権限がRLSとServer-side validationで守られる
- [ ] Realtime通知を失ってもDatabaseから最新状態へ収束する
- [ ] 複数Tab、通信切断、スマートフォンSleep後も不正な重複状態を作らない
- [ ] 主要フローを日本語・英語で利用できる
- [ ] 主要フローをスマートフォンとPCブラウザで完了できる
- [ ] Keyboardとスクリーンリーダーで主要操作ができる
- [ ] Reduced Motion設定を尊重する

---

# 14. Out of Scope

- ユーザー名検索による特定ユーザーへの直接Challenge
- Friend Match
- フレンド、フォロー、DM
- Party / Team Match
- Character指定Matchmaking
- Match成立前のキャラクター情報表示
- 全世界への無制限Matchmaking
- ±500を超えるQuick Match / Find Opponent
- Ping実測を使った高度な通信品質Matchmaking
- 機械学習によるMatchmaking
- ブロックリストによる候補Filter
- 専用Matchmaking Server
- Redis等の追加Queue基盤
- Native Push通知
- ネイティブアプリ
- Match Room内の詳細フロー
- Result Reporting / Rating確定の詳細
- No-show / Penaltyの具体的閾値
- 高度な不正検知
- Challenger UIの高度な演出

---

# 15. Open Questions

以下は実装を開始できないBlockerではない。合理的な初期値を設定可能なものはAssumptionとして実装し、検証結果を記録する。

## OQ-01 Nearby Country Groups

**Open Question — Non-blocking**

- 日本、韓国、台湾、香港等を含む「近隣国」の具体的Grouping
- 各国のBroad Regionと近隣国の対応
- 通信品質や利用人口に基づくGroup更新方法

MVPでは設定データとして合理的なEast Asia Groupを仮置きする。

## OQ-02 Candidate Score Weights

**Open Question — Non-blocking**

- Rating差、地域、待機時間の具体的な重み
- Quick MatchとFind Opponentで同一の重みを使うか
- 待機時間が長いユーザーをどの程度優先するか

優先順位は確定済みのため、初期重みをAssumptionとして設定し、マッチ成立時間とRating差の実測で調整する。

## OQ-03 Candidate Pagination and Refresh

**Open Question — Low Impact**

- 初期20件が適切か
- 追加読み込み方式
- Realtime以外の再取得間隔

MVPでは初期20件、追加読み込み、Focus時再取得を仮採用する。

## OQ-04 Waiting Activity Detection

**Open Question — Implementation Detail**

- Heartbeat / last_activeの具体的間隔
- Browser background中の判定
- DB expirationの掃除方法

10分のServer-side expirationを必須とし、正確なHeartbeat値はImplementation Planで決める。

## OQ-05 Profile Changes During Waiting

**Open Question — Low Impact**

- Rating、国、大地域等の変更が待機中に発生した場合、Snapshotを維持するか待機を終了するか

MVPでは不整合を避けるため、検索条件へ影響するProfile変更時は待機終了を要求する案を第一候補とする。

## OQ-06 Screen Wake Lock

**Open Question — Future UX**

- 対応ブラウザでQuick Match中にScreen Wake Lockを要求するか
- 省電力・権限拒否時の案内

MVPの正しさはWake Lockへ依存させず、実利用でスリープによる見逃しが問題になった場合に追加検討する。
