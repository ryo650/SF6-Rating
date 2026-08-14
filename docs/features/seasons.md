# Seasons — Feature Spec

Status: Reviewed
Product: SF6-Rating
Related Feature: [Ranking](./ranking.md)

---

# 1. Feature Overview

## Feature Name

Seasons

## Summary

3か月単位でRating競争を区切り、Season終了時の成績を不変のSnapshotとして保存し、次SeasonをSoft Reset後のRatingで開始する。

## Purpose

定期的な競争の区切りと再スタートを提供しながら、過去Seasonの到達実績を保存し、プレイヤーの継続的な成長を比較できるようにする。

---

# 2. User

## Target User

- 現在SeasonでRated FT3とRankingに参加するプレイヤー
- 現在および過去Seasonの成績を確認するユーザー
- Season rolloverを管理・監視する運営者

## User Goal

- Seasonの開始・終了時期と残り期間を理解する
- Season終了時のFinal Rating、Final Ranking、戦績を実績として残す
- 過去の実力を一部引き継ぎながら新Seasonを開始する
- Public Profileで過去Seasonの成績を確認する

---

# 3. User Flow

1. ユーザーがactive Season内でRated FT3を行う
2. 確定したRated結果がCurrent Ratingと当Seasonの戦績へ反映される
3. Season終了30分前になると、新規Rated Matchmakingを停止する
4. 成立済みMatchはSeason終了時点まで継続し、そこまでに確定した結果だけをFinal成績へ反映する
5. 終了時点でRating未確定の旧Season Rated Matchを`cancelled + season_boundary_no_rating`でNo-Rating Closeする
6. Season終了時にeligible playerのFinal Rating、Final Ranking、戦績をSnapshot保存する
7. Placement完了済みプレイヤーへSoft Resetを一度だけ適用する
8. 次Seasonをactiveにし、Placement完了済みプレイヤーをSoft Reset後RatingでRankingへ掲載する
9. Placement途中のプレイヤーは進捗とRatingをそのまま引き継ぎ、Placementを継続する
10. ユーザーはPublic Profileから過去SeasonのSnapshot成績を確認できる

---

# 4. Functional Requirements

## Requirement 1 — Season Definition

- 1 Seasonは3か月とする
- Seasonは少なくとも以下を持つ
  - Season ID
  - NameまたはNumber
  - Start At
  - End At
  - Status: `upcoming` / `active` / `completed`
- DBおよびserver-side処理では時刻をUTCで管理する
- UIではユーザーに適切なローカル時刻または残り期間を表示する
- 同時にactiveとなるSeasonは1つとする

## Requirement 2 — Match Season Attribution

- MatchはMatch成立時にactiveだったSeasonへ所属させる
- Season IDはMatch成立時に確定し、Seasonを跨いでも変更しない
- Season終了時点で未確定のMatchも旧Season所属のまま保持する

## Requirement 3 — Rated Matchmaking Cutoff

- MVPではSeason終了30分前から新規Rated Matchmakingを停止する
- 停止対象には自動マッチングと、待機一覧等から新しいRated Matchを成立させる操作を含む
- すでに成立済みのMatchはSeason終了30分前以降も継続できる
- Unrated Matchの可否はMatchmaking / Rematchの仕様に従い、Rated Season Snapshotへは影響させない

## Requirement 4 — Final Snapshot

- Season終了時点で、各eligible playerについて少なくとも以下をSnapshot保存する
  - Final Rating
  - Final Ranking
  - Rated Wins
  - Rated Losses
  - Win Rate
  - Rated Match Count
- Snapshotは`season_player_records`等のSeason単位・Player単位の記録として保持する
- Final Rankingは[Ranking Feature Spec](./ranking.md)のCurrent Rating降順および同順位ルールに従う
- Season終了時点までに確定したRated結果だけをFinal Snapshotへ反映する
- 保存済みFinal Snapshotは後から変更しない
- Season終了時点で未確定だったMatchが後日解決しても、過去のFinal RankingおよびFinal Snapshotを再計算しない

## Requirement 5 — Soft Reset

- Placement完了済みプレイヤーの新Season Ratingは次式で計算する

  `newRating = 1500 + 0.7 * (previousRating - 1500)`

- `previousRating`には終了SeasonのFinal Ratingを使用する
- 計算結果はRating Systemと整合する方法で整数へ四捨五入する
- Soft Resetは対象Player・新Seasonごとに一度だけ適用する
- Placement完了済み既存ユーザーへ再Placementを要求しない
- Soft Reset後、当該Seasonで0戦でもRanking eligibleとする

## Requirement 6 — Placement Across Seasons

- Season終了時点でPlacement途中のプレイヤーにはSoft Resetを適用しない
- Placement progressとCurrent Ratingをそのまま次Seasonへ引き継ぐ
- Placementを最初からやり直させない
- 引き継いだ進捗が10/10に到達した直後から、新SeasonのRanking eligibleとする

## Requirement 7 — No Opening Activity Requirement

- Season開始時にRated Matchを1戦以上行うことをRanking掲載条件にしない
- MVPではRating Decayまたは高度なActivity requirementを設けない

## Requirement 8 — Past Season Display

- Public Profileで過去Seasonの以下のSnapshotを表示可能とする
  - Final Rank
  - Final Rating
  - Rated Wins / Rated Losses
  - Win Rate
  - Rated Match Count等
- 詳細な絞り込み、比較、分析UIはMVP必須としない

## Requirement 9 — Rollover Safety

- Season rolloverはserver-sideで実行する
- rollover全体をidempotentにし、再試行しても二重Soft Resetや重複Snapshotを発生させない
- 処理を複数段階へ分割してよいが、各Player・各Season単位で以下を保証する
  - Final Snapshotが一意である
  - Soft Resetの適用が一度だけである
  - 中断後に安全に再開できる
  - 完了済み処理を再実行しても値が変化しない

## Requirement 10 — Season Boundary No-Rating Close

- Season終了時点でRating未確定の旧Season Rated Matchをすべて`status=cancelled`、`resolution_type=season_boundary_no_rating`、`rating_status=not_applicable`で終了する
- 終了処理はserver-sideかつidempotentに行い、Rated Match gateを解除する
- 関連するDispute / IncidentおよびAdmin auditは保持できる
- 一度Season Boundary CloseしたMatchを後からRated結果として復活させない
- これによりSoft Reset後に旧Season Matchのlate Rating deltaを加える順序問題をMVPから除外する
- completed SeasonのFinal Rating / Ranking / Stats Snapshotは後から変更しない

---

# 5. Product Rules

- 1 Seasonは3か月とする
- DB時刻はUTCで管理する
- Matchは成立時のSeasonに固定して所属する
- Season終了30分前から新規Rated Matchmakingを停止する
- 成立済みMatchはSeason終了時点まで継続できる
- Season終了時点の未確定Rated Matchは`cancelled + season_boundary_no_rating`で終了し、Rated結果として復活させない
- Season終了時点までに確定したRated結果だけをFinal Snapshotへ含める
- Final Snapshotは保存後に変更しない
- Placement完了済みプレイヤーだけにSoft Resetを適用する
- Placement完了済みプレイヤーは再Placementしない
- Placement途中のプレイヤーは進捗とRatingをそのまま引き継ぎ、Soft Resetしない
- 新Seasonで0戦でも、Placement完了済みならRanking eligibleとする
- rolloverはserver-sideかつidempotentに実行する
- MVPでは過去Final Rankingのpost-hoc再計算を行わない

---

# 6. States

## Upcoming

- NameまたはNumber、開始日時を表示できる
- Rated MatchおよびCurrent Rankingの対象にはしない

## Active

- 現在SeasonとしてRated MatchとCurrent Rankingの対象にする
- 終了日時または残り期間を表示する

## Closing Soon

- 終了30分前から新規Rated Matchmakingを停止する
- 停止理由とSeason終了時刻をユーザーへ表示する
- 成立済みMatchは継続可能であることを表示する

## Rollover Processing

- Final Snapshot保存、Soft Reset、次Season開始をserver-sideで安全に処理する
- ユーザーへ旧Seasonと新Seasonが混在したRankingを表示しない

## Completed

- Final Snapshotを不変の過去Season実績として参照できる
- 新規Matchを所属させない

## Error

- rolloverが完了していない場合、処理状態を運営が検知できる
- ユーザーへ不確定なRatingやRankingを確定値として表示しない

---

# 7. Edge Cases

- Matchが終了30分より前に成立し、Season終了時点まで未確定の場合、そのMatchは旧Season所属のまま`cancelled + season_boundary_no_rating`で終了する
- Season終了時刻の直前に結果が確定した場合、server-sideの確定時刻がEnd At以前ならFinal Snapshotへ含める
- Season終了処理と結果確定が競合した場合、server-side Transactionで一方だけを成立させ、境界Close後のRated確定を拒否する
- rollover処理が途中で失敗した場合、再実行して未完了部分だけを安全に完了できるようにする
- 同じrollover jobが同時または複数回実行されても、SnapshotとSoft Resetを重複させない
- Placementの10戦目がSeason終了時点までに確定した場合、その時点でeligibleとなりFinal Snapshot対象に含める
- Placementの10戦目がSeason終了時点で未確定ならNo-Rating Closeし、Placement countを増やさず新Seasonで次のRated Matchを継続する
- eligible playerがSeason中に0戦でも、Season開始時のSoft Reset後RatingをFinal Rating候補として保持する
- 次Season定義が欠損または重複している場合、二重rolloverを行わず運営エラーとする

---

# 8. Error Handling

- rollover失敗時は処理段階、Season、対象Playerを追跡できるようにする
- 再試行時にSnapshotを上書きまたは重複作成しない
- Soft Reset済みPlayerへ再度Soft Resetを適用しない
- 次Seasonを一意に決定できない場合は処理を安全に停止し、不正なactive Seasonを作らない
- Snapshot完了前の値をFinal成績として公開しない
- Match結果の重複確定によってSeason戦績やRatingを二重加算しない
- 時刻判定はserver-sideのUTCを正とし、クライアント時刻に依存しない

---

# 9. Permissions

## Guest

- active Seasonの期間と、公開されている過去Season成績を閲覧できる

## Logged-in User

- active Seasonの期間と自分のSeason成績を確認できる
- Public Profileで公開される過去Season成績を閲覧できる
- rolloverを手動実行または変更できない

## Owner

- 自分のSeason Snapshotを変更できない

## Admin

- Season定義とrollover処理状態を運営目的で確認できる
- Season運用操作の具体的権限はAdmin仕様に従う
- Admin / Dispute処理でもMVPのFinal Snapshot不変ルールに従う

---

# 10. Data

## Season

- Season ID
- NameまたはNumber
- Start At (UTC)
- End At (UTC)
- Status: upcoming / active / completed
- Created At / Updated At

## Season Player Record

- Season ID
- User ID
- Final Rating
- Final Ranking
- Rated Wins
- Rated Losses
- Win Rate
- Rated Match Count
- Snapshot At
- Snapshot Statusまたはidempotency情報

Season IDとUser IDの組み合わせは一意であること。

## Player Season Transition

- From Season ID
- To Season ID
- User ID
- Placement Completion Status
- Previous / Final Rating
- Soft Reset Rating
- Soft Reset Applied At
- Transition Statusまたはidempotency key

## Match Season Attribution

- Match ID
- Season ID at Match Formation
- Matched At
- Result Confirmed At
- Rated / Unrated
- Result / Dispute Status

実際のDB設計とtransaction境界はArchitectureで定義する。

---

# 11. Dependencies

- [Product Spec](../product-spec.md)
- [Architecture](../architecture.md)
- [Ranking](./ranking.md)
- [Placement](./placement.md)
- [Rating System](./rating-system.md)
- [Public Profile](./public-profile.md)
- Matchmaking / Waiting Pool
- Result Reporting
- Admin / Dispute
- server-side scheduling / job execution

---

# 12. Non-Functional Requirements

## Reliability

- rolloverは再試行可能かつidempotentであること
- 各Player・各SeasonのSnapshotおよびSoft Resetが高々一度だけ確定すること
- 部分失敗が他Playerの記録破損や二重更新を引き起こさないこと

## Consistency

- Snapshotに使用するRating、Ranking、戦績は同一のSeason終了境界を基準とすること
- RankingとSeason Player RecordでFinal Rankingが一致すること
- MatchのSeason所属は成立後に変化しないこと

## Observability

- rolloverの開始、各段階、完了、失敗、再試行を運営が追跡できること
- 重複処理を防止した事実と未完了対象を確認できること

## Security

- Season境界、Snapshot、Soft Resetはクライアントから変更できないこと
- server-sideの認可された処理だけがrollover状態を更新できること

## Localization

- DBではUTCを使用し、UIでは適切なローカル日時・期間表現を使用すること
- 日本語・英語でSeason状態とMatchmaking停止理由を理解できること

## Mobile

- モバイルでもSeason名、残り期間、現在および過去Seasonの主要成績を確認できること

---

# 13. Acceptance Criteria

- [ ] Seasonが3か月で定義される
- [ ] Seasonがstart、end、status、nameまたはnumberを持つ
- [ ] DB時刻がUTCで管理され、UIが適切なローカル時刻を表示する
- [ ] Match成立時にSeason IDが固定される
- [ ] Season終了30分前から新規Rated Matchmakingが停止する
- [ ] 成立済みMatchがcutoff後も継続できる
- [ ] Season終了時点までに確定した結果だけがFinal Snapshotへ反映される
- [ ] eligible playerごとにFinal Rating、Final Ranking、W/L、Win Rate、Rated Match Countが保存される
- [ ] Final Snapshotが後から変更されない
- [ ] Soft Resetが指定式とRating System準拠の四捨五入で計算される
- [ ] Placement完了済みプレイヤーにSoft Resetが一度だけ適用され、再Placementを要求しない
- [ ] Placement途中のプレイヤーが進捗とRatingを引き継ぎ、Soft Resetされない
- [ ] 新Seasonで0戦でもPlacement完了済みプレイヤーがRankingへ掲載される
- [ ] Public Profileで過去Season Snapshotを表示可能である
- [ ] rolloverを再実行しても重複Snapshotと二重Soft Resetが発生しない
- [ ] Season終了時点で未確定のMatchが旧Season所属のまま保持される
- [ ] 未確定Matchの後日解決やRating correctionで過去Final Rankingが再計算されない
- [ ] Ranking、Rating System、Placement、Public Profile、Admin / Disputeとの参照関係が明記されている

---

# 14. Out of Scope

- Rating Decay
- 高度なActivity rules
- 国別・地域別Leaderboard
- 複雑なSeason playoffs / rewards
- Dynamic Season Length
- completed Seasonに対するpost-hoc full ranking recalculation
- 高度な過去Season絞り込み・分析UI

---

# 15. Open Questions

- Seasonの具体的な開始日と終了日
- Seasonの命名規則またはNumber形式
- rollover処理の段階分割と運営用リカバリーUIの詳細
