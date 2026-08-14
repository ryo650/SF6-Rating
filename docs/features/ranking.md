# Ranking — Feature Spec

Status: Reviewed
Product: SF6-Rating
Related Feature: [Seasons](./seasons.md)

---

# 1. Feature Overview

## Feature Name

Ranking

## Summary

Placementを完了したプレイヤーを、現在のSeasonにおけるCurrent Ratingの降順で比較できるランキングを提供する。

## Purpose

プレイヤーが現在の立ち位置、自分と他プレイヤーのRating差、Season終了までの期間を確認し、継続的にRated FT3へ参加する動機を得られるようにする。

---

# 2. User

## Target User

- 現在のランキングを確認したいGuestまたはLogged-in User
- Placementを完了し、自分の順位を確認したいLogged-in User

## User Goal

- 現在のSeasonにおける自分の公開順位とCurrent Ratingを確認する
- Leaderboardで他プレイヤーとの位置関係を比較する
- Usernameから対象プレイヤーのPublic Profileを確認する

---

# 3. User Flow

1. ユーザーがRanking画面を開く
2. システムがactiveなSeasonと、Placement完了済みプレイヤーのCurrent Ratingを取得する
3. ユーザーがSeason残り期間とLeaderboardを確認する
4. Logged-in UserかつRanking eligibleの場合、自分の順位とCurrent Ratingを確認する
5. ユーザーがLeaderboard上のUsernameを選択する
6. 対象プレイヤーのPublic Profileへ遷移する

---

# 4. Functional Requirements

## Requirement 1 — Eligibility

- Placementを完了したプレイヤーのみRanking eligibleとする
- Placementは10 Rated FT3の完了を要件とし、10/10完了によって結果とRatingが確定した直後からRanking eligibleとする
- Placement自体が最低10 Rated FT3を要求するため、MVPではPlacement完了後の追加最低試合数条件を設けない

## Requirement 2 — Ranking Calculation

- 公開順位はCurrent Ratingの降順のみで決定する
- 勝率、試合数、連勝数、セットスコアその他の指標を順位計算に使用しない
- 同じCurrent Ratingのプレイヤーは表示上同順位とする
- 同順位はcompetition ranking方式で表示する。例: `1, 2, 2, 4`
- 一覧の内部表示順を安定させる目的に限り、当該Ratingへの到達時刻、User ID等のtechnical tie-breakerを使用してよい
- technical tie-breakerは公開順位へ影響させず、同Ratingのプレイヤー間に異なる公開順位を付与しない

## Requirement 3 — Ranking UI

Ranking画面には少なくとも以下を表示する。

- Logged-in User自身の順位（eligibleの場合）
- Logged-in User自身のCurrent Rating
- active Seasonの残り期間
- Leaderboard

Leaderboardの各行には少なくとも以下を表示する。

- 順位
- Avatar
- Username
- Country
- Current Rating

Usernameから対象プレイヤーのPublic Profileへ遷移できること。

## Requirement 4 — Character Information

- Ranking画面およびLeaderboardには、メインキャラクター、使用予定キャラクター、使用率を含むキャラクター情報を表示しない

## Requirement 5 — Season Transition

- Placement完了済みプレイヤーは、新Season開始時にSoft Reset後のRatingでRanking eligibleとする
- 当該SeasonでRated Matchが0戦でも掲載する
- Season開始後に1戦以上プレイすることを掲載条件にしない
- 過去SeasonのFinal RankingはCurrent Rankingと分離し、保存済みSnapshotを参照する
- Current Rankingは`profiles.current_rating`をRatingの正本、active Seasonの`season_player_records`をeligibilityとSeason statsの正本として読む
- Current SeasonのCompleted Matchが無効化された場合、同じDomain ActionのCompensating Correction完了後のRatingを反映する
- completed SeasonのFinal Ranking Snapshotは後日の無効化で変更しない

## Requirement 6 — Discovery

- Username検索はMVPに含めてもよい候補機能とする
- Username検索を実装しなくてもRanking MVPの未完成とはしない
- 国別・地域別LeaderboardはMVP必須としない

---

# 5. Product Rules

- Placement未完了のプレイヤーをLeaderboardへ掲載しない
- Placement 10/10完了直後からeligibleとする
- 公開順位はCurrent Ratingのみで決定する
- 同Ratingは同順位とし、competition rankingを使用する
- MVPではRating Decayを適用しない
- MVPではRanking掲載のためのActivity requirementを設けない
- 新Season開始直後の0戦プレイヤーも、Placement完了済みであればSoft Reset後Ratingで掲載する
- Rankingにキャラクター情報を表示しない
- Season終了時のFinal Ranking確定ルールは[Seasons Feature Spec](./seasons.md)に従う

---

# 6. States

## Loading

- Season情報とLeaderboardを読み込み中であることを表示する

## Active

- active Season、残り期間、Leaderboardを表示する
- Logged-in Userがeligibleなら自分の順位とCurrent Ratingを表示する

## Placement Incomplete

- Logged-in UserのPlacement進捗を示し、未完了のためRanking対象外であることを表示する
- Leaderboard自体は閲覧できる

## No Active Season

- active Seasonがないため現在Rankingを表示できないことを明示する
- 不正確な前SeasonのCurrent Rankingを代替表示しない

## Empty

- active Seasonは存在するがeligible playerがいないことを表示する

## Error

- Rankingを取得できなかったことと、再試行手段を表示する

---

# 7. Edge Cases

- Rated Match確定によって複数プレイヤーが同じRatingになった場合、全員を同順位として表示する
- 同Ratingの人数が変化した場合、後続順位をcompetition ranking方式で再計算する
- Placement 10戦目の結果確定と同時に、Rating更新後の値でRanking eligibleにする
- Season rollover中は旧Seasonと新Seasonのデータを混在表示しない
- Logged-in Userがeligibleだが現在表示中のLeaderboard範囲外でも、自分の順位とCurrent Ratingを確認できるようにする
- UsernameやAvatarが変更された場合も、User IDを基準に同一プレイヤーとして扱う
- technical tie-breakerが欠損または同値でも公開順位は変えず、最終的にUser ID等で表示順のみを安定させてよい

---

# 8. Error Handling

- Ranking取得失敗時に古いデータを現在値と誤認させない
- 再試行できる導線を提供する
- Rating更新またはSeason rolloverの途中状態を公開順位として表示しない
- 同じRated結果が重複処理されても順位へ二重反映しない
- active Seasonを一意に特定できない場合はRankingを確定表示せず、運営が検知可能なエラーとして記録する

---

# 9. Permissions

## Guest

- Current Leaderboardを閲覧できる
- UsernameからPublic Profileへ遷移できる
- 自分の順位は表示されない

## Logged-in User

- Current Leaderboardを閲覧できる
- eligibleの場合、自分の順位とCurrent Ratingを確認できる
- Placement未完了の場合、Ranking対象外であることを確認できる

## Owner

- Rankingに関してLogged-in Userを超える操作権限を持たない

## Admin

- 運営確認のためRankingおよび関連データを参照できる
- Admin操作によるRating correctionやDispute解決はRating SystemおよびAdmin / Disputeの仕様に従う

---

# 10. Data

## Ranking Entry

- User ID
- Avatar
- Username
- Country
- Current Rating
- Public Rank
- Placement Completion Status
- Rating Reached At等のtechnical ordering key（必要な場合）

## Ranking Context

- Season ID
- Season NameまたはNumber
- Season Start At
- Season End At
- Season Status
- Ranking Calculated / Updated At

公開順位の保存または算出方式はArchitectureで定義する。technical ordering keyは表示安定化だけに使用する。

---

# 11. Dependencies

- [Product Spec](../product-spec.md)
- [Architecture](../architecture.md)
- [Placement](./placement.md)
- [Rating System](./rating-system.md)
- [Public Profile](./public-profile.md)
- [Seasons](./seasons.md)
- Authentication / Account & Player Profile
- Rated Match Result Processing

---

# 12. Non-Functional Requirements

## Performance

- Leaderboardは通常利用で実用的な時間内に表示されること
- eligible player増加時もページネーション等により安定して閲覧できること

## Consistency

- Rating確定とRanking反映の間に不整合が生じないこと
- 同一時点の同Ratingプレイヤーには常に同じ公開順位を返すこと
- Season IDを明示して異なるSeasonのRankingを混在させないこと

## Accessibility

- 順位、Username、Ratingを色だけに依存せず識別できること
- キーボード操作およびスクリーンリーダーで主要情報へアクセスできること

## Mobile

- モバイルでも自分の順位、Current Rating、Season残り期間、Leaderboardの主要項目を確認できること

## Localization

- 日本語・英語で表示できること
- Season残り期間と日時はユーザーに適切なローカル表現で表示すること

---

# 13. Acceptance Criteria

- [ ] Placement未完了のプレイヤーがLeaderboardに掲載されない
- [ ] Placement 10/10完了直後、更新後Current RatingでRanking eligibleになる
- [ ] 公開順位がCurrent Rating降順のみで決定される
- [ ] 勝率、試合数、連勝数が順位へ影響しない
- [ ] 同Ratingが`1, 2, 2, 4`形式の同順位で表示される
- [ ] technical tie-breakerを使用しても同Ratingの公開順位が分かれない
- [ ] 自分の順位、Current Rating、Season残り期間、Leaderboardを確認できる
- [ ] 各行に順位、Avatar、Username、Country、Ratingが表示される
- [ ] UsernameからPublic Profileへ遷移できる
- [ ] Rankingにキャラクター情報が表示されない
- [ ] Placement完了済みプレイヤーが新Seasonの0戦時点でもSoft Reset後Ratingで掲載される
- [ ] MVPでは追加最低試合数、Rating Decay、Activity requirementが適用されない
- [ ] Guest、モバイル、日本語UI、英語UIでLeaderboardの主要情報を確認できる

---

# 14. Out of Scope

- Rating Decay
- Ranking掲載に対する高度なActivity requirement
- 国別・地域別Leaderboard
- キャラクター別Ranking
- 勝率、試合数、連勝数等を使う複合順位
- 複雑なSeason playoffs / rewards
- 終了済みSeasonのpost-hoc full ranking recalculation

---

# 15. Open Questions

- Username検索をMVPへ含めるか
- Leaderboardの1ページあたりの表示件数
- 自分の順位周辺を表示するUIの詳細
