# Public Profile Feature Spec

Status: Draft  
Product: SF6-Rating  
Feature: Public Profile

---

# 1. Feature Overview

## Feature Name

Public Profile

## Summary

オンボーディング完了後のプレイヤーについて、現在のRating、Ranking / Placement状態、Rated FT3戦績、確定済み対戦履歴、Season実績を公開するプロフィールページ。

## Purpose

プレイヤーがSF6-Rating上で残した現在の実力、主要戦績、対戦履歴、Season実績を、本人と他ユーザーが一貫した形で確認できるようにする。

Public Profileは自己紹介やSNS交流のためのページではなく、SF6-Ratingにおける確定済みの競技情報を確認するためのページとする。

---

# 2. User

## Target User

- 自分のRating、戦績、対戦履歴、Season実績を確認したいプレイヤー
- 対戦候補、対戦相手、Ranking掲載プレイヤーの実績を確認したいユーザー
- ログインせず公開情報を閲覧するGuest

## User Goal

- プレイヤーの現在のRatingとRanking / Placement状態を確認する
- Rated FT3に限定した主要戦績を確認する
- 確定済みMatch HistoryをRated / Unratedの区別付きで確認する
- Current Seasonと過去Seasonの実績を確認する
- 履歴から対戦相手のPublic Profileへ移動する

---

# 3. User Flow

1. ユーザーが自分または他プレイヤーのPublic Profileを開く
2. OverviewでUsername、Avatar、Country、Current Rating、Ranking PositionまたはPlacement status、Current Season、Rated FT3の主要Statsを確認する
3. Match Historyで確定済みMatchを新しい順に確認する
4. 必要に応じてLoad moreまたはPaginationで過去の履歴を取得する
5. Opponent名から相手のPublic Profileへ移動する
6. SeasonsでCurrent Seasonおよび過去Seasonの記録を確認する

Public Profileはオンボーディング完了後に公開され、MVPではユーザーが非公開へ変更できない。

---

# 4. Functional Requirements

## FR-01 Public Profileの公開

- オンボーディング完了後、Public Profileを常時公開する
- MVPではProfile privacy toggleや非公開アカウントを提供しない
- Guestを含む閲覧者が、許可された公開情報を閲覧できる
- Account削除後はPublic Profile自体を非公開化または削除する

## FR-02 基本表示

プロフィール上部に以下を表示する。

- Username
- Avatar
- Country
- Current Rating
- Ranking Position（Placement完了後）
- Placement status（Placement中。例: `Placement 6/10`、`Not yet ranked`）
- Current Season

Placement中もCurrent Ratingは表示するが、Ranking Positionは表示しない。

## FR-03 非公開情報

Public ProfileおよびPublic APIから以下を返さない。

- SF6 User Code
- Matchmaking用の詳細地域
- Email
- OAuth情報
- Restriction履歴
- Dispute情報
- Admin情報
- その他Account / Profile Feature SpecでPrivateまたはLimitedと定義された情報

SF6 Player NameやSF6 User Codeを対戦相手へ限定公開する責務はMatch Room側に置く。

## FR-04 キャラクター情報

- MVPのPublic ProfileではMain Characterを含むキャラクター情報を表示しない
- Character stats、Character matchup stats、使用率、使用予定Characterも表示しない
- Find OpponentやRankingなどからPublic Profileを開いても、Rated Match成立前のキャラクター非公開ルールを迂回できない
- Accountにキャラクター情報が存在しても、Public Profile用の取得経路から返さない

## FR-05 Headline Stats

OverviewのHeadline StatsはCompleted Rated FT3だけで集計する。

最低限の表示対象:

- Rated Wins
- Rated Losses
- Win Rate
- Rated Match Count

Set Score Breakdownを表示する場合、確定済みの通常終了Scoreに基づき、以下のような結果をRated FT3だけで集計する。

- 3-0 wins / losses
- 3-1 wins / losses
- 3-2 wins / losses

Unrated MatchはHeadline StatsおよびRated Statsへ含めない。

## FR-06 Public Match History

- 確定済みMatchだけを表示する
- Rated / Unratedを明確に区別する
- 各項目に、閲覧者から見たWin / Loss、Opponent、確定済みSet Scoreがある場合のScore、Match種別、確定日時を表示できる
- Rated Matchでは、データが利用可能な場合にRating Before、Rating After、Rating Changeを表示する
- Unrated MatchではRatingが変動しないことが分かる表示にする
- 新しい順に表示し、Load moreまたはPaginationで段階取得する
- 初回から全履歴を一度に取得しない

## FR-07 Moderationおよび未確定情報の除外

以下をPublic Profile、Public Match History、Public APIへ表示または返却しない。

- Result pending
- Disputed
- Abandonment / Disconnect incident
- Warning
- Restriction
- Admin investigation
- その他Moderationまたは未確定状態の情報

Cancelled、Invalidated、未解決MatchはPublic Match Historyへ表示しない。確定した競技結果とModeration情報を分離する。

## FR-08 Explicit Forfeit

- Explicit Forfeitが正式なRated Win / Lossとして確定した場合、Rated Wins / Losses、Win Rate、Rated Match Countへ含める
- Public ProfileではForfeit理由を原則表示しない
- 通常終了のSet Scoreが存在しない場合、架空の3-0やその他のScoreを生成しない
- Forfeit結果と通常終了Scoreをデータ上で区別できるようにする

## FR-09 画面構成

Public Profileは以下を基本構成とする。タブまたは同一ページ内のセクションとして実装できる。

- Overview
- Match History
- Seasons

Rating推移グラフはMVP必須要件にしない。

## FR-10 Opponent Profileへの導線

- Match HistoryのOpponent名から相手のPublic Profileへ遷移できる
- Account削除済みのOpponentは`Deleted Player`等の匿名表示にする
- 匿名表示から削除済みPublic Profileへ遷移できない
- Username変更後も不変のUser / Profile IDにより正しい相手へ関連付ける

## FR-11 Seasons表示

Current Seasonの表示候補:

- Current Rating
- Current Rank
- Rated Wins / Losses
- Win Rate
- Rated Match Count

過去Seasonの表示候補:

- Final Rating
- Final Ranking
- Rated Wins / Losses
- Win Rate
- Rated Match Count

具体的なSeason Snapshot、Ranking計算、Season境界、表示項目はRanking / Seasons Feature SpecをSource of Truthとする。Public Profileはその確定データを表示する。

## FR-12 編集不能な競技情報

- Rating、Stats、Placement進捗、Ranking Position、Season Recordをプロフィール編集から直接変更できない
- Username変更でも内部の不変User / Profile IDによってRating History、Match History、Season Recordとの関連を維持する
- 表示用Usernameを履歴関連付けのKeyとして使用しない

## FR-13 Account削除

- Account削除時はPublic Profile自体を非公開化または削除する
- 過去Matchは競技記録の整合性のため保持できる
- 保持した過去Match上の削除済みユーザーは`Deleted Player`等に匿名化する
- 削除済みユーザーのUsername、Avatar、Public ProfileへのLinkを履歴から公開しない

---

# 5. Product Rules

1. Public Profileはオンボーディング完了後、MVPでは常時公開する。
2. Public Profileへ表示するのは公開可能な確定済み競技情報だけとする。
3. Rated Match成立前のキャラクター非公開ルールをPublic Profileから迂回できない。
4. Headline StatsはCompleted Rated FT3だけで計算する。
5. Unrated MatchはMatch Historyへ表示できるが、Rated Statsへ含めない。
6. Match Historyへ表示するのは確定済みMatchだけとする。
7. Moderation情報、Incident情報、未確定結果は公開しない。
8. Explicit Forfeitは正式に確定したWin / Lossとして戦績へ含めるが、理由を原則公開せず、存在しないSet Scoreを生成しない。
9. Rating、Stats、Placement進捗はServer側の確定データから導出し、プロフィール編集で変更できない。
10. Usernameではなく不変User / Profile IDで履歴を関連付ける。
11. Account削除後はProfileを公開せず、保持する過去Matchは匿名化する。
12. Private / Limitedデータはフロントで隠すだけではなく、Public API、Query、View、RLSの境界で返さない。

---

# 6. States

## Loading

- Profile Header、Overview、Match History、Seasonsの読み込み中状態を表示する
- ページ全体とLoad moreの読み込み状態を区別する

## Active — Placement

- Current Ratingを表示する
- `Placement N/10`と`Not yet ranked`を表示する
- Ranking Positionを表示しない

## Active — Ranked

- Current RatingとRanking Positionを表示する
- Placement完了状態を反映する

## Empty Match History

- 公開可能な確定済みMatchがないことを表示する
- PendingやDisputedの存在を推測できる文言を表示しない

## Empty Seasons

- 表示可能な過去Season Recordがないことを表示する
- Current Season情報は利用可能な範囲で表示する

## Deleted

- Public Profileを表示しない
- 過去MatchのOpponent欄では`Deleted Player`等を表示する

## Not Found / Unavailable

- 存在しない、削除済み、または未公開状態のProfileについてPrivate情報を漏らさない共通表示を行う

## Error

- 取得失敗を表示し、安全に再試行できる
- 失敗時にStaleなPrivate / Limitedデータを表示しない

---

# 7. Edge Cases

## Placement中

Current RatingとPlacement進捗を表示し、Ranking Positionは表示しない。

## Placement完了直後

Ranking eligibilityが反映された最新状態を再取得する。順位算出前は誤った順位を推測表示しない。

## Username変更

過去Match、Rating History、Season Recordを同一人物へ維持し、最新の公開Usernameを表示する。

## Account削除

Profileを公開せず、過去Matchの相手表示を匿名化する。

## Explicit Forfeit

正式確定したRated Win / Lossへ加算する。Scoreが存在しなければScore Breakdownへ加算せず、架空Scoreを表示しない。

## Unrated Match

Public Match HistoryへUnratedとして表示できるが、Rating変動とHeadline Statsへ影響させない。

## Pending / Disputed / Incident

公開履歴へ表示せず、件数や存在を推測できる情報も返さない。

## Match Later Invalidated

無効化後はPublic Match Historyと公開Statsから除外または正式なCorrection結果へ同期する。詳細はResult Reporting / Rating Systemの確定ルールに従う。

## Missing Rating Snapshot

Rating Before / After / Changeを推測せず、その項目だけ表示しない。確定済み勝敗とMatch種別は表示できる。

## Opponent Username Changed or Deleted

不変IDで関連付け、変更済みなら最新公開Username、削除済みなら匿名表示を使う。

## Pagination During New Finalization

安定したCursorまたは同等の方式で重複・欠落を抑え、同一Matchを重複表示しない。

---

# 8. Error Handling

## Profile Fetch Failed

- 取得失敗を明示する
- 再試行手段を提供する
- Private / LimitedデータをFallbackとして使用しない

## Match History Fetch Failed

- Overviewを利用可能なら維持する
- Match Historyだけ再試行できる
- 既に取得した項目を重複追加しない

## Load More Failed

- 現在表示中の履歴を維持する
- 同じCursorから安全に再試行できる
- Errorによって全履歴を初期化しない

## Season Data Unavailable

- Current Profile情報とMatch Historyを利用可能なら維持する
- 未確定のSeason値を推測表示しない

## Unauthorized Private Data Request

- Publicに許可されたProjectionだけを返す
- Private / Limited列、Moderation情報、認証情報を返さない
- 必要な監査ログを残し、ユーザー向けには内部情報を含まない一般的なErrorを表示する

---

# 9. Permissions

## Guest

- 公開中のPublic Profileを閲覧できる
- 公開が許可されたOverview、確定済みMatch History、Season Recordだけを取得できる
- Profile情報や競技情報を変更できない

## Logged-in User

- Guestと同じPublic Profile情報を閲覧できる
- Opponent名から公開中のPublic Profileへ移動できる
- Rating、Stats、Placement進捗、Ranking、Season Recordを変更できない

## Owner

- Account / Profile Feature Specで編集可能とされた自分の公開プロフィール項目を編集できる
- Rating、Stats、Placement進捗、Ranking Position、Match History、Season Recordを直接変更できない
- MVPではPublic Profileを非公開にできない

## Admin

- 管理用途では別の権限境界から必要情報へアクセスできる
- Admin / Moderation情報をPublic ProfileのResponseへ混入させない
- 確定結果の訂正はResult Reporting / Rating Systemの信頼された処理を使用する

Public Profile用の権限はRLS、Server-side authorization、公開専用Query / View / DTO等で保護し、BrowserへService Role等の秘密情報を公開しない。

---

# 10. Data

実際のDBスキーマではなく、Public Profileに必要なプロダクトデータを示す。

## Public Profile Identity

- Immutable User / Profile ID
- Username
- Avatar
- Country
- Onboarding Completed
- Account Status
- Deleted / Anonymized State

## Current Competitive Summary

- Current Season
- Current Rating
- Placement Status
- Placement Completed Rated FT3 Count
- Ranking Eligibility
- Current Ranking Position
- Rated Wins
- Rated Losses
- Rated Match Count
- Win Rate
- Confirmed Set Score Breakdown
- Stats Updated At

## Public Match History Item

- Match ID
- Season ID
- Viewer Player ID
- Opponent IDまたはDeleted Player表示
- Result: Win / Loss
- Confirmed Set Score（存在する場合のみ）
- Match Type: Rated / Unrated
- Rating Before（Ratedかつ利用可能な場合）
- Rating After（Ratedかつ利用可能な場合）
- Rating Change（Ratedかつ利用可能な場合）
- Finalized At
- Public Eligibility

## Season Record

- Season ID / Name
- Season Status
- CurrentまたはFinal Rating
- CurrentまたはFinal Ranking
- Rated Wins
- Rated Losses
- Rated Match Count
- Win Rate
- Snapshot Timestamp

以下はPublic Profile Response Modelへ含めない。

- SF6 User Code
- Detailed Region
- Email / OAuth Data
- Character Data
- Restriction / Warning History
- Dispute / Incident Data
- Admin / Investigation Data
- Pending Result Data
- Forfeit Reason

---

# 11. Dependencies

- Product Spec
- Account / Profile Feature Spec
- Matchmaking Feature Spec
- Result Reporting Feature Spec
- Rating System Feature Spec
- Placement Feature Spec
- Ranking Feature Spec
- Seasons Feature Spec
- Authentication / Onboarding
- Rating History
- Confirmed Match History
- Account deletion / Anonymization
- PostgreSQL
- Row Level Security
- Public APIまたは公開専用Server Query
- 日本語・英語のUI文言

Ranking Position、Current Season、過去Season Recordの最終定義はRanking / Seasons Feature Specへ接続する。

---

# 12. Non-Functional Requirements

## Performance

- Profile HeaderとOverviewを、全Match Historyの都度再集計なしで取得できる
- Current Seasonの頻繁に利用するStatsは集計済みデータまたは効率的なQueryを利用できる
- Match HistoryはCursor Pagination、Pagination、またはLoad moreで段階取得する
- 初回表示で全履歴を取得しない
- 同一ページ内で不要なPrivate / Limitedデータを過剰取得しない

## Security

- Public API、公開Query / View、RLSレベルでPrivate / Limitedデータを返さない
- フロントエンドで非表示にすることだけをSecurity境界にしない
- SF6 User Code、詳細地域、Email / OAuth、Character、Moderation / AdminデータをPublic Responseへ含めない
- Rating、Stats、Placement進捗、Ranking、Season Recordのクライアント直接更新を拒否する
- 不変IDを内部関連付けに使用し、Username変更やAccount削除で他ユーザーの履歴へ誤接続しない

## Reliability

- Match finalization後、公開StatsとMatch Historyが同じ確定結果へ収束する
- Pending、Disputed、Cancelled、Invalidated状態を確定結果として公開しない
- Pagination再試行で重複表示を作らない
- Account削除と匿名化処理を再試行可能かつIdempotentにする
- Stats更新失敗時に未確定値を推測表示しない

## Accessibility

- Rating、Rank、Placement、Win / Loss、Rated / Unratedを色だけで区別しない
- Overview、Match History、Seasonsを見出しとKeyboard操作で移動できる
- Pagination / Load moreのLoading、Success、Errorをスクリーンリーダーへ伝える
- Avatarへ適切な代替表現を提供する

## Mobile

- スマートフォンでOverview、Match History、Seasonsを読みやすく表示する
- Rating変動とRated / Unratedの区別を小さい画面でも確認できる
- Load moreまたはPaginationをTouch操作できる
- PCブラウザでも同じ公開情報へアクセスできる

## Localization

- Profile状態、Placement、Deleted Player、Rated / Unrated、Win / Loss、Errorを日本語・英語で提供する
- 日時、数値、PercentageをLocaleに応じて表示する
- 内部Statusと表示文言を分離する

---

# 13. Acceptance Criteria

## Visibility and Privacy

- [ ] オンボーディング完了後にPublic Profileが公開される
- [ ] MVPでProfile privacy toggleが存在しない
- [ ] Guestが許可された公開情報を閲覧できる
- [ ] SF6 User CodeがPublic ProfileおよびPublic APIから取得できない
- [ ] 詳細地域がPublic ProfileおよびPublic APIから取得できない
- [ ] Email / OAuth情報がPublic ProfileおよびPublic APIから取得できない
- [ ] Restriction、Dispute、Admin情報がPublic ProfileおよびPublic APIから取得できない
- [ ] Main Characterを含むCharacter情報がPublic ProfileおよびPublic APIから取得できない
- [ ] Find OpponentからProfileを開いてもRated Match前のCharacter非公開ルールを迂回できない
- [ ] Private / LimitedデータがRLSまたはServer-side公開境界で除外される

## Overview

- [ ] Username、Avatar、Country、Current Rating、Current Seasonが表示される
- [ ] Placement中はCurrent Ratingと`Placement N/10`が表示され、Ranking Positionが表示されない
- [ ] Placement完了後はRanking Positionを表示できる
- [ ] Rating、Stats、Placement進捗をProfile編集から変更できない
- [ ] Headline StatsがCompleted Rated FT3だけで計算される
- [ ] Unrated MatchがHeadline Statsへ含まれない
- [ ] Set Score Breakdownが存在する確定済みRated Scoreだけで計算される
- [ ] Rating推移グラフがなくてもMVP完了条件を満たす

## Match History

- [ ] 確定済みMatchだけが表示される
- [ ] Rated / Unratedが区別される
- [ ] Rated Matchで利用可能なRating Before / After / Changeを表示できる
- [ ] Unrated MatchにRating変動を表示しない
- [ ] Pending、Disputed、Cancelled、Invalidated、Incident情報が表示されない
- [ ] Warning、Restriction、Admin investigationが表示されない
- [ ] Explicit Forfeitが正式Win / LossとしてRated Statsへ含まれる
- [ ] Forfeit理由が原則表示されない
- [ ] ScoreのないForfeitに架空の3-0が表示されない
- [ ] Match HistoryをLoad moreまたはPaginationで段階取得できる
- [ ] 初回に全履歴を取得しない
- [ ] Opponent名から相手Public Profileへ遷移できる
- [ ] 削除済みOpponentが`Deleted Player`等で匿名表示される

## Identity, Deletion, and Seasons

- [ ] Username変更後も不変IDでMatch HistoryとSeason Recordが維持される
- [ ] Account削除後にPublic Profileへアクセスできない
- [ ] Account削除後の過去Matchが匿名化されて保持される
- [ ] 削除済みUsername、Avatar、Profile Linkが過去Matchから公開されない
- [ ] Overview / Match History / Seasonsの基本構成を提供する
- [ ] Current Season情報を表示できる
- [ ] Ranking / Seasons Feature Specで確定した過去Season Recordを表示できる
- [ ] 主要表示を日本語・英語、スマートフォン、PCブラウザで利用できる

---

# 14. Out of Scope

MVPでは以下を扱わない。

- Bio
- Comments
- Follow
- Friend
- DM
- Likes
- Profile privacy toggle
- Character stats
- Main Character公開
- Character matchup stats
- Achievement system
- Detailed analytics dashboard
- Rating graphの必須化
- Public Profile上のModeration履歴
- Public Profile上のDispute詳細
- Public Profile上のForfeit理由

Post-MVPのTournament実績やCharacter Practice実績は将来の拡張余地としてPublic Profileへ追加できる。ただし、いずれもMVP要件には含めず、対応する将来Feature Specで公開範囲と集計ルールを決定する。

---

# 15. Open Questions

現時点でPublic ProfileのMVP実装を停止するBlockerはない。

## OQ-01 Ranking / Seasons Display Contract

**[Open Question — Non-blocking / Cross-feature]**

- Current Seasonと過去Seasonの最終表示項目
- Ranking Position更新タイミング
- Season Snapshotの取得契約
- Season別Match Historyへの絞り込みをMVPに含めるか

Ranking / Seasons Feature SpecをSource of Truthとして確定後に接続する。Public Profile側ではOverview / Match History / Seasonsの構成と、確定済み公開データだけを表示する境界を維持する。

## OQ-02 Initial Match History Page Size

**[Assumption — Non-blocking / Configuration]**

初回件数は20件程度を候補とし、PerformanceとUXを確認して設定値として調整できるようにする。全履歴を一度に取得しないことは確定要件とする。

## OQ-03 Rating Snapshot Availability

**[Assumption — Non-blocking / Cross-feature]**

Rating Before / After / ChangeがRating Historyから取得できる場合は表示する。過去データにSnapshotがない場合は推測せず非表示とし、勝敗、Opponent、Rated / Unrated、確定日時など利用可能な確定情報だけを表示する。
