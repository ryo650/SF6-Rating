# SF6-Rating — Match Room Feature Spec

Status: Draft  
Feature: Match Room  
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

Match Room

## Summary

Match成立後、両プレイヤーがSF6のCustom Roomへ迷わず合流し、FT3を実施して結果報告へ進めるよう支援する限定公開画面。

## Purpose

SF6-RatingはSF6本体と直接連携しないため、Match成立後に次の情報と操作を一か所へまとめる必要がある。

- 対戦相手とSF6上で合流するための情報
- Custom Roomを作成するHost
- Host変更
- Room作成・参加時の最低限の定型連絡
- 接続トラブル時の案内
- FT3終了後のResult Reportingへの導線

Match RoomはSF6内の実際の進行を管理する画面ではない。役割を「Custom Roomへの合流支援」と「結果報告への入口」に限定し、外部ゲーム上で検証できない状態を増やさない。

---

# 2. User

## Target User

- MatchmakingによってMatchが成立した2名のログインユーザー
- スマートフォンまたはPCブラウザを使いながら、PC・PlayStation等の別デバイスを含む環境でSF6をプレイするユーザー
- Matchの確認、取消、dispute対応を行うAdmin

## User Goal

- Match成立後に相手と自分の役割をすぐ理解する
- SF6プレイヤーネームまたはSF6ユーザーコードを見て相手のCustom Roomへ合流する
- Room作成や参加状況を定型メッセージで伝える
- Host側でRoomを作成できない場合に相手へHostを変更する
- FT3終了後、迷わずResult Reportingへ進む
- Reload、通信切断、スマートフォンのSleep後も進行中Matchへ戻る

---

# 3. User Flow

## Standard Flow

1. Matchmakingがサーバー上でMatchを成立させる。
2. Match作成時にシステムがCustom Room Hostを1名指定する。
3. MATCH FOUND演出後、両プレイヤーがMatch Roomへ移動する。
4. Match RoomはMatchを `matched` から `room_setup` へ進める。
5. 両者は対戦相手、Rating、Host、SF6プレイヤーネーム、SF6ユーザーコードを確認する。
6. HostはSF6内でCustom Roomを作成する。
7. Hostは `Room created` を送信する。
8. Guestは表示されたSF6情報を参照してCustom Roomへ参加する。
9. Guestは `Joined` を送信する。
10. 両者はSF6内でFT3を行う。
11. FT3終了後、各プレイヤーは独立してResult Reportingへ進む。
12. 最初のプレイヤーが結果報告へ進んだ時点で、Matchは `reporting` となる。
13. 双方の結果が一致すると、Result Reporting側の信頼された処理がMatchを `completed` にする。
14. 結果が解決しない場合は `disputed`、対戦が成立しなかった場合は適切な取消処理により `cancelled` となる。

## Host Change Flow

1. `room_setup` 中に現在のHostがHost変更を選ぶ。
2. サーバーが本人性、Match参加資格、現在状態を検証する。
3. 追加承認なしでHostを相手へ変更する。
4. Host変更を `match_events` に保存する。
5. 両者の画面が最新Hostへ更新され、新しい役割別案内を表示する。

## Trouble Flow

1. Roomが見つからない、作り直しが必要、または少し待ってほしい場合、該当する定型メッセージを送る。
2. 必要に応じてRoomを再作成するかHostを変更する。
3. Room setup開始から10分経過した場合、No-show / trouble対応の導線を目立たせる。
4. 10分経過だけではMatchを自動キャンセルしない。
5. 対戦続行が不可能な場合は、取消・No-show処理へ進む。

## Return to Active Match Flow

1. ユーザーがMatch Roomからサイト内の別ページへ移動する。
2. サイト全体に `Active Match — Return to Match` の導線を表示する。
3. ユーザーはいつでも進行中Matchへ戻れる。
4. Active Match中は新しいQuick Match、対戦受付、相手選択を開始できない。
5. Reload、通信切断、スマートフォンSleep後はDatabaseからActive Match、Host、状態、eventsを取得して復元する。

---

# 4. Functional Requirements

## FR-01 Match Is Already Confirmed

**Confirmed**

- MATCH FOUNDの時点でMatchはサーバー上ですでに成立している。
- Match Roomで相手情報を見た後に「対戦する / 拒否する」を選ぶ確認画面は設けない。
- Match成立後の離脱はWaitingへ戻す操作ではなく、No-show / cancellationとして扱い得る。
- 単発の通信事故や離脱に即時の重いペナルティは課さず、繰り返しを履歴に基づき評価する。

## FR-02 Participant Information

**Confirmed**

Match Roomでは参加者に次を表示する。

- SF6-Ratingユーザー名
- プロフィールアイコン
- 現在Rating
- Placement状態（該当時）
- Rated / Unrated
- SF6プレイヤーネーム
- SF6ユーザーコード
- 現在のCustom Room Host
- Match状態
- Room setup開始からの経過時間
- Match Event Timeline

SF6プレイヤーネームとSF6ユーザーコードはMatch成立後に初めて、現在の対戦相手へ限定公開する。

## FR-03 Limited SF6 Identity Disclosure

**Confirmed**

- SF6プレイヤーネームとSF6ユーザーコードは、そのMatchの参加者2名とAdminだけが閲覧できる。
- Rated Match成立前のMatchmaking候補一覧には表示しない。
- Matchが `completed`、`cancelled`、または運営処理で終了した後は、「現在の対戦相手への限定公開」として取得できないようにする。
- 一般公開プロフィール、公開対戦履歴、分析イベントへSF6ユーザーコードを含めない。

## FR-04 Host Assignment

**Confirmed**

- Match作成時にシステムが参加者の一方をCustom Room Hostとして自動指定する。
- Host選出は同じユーザーへ不合理に偏らない方式とする。
- Host選出アルゴリズムの詳細はImplementation Detailとする。
- HostとGuestには、それぞれが今行うべき操作を明確に分けて表示する。

## FR-05 Host Change

**Confirmed**

- `room_setup` 中は現在のHostを相手へ変更できる。
- Host変更に相手の追加承認は不要とする。
- Host変更はサーバー側で検証し、成功時に `match_events` へ保存する。
- `reporting`、`completed`、`cancelled`、`disputed` 状態ではHostを変更できない。
- **Assumption:** Host変更回数にプロダクト上の固定上限は設けず、異常な連打だけRate Limitする。

## FR-06 Role-Specific Guidance

**Assumption — UX**

Hostには次の趣旨を表示する。

> SF6でCustom Roomを作成し、作成後に「Room created」を送信してください。

Guestには次の趣旨を表示する。

> HostのSF6プレイヤーネームまたはユーザーコードを確認し、Custom Roomへ参加してください。

Host変更時は両者の案内を即時に切り替える。

## FR-07 User Code Display

**Confirmed**

- SF6ユーザーコードは別デバイスのSF6へ手入力する利用を前提に、読み取りやすく表示する。
- User Codeのワンタップコピー機能はMVPで提供しない。
- QRコード、Deep Link、自動入力も提供しない。
- **Assumption:** 元のコード値を変更しない範囲で、Typography、余白、視覚的な区切りにより読みやすさを高める。

## FR-08 Preset Messages

**Confirmed**

MVPでは自由入力チャットを提供せず、最低限次の定型メッセージを提供する。

- `Room created`
- `Joined`
- `Can't find the room`
- `Please try again`
- `Please wait`

- 定型メッセージは日本語・英語の表示文と安定した内部Message Typeを分離する。
- 送信者、送信時刻、Message Typeを `match_events` へ保存する。
- 両参加者へRealtimeで新着を通知する。
- **Assumption:** MVPは上記5種類から開始し、実利用で不足が確認された場合に追加する。

## FR-09 Match Event Timeline

**Confirmed**

定型メッセージとシステムイベントを、自由入力チャットではなくMatch進行Timelineとして時系列表示する。

主なイベント:

- Match created
- Host assigned
- Host changed
- Room created
- Joined
- Can't find the room
- Please try again
- Please wait
- Result reporting started
- Match cancelled
- Dispute opened

Timelineは通信切断後にも復元できるよう永続化する。

## FR-10 External Game State Is Not Verified

**Confirmed**

- SF6-RatingはSF6側のCustom Room作成、参加、対戦開始、対戦中状態を自動検証しない。
- `Room created` と `Joined` はユーザーが送った進行補助メッセージであり、SF6内の事実を証明するものではない。
- SF6-Rating側に `Start FT3` ボタンを設けない。
- 外部ゲーム内の進行を別のMatch statusとして設けない。
- Result Reportingへ進むために `Room created` や `Joined` の送信を必須条件にしない。
- 最終的な勝敗は双方のResult Report一致によって確定する。

## FR-11 Result Reporting Entry

**Confirmed**

- 各参加者はFT3終了後に独立してResult Reportingへ進める。
- 相手が同時に操作する必要はない。
- 最初の結果報告開始または提出により、サーバーは有効な状態遷移としてMatchを `reporting` にできる。
- 片方が結果報告へ進んだ場合、相手側に結果報告が始まったことを表示できる。
- Resultの入力、整合判定、Rating更新、disputeの詳細はResult Reporting / Rating Feature Specへ委ねる。

## FR-12 Active Match Global Experience

**Confirmed**

- Match成立後も、ユーザーがサイト内の他ページを閲覧すること自体は禁止しない。
- Active Matchがある間、サイト全体にMatch Roomへ戻る常設導線を表示する。
- Active Match中はQuick Match、Find Opponentの対戦受付、相手選択等の新規Matchmakingを開始できない。
- Matchmaking画面へ移動した場合も、新規開始操作ではなくActive Matchへ戻る導線を優先表示する。
- 複数Tabでも同じActive Match状態へ収束する。

## FR-13 Room Setup Time Guidance

**Confirmed + Assumption**

- Room setup開始から10分をNo-show / trouble対応の目安とする。
- 10分経過した時点で、問題解決、取消、No-show報告等への導線を強調する。
- 10分経過だけを理由にMatchを自動キャンセルしない。
- 経過時間はServer時刻を基準に判定する。
- **Assumption:** 10分到達前にも定型メッセージとHost変更は常に利用できる。
- **Open Question — Non-blocking:** 取消とNo-show申告の具体的な操作、相手確認、ペナルティ判定はDispute / Admin Feature Specで定義する。

## FR-14 Reload, Reconnect, and Sleep Recovery

**Derived Technical Decision**

- PostgreSQLをActive Match、Host、Match state、Match eventsのSource of Truthとする。
- Realtimeは状態変更を早く通知するために使用し、正解の決定には使用しない。
- Reload、ブラウザ再起動、通信切断、スマートフォンSleep後にActive MatchをDBから再取得する。
- 復元時にCurrent state、Host、Participant information、eventsを取得し、Realtimeを再購読する。
- 状態が確認できるまで新規Matchmakingや重複する重要操作を開始させない。

## FR-15 Trusted Operations

**Derived Technical Decision**

Host変更、定型メッセージ送信、状態遷移、取消要求等は信頼されたServer処理を介し、少なくとも次を検証する。

- 認証済みユーザーである
- 対象Matchの参加者である
- Matchが操作を許可する状態である
- 同じ操作がすでに適用済みでない
- Rate Limitまたは利用制限に違反していない
- Clientが他人、任意Host、任意状態、任意Timestampを指定して改ざんできない

## FR-16 Future Client Compatibility

**Derived Technical Decision**

- Host変更、定型メッセージ送信、Active Match取得、Result Reportingへの遷移等の重要ロジックをNext.js画面コンポーネントへ密結合しない。
- Web ClientはBackend API / RPC等の安定した境界を利用する。
- 将来React Native / Expo Clientから同じBackend処理を再利用できるようにする。
- Native Push通知やNative UI自体はMVP対象外とする。

---

# 5. Product Rules

1. **Confirmed:** MATCH FOUND時点で対戦は成立済みであり、Match Roomに相手拒否の確認画面を設けない。
2. **Confirmed:** SF6プレイヤーネームとSF6ユーザーコードはMatch成立後、参加者2名とAdminだけへ限定公開する。
3. **Confirmed:** Match作成時にCustom Room Hostを自動決定する。
4. **Confirmed:** `room_setup` 中は追加承認なしでHostを相手へ変更できる。
5. **Confirmed:** 自由入力チャットを提供しない。
6. **Confirmed:** 定型メッセージとシステムイベントを `match_events` のTimelineとして保存する。
7. **Confirmed:** SF6側の実際のRoom作成、参加、対戦開始、対戦中状態を自動検証しない。
8. **Confirmed:** `Start FT3` ボタンを作らない。
9. **Confirmed:** 外部ゲーム内の進行を別のMatch statusとして作らない。
10. **Confirmed:** User Codeのワンタップコピー機能を作らず、見やすく表示する。
11. **Confirmed:** Active Match中もサイト内の他ページを閲覧できるが、新しいMatchmakingは開始できない。
12. **Confirmed:** Room setup開始から10分はtrouble / No-show対応の目安であり、自動キャンセル時刻ではない。
13. **Derived Technical Decision:** DatabaseをMatch Room状態のSource of Truthとし、Realtimeを通知用途に限定する。
14. **Derived Technical Decision:** 重要操作はServer側で参加者・状態・入力・重複・制限を検証する。
15. **Derived Technical Decision:** Match Room詳細を参加者2名とAdmin以外へ開示しない。
16. **Derived Technical Decision:** 重要なビジネスロジックをWeb UIへ密結合しない。

---

# 6. States

Match Roomの基本状態モデルは次のとおりとする。

```text
matched → room_setup → reporting → completed
                 ├──→ cancelled
                 └──→ disputed
reporting ──────────→ disputed
```

外部ゲーム内の進行を表す追加statusは存在しない。

## Matched

- Matchは成立済み。
- Hostと参加者Snapshotが確定している。
- MATCH FOUND演出後、Match Roomを開く。
- 通常はサーバー処理により速やかに `room_setup` へ進む。

## Room Setup

- Host、SF6情報、役割別案内、定型メッセージ、Timelineを表示する。
- Host変更を許可する。
- FT3はSF6側で行われるが、SF6-Ratingは開始・対戦中を検知しない。
- 各参加者はFT3終了後にResult Reportingへ進める。
- 10分経過後はtrouble / No-show対応導線を強調するが、自動遷移・自動取消はしない。

## Reporting

- 少なくとも一方が結果報告を開始または提出している。
- Host変更は不可。
- 未報告者へResult Reporting導線を表示する。
- Match Room Timelineと限定情報は、結果確定・取消・dispute処理に必要な範囲で参加者へ表示する。

## Completed

- 双方の結果が一致し、結果と必要なRating処理が確定している。
- Active Matchではない。
- 新しいMatchmakingを開始できる。
- SF6ユーザーコードの対戦相手限定公開を終了する。
- 公開可能なMatch summary / historyへの導線を表示できる。

## Cancelled

- FT3が成立しなかった、または信頼された取消処理でMatchが終了した。
- Active Matchではない。
- Ratingを変更しない。
- SF6ユーザーコードの対戦相手限定公開を終了する。
- No-show履歴等の扱いは取消理由とAdminルールに従う。

## Disputed

- Result不一致、No-show、離脱、その他運営確認が必要な状態。
- 新しいMatchmakingを許可する時点はDispute / Admin Feature Specで定義する。
- 一般ユーザーは重要状態を直接確定・無効化できない。
- Adminが必要な情報とeventsを確認できる。

## UI / Connection States

- Loading
- Reconnecting
- Action Pending
- Timeline Empty
- Error
- Access Denied
- Active
- Trouble Guidance Visible

これらはMatchの永続状態とは別の画面状態として扱う。

---

# 7. Edge Cases

## Participant Reloads or Returns Later

Active Match、Host、状態、eventsをDBから復元してMatch Roomへ戻す。Client上の古い表示を正解として扱わない。

## Smartphone Sleeps During Room Setup

復帰後にCurrent Matchを再取得する。Realtime通知を失っていてもTimelineとHostを最新状態へ同期する。

## Participant Opens Multiple Tabs

すべてのTabは同じDB状態へ同期する。Host変更やメッセージ送信が競合してもServerの確定結果を表示する。

## Both Participants Try to Change Host

各要求をServer側で現在Hostと状態に対して検証する。成功した順序に従い最終HostをDBで確定し、Timelineへ記録する。Client予測だけでHostを決めない。

## Duplicate Preset Message Submission

Network retryや二重タップで意図しない重複eventが作られないようIdempotencyを適用する。意図的に同じMessage Typeを後から再送すること自体はRate Limit範囲で許可できる。

## Host Cannot Create a Room

`Please wait`、`Please try again` 等を使用し、必要ならHostを相手へ変更する。Host変更後は両者へ新しい役割を表示する。

## Guest Cannot Find the Room

`Can't find the room` を送信し、HostはRoom再作成またはHost変更を行える。システムはSF6側の検索結果を検証しない。

## FT3 Starts Without Preset Messages

`Room created` や `Joined` が送信されていなくても、Result Reportingへの遷移を妨げない。

## FT3 Finishes While Match Is Still Room Setup

ユーザーがResult Reportingへ進んだ時点で、サーバーが有効性を検証して `reporting` へ遷移できる。

## Ten Minutes Pass During Legitimate Setup

trouble対応導線を強調するが、Matchを自動キャンセルせず、Host変更・定型メッセージ・結果報告導線を維持する。

## One Participant Leaves Immediately After Match Found

Matchは成立済みであるためWaitingへ自動的に戻さない。相手はtrouble / No-show導線を利用する。単発では即時の重いペナルティを課さず、繰り返しは履歴として扱う。

## Participant Navigates Away

Active Matchへの常設導線を表示し、新規Matchmaking操作を無効化する。Match Room自体は終了しない。

## Profile Information Changes During Active Match

Match成立時Snapshotと、合流に必要な有効SF6情報のどちらを表示するかを一貫させる。MVPではActive Match中のSF6プレイヤーネーム / ユーザーコード変更を禁止する案を第一候補とする。

## Account Becomes Restricted During Active Match

新規Matchmakingを禁止する。進行中Matchを継続・取消・disputeのどれにするかは制限理由とAdminルールに従い、Clientだけで決めない。

## Result Reporting and Cancellation Collide

Server側で現在状態をLockまたは同等の同時実行制御で検証し、`completed` と `cancelled` が同時成立しないようにする。

---

# 8. Error Handling

## Match Room Load Failed

- Active Matchの存在が不明なまま新規Matchmakingを許可しない。
- 再試行を提供する。
- Realtime障害とDB取得障害を区別し、Realtime障害だけならDB表示を継続する。
- 内部エラーや相手の非公開情報をエラー文へ含めない。

## Access Denied

- Guest、非参加者、終了後に限定情報へアクセスしようとしたユーザーへMatch Room詳細を返さない。
- 一般的なアクセス不可メッセージを表示する。
- SF6ユーザーコードの存在を推測できる情報を返さない。

## Host Change Failed

- 現在HostとMatch状態を再取得する。
- すでに相手がHostである場合は最新状態へ同期する。
- `room_setup` 以外では操作不可と明示する。
- 失敗時にClientだけのHost表示を残さない。

## Preset Message Failed

- Timelineへ未確定メッセージを確定済みとして残さない。
- 再試行を提供する。
- 重複送信の可能性がある場合はIdempotency結果を確認する。
- 他のMatch操作を不要に停止しない。

## Result Reporting Entry Failed

- Match状態と参加資格を再取得する。
- すでに `reporting` の場合はResult Reportingへ復帰する。
- `completed`、`cancelled`、`disputed` の場合は適切な終了状態へ案内する。
- 同じ結果報告セッションを重複作成しない。

## Reconnection Failure

- Realtime再接続だけに依存せず、DB再取得を再試行する。
- 状態確認ができない間はHost変更や新規Matchmaking等の重要操作を抑止する。
- 回復後は最新状態へ収束する。

## Localization

- 主要な状態、定型メッセージ、エラー、trouble案内を日本語・英語で提供する。
- 内部Reason Codeとユーザー表示文を分離する。

---

# 9. Permissions

## Guest

- Match Room詳細を閲覧できない。
- SF6プレイヤーネーム、SF6ユーザーコード、eventsを取得できない。
- Host変更、定型メッセージ、Result Reportingへの遷移を実行できない。

## Logged-in User

- 自分が参加者であるActive MatchのMatch Roomを閲覧できる。
- 自分のActive Matchへ戻れる。
- `room_setup` 中に許可された定型メッセージを送信できる。
- 自分が現在Hostの場合にHost変更を要求できる。
- 自分のResult Reportingへ進める。
- 他人のMatch Room、SF6情報、eventsを閲覧・変更できない。
- Match status、Host、相手、Timestampを直接書き換えられない。

## Owner

このFeatureではOwnerを「対象Matchの参加者」として扱う。

- 自分が参加するMatchの許可された操作だけを実行できる。
- 相手になりすましてメッセージ送信・結果報告できない。
- Matchを直接 `completed`、`cancelled`、`disputed` に設定できない。
- Rating、Result、No-show判定を直接指定できない。

## Admin

- 運営上必要な範囲でMatch Room詳細、参加者のSF6情報、events、状態遷移を確認できる。
- Dispute / Admin仕様で許可された取消、無効化、制限、修正を行える。
- Admin操作は監査可能な形で記録する。
- 一般ユーザー向けClientからAdmin権限を利用できない。

すべての読取・書込はRLS、Server-side validation、Database制約で保護する。Service Role等の秘密鍵をBrowserへ公開しない。

---

# 10. Data

実際のDB設計ではなく、このFeatureが必要とするプロダクトデータを示す。

## Match

- Match ID
- Player A
- Player B
- Rated / Unrated
- Status: matched / room_setup / reporting / completed / cancelled / disputed
- Host Player
- Creation Source
- Created At
- Room Setup Started At
- Reporting Started At
- Completed / Cancelled / Disputed At
- Participant Rating Snapshot
- Participant Placement Snapshot
- Active Match Flagまたは同等の一意性制御
- Versionまたは同時更新制御情報

## Match Participant Private View

- Match
- Participant
- Opponent Public Username
- Opponent Avatar
- Opponent Rating Snapshot
- Opponent Placement Snapshot
- Opponent SF6 Player Name
- Opponent SF6 User Code
- Host / Guest Role
- Permission to View Private SF6 Identity
- Result Reporting Status

## Match Event

- Event ID
- Match
- Event Type
- Actor UserまたはSystem
- Preset Message Type（該当時）
- Previous Host / New Host（該当時）
- Created At
- Idempotency Key
- Metadata（機密情報を含めない）
- Visibility

## Active Match Reference

- User
- Match
- Active Since
- Current Status
- Return Route
- Cleared At

## No-show / Cancellation Reference

- Match
- Reporting User
- Reason Code
- Requested At
- Counterparty Response（将来仕様）
- Resolution
- Resolved By
- Resolved At

No-show / cancellationの詳細データと判定はDispute / Admin Feature Specで確定する。

## Analytics Events

- Match Room Opened
- Match Room Restored
- Host Changed
- Preset Message Sent
- Trouble Guidance Shown
- Result Reporting Opened
- Match Room Load / Action Failed

分析イベントへSF6ユーザーコード、SF6プレイヤーネーム、Email、詳細地域等の不要な個人情報を含めない。

---

# 11. Dependencies

- Product Spec
- Architecture
- Account / Profile Feature Spec
- Matchmaking / Waiting Pool Feature Spec
- Result Reporting / Rating Feature Spec
- Dispute / Admin Feature Spec
- Authentication
- User Restrictions
- Supabase PostgreSQL
- Supabase Realtime
- Row Level Security
- Next.jsの信頼されたServer処理
- Match state machineとAtomic transaction
- `match_events` Timeline
- 日本語・英語の定型メッセージおよび状態文言
- サイト全体のActive Match表示
- 将来ClientのためのBackend API / RPC境界

---

# 12. Non-Functional Requirements

## Performance

- Match Room初期表示で不要な全対戦履歴やRating Historyを取得しない。
- Active Match、Participant情報、Host、最新eventsをモバイル回線でも実用的な時間で取得する。
- Timelineはページングまたは上限を持ち、無制限のeventを毎回読み込まない。
- Realtimeは対象Matchの参加者へ必要なeventだけを配信する。
- Active Match復元のために全Matchを走査しない。
- Match ID、Participant、Status、Created At等へ適切なIndexを利用できる。

## Security

- Match Room詳細は参加者2名とAdminだけが閲覧できる。
- SF6ユーザーコードを公開Profile、公開History、候補一覧、分析へ漏らさない。
- Host変更、定型メッセージ、状態遷移をServer側で検証する。
- Clientが任意のActor、Host、Match status、Timestampを送って確定できない。
- 定型メッセージとHost変更へ通常利用を妨げないRate Limitを適用する。
- 自由入力を受け付けず、Message Type allowlistを使用する。
- Event metadataへSecretや不要な個人情報を保存しない。
- Service Role等の秘密鍵をBrowserへ公開しない。

## Reliability

- **Derived Technical Decision:** PostgreSQLをActive Match、Host、state、eventsのSource of Truthとする。
- **Derived Technical Decision:** Realtimeは通知用途に限定し、通知欠落後もDB再取得で回復する。
- Host変更、event作成、状態遷移は部分成功を避ける。
- 二重操作・通信Retryで重複eventや不正な状態遷移を作らない。
- Reload、複数Tab、ブラウザ再起動、スマートフォンSleep後もActive Matchを復元する。
- `completed`、`cancelled`、`disputed` の競合をServer / DB側で防ぐ。
- Match Room取得失敗中にActive Matchがないと誤認して新規Matchmakingを開始させない。

## Accessibility

- Host変更、定型メッセージ、Active Matchへ戻る、Result Reportingへの導線をKeyboardで操作できる。
- Host変更、新着event、状態変更、エラーをスクリーンリーダーへ通知する。
- Host / Guest、Rated / Unrated、状態を色だけで表現しない。
- Timelineに意味のあるLabelと時系列構造を提供する。
- Focus表示と論理的なFocus順序を維持する。
- 10分経過やtrouble表示を点滅だけで伝えない。

## Mobile

- モバイルファーストで相手情報、Host、SF6情報、定型メッセージ、結果報告導線を確認できる。
- SF6ユーザーコードは別デバイスへ手入力しやすい大きさと視認性で表示する。
- ワンタップコピーを主要導線として前提にしない。
- 小さい画面でもHost / Guestの役割と次の操作が見失われない。
- スマートフォンSleep・Background復帰後にActive Matchを復元する。
- PCブラウザでも同じ主要機能を利用できる。

## Localization

- 主要UI、状態、定型メッセージ、エラー、trouble案内を日本語・英語で提供する。
- Event Type、State、Reason Codeは言語非依存の内部値とする。
- Timeline時刻はLocale / Timezoneに合わせて表示し、状態判定はServer上の絶対時刻で行う。
- SF6ユーザーコード等の識別子を翻訳・変換しない。

## Future Client Compatibility

- **Derived Technical Decision:** Host変更、定型メッセージ送信、Active Match復元、状態遷移をWeb UIへ密結合しない。
- 将来React Native / Expo Clientが同じBackend処理を利用できる。
- Web固有のNavigationやPresentationと、Match Roomの権限・状態処理を分離する。

---

# 13. Acceptance Criteria

## Entry and Visibility

- [ ] Match成立後、拒否確認なしでMatch Roomへ進む
- [ ] Match Room表示時点でMatchがDB上に存在する
- [ ] Match参加者2名が相手のSF6プレイヤーネームとSF6ユーザーコードを確認できる
- [ ] 非参加者とGuestがMatch Room詳細を取得できない
- [ ] Adminが運営権限の範囲でMatch Room詳細を確認できる
- [ ] Match終了後、相手のSF6ユーザーコードを「現在の対戦相手」向けAPIから取得できない
- [ ] 一般公開Profile、History、AnalyticsにSF6ユーザーコードが含まれない

## Host and Guidance

- [ ] Match作成時にHostが自動指定される
- [ ] HostとGuestで役割別の案内が表示される
- [ ] `room_setup` 中に現在Hostが相手へHostを変更できる
- [ ] Host変更に相手の追加承認を必要としない
- [ ] Host変更がTimelineへ記録される
- [ ] `reporting` 以降はHostを変更できない
- [ ] 同時または重複するHost変更で不正なHost状態が作られない

## SF6 Information UX

- [ ] SF6プレイヤーネームとSF6ユーザーコードが読みやすく表示される
- [ ] User Codeのワンタップコピー機能が存在しない
- [ ] QRコード、自動入力、SF6 Deep Linkが存在しない
- [ ] Character情報をMatch Room参加前の選別へ利用させない

## Preset Messages and Timeline

- [ ] 自由入力チャットが存在しない
- [ ] Room createdを送信できる
- [ ] Joinedを送信できる
- [ ] Can't find the roomを送信できる
- [ ] Please try againを送信できる
- [ ] Please waitを送信できる
- [ ] 定型メッセージが送信者・時刻とともにTimelineへ保存される
- [ ] Host assigned / changed等のSystem EventがTimelineへ表示される
- [ ] 通信切断後にTimelineをDBから復元できる
- [ ] Rate LimitやIdempotencyにより不正・意図しない大量送信を抑制できる

## State Model and Result Reporting

- [ ] 状態モデルが `matched → room_setup → reporting → completed` を基本とする
- [ ] `cancelled` と `disputed` の分岐を持つ
- [ ] 外部ゲーム内の進行を表す追加statusが存在しない
- [ ] Start FT3ボタンが存在しない
- [ ] SF6側でRoom作成・参加・対戦開始したことを自動検証しない
- [ ] Room created / Joined未送信でもResult Reportingへ進める
- [ ] 各参加者が独立してResult Reportingへ進める
- [ ] 一方の報告開始後に相手へ報告導線を表示できる
- [ ] ClientがMatchを直接completed / cancelled / disputedへ変更できない

## Active Match and Recovery

- [ ] Match成立後もサイト内の他ページを閲覧できる
- [ ] サイト全体にActive Matchへ戻る導線が表示される
- [ ] Active Match中は新しいQuick Matchを開始できない
- [ ] Active Match中は対戦受付を開始できない
- [ ] Active Match中はFind Opponentから新しい相手を選択できない
- [ ] Reload後にActive Match、Host、状態、eventsをDBから復元できる
- [ ] スマートフォンSleep後にActive Matchを復元できる
- [ ] Realtime通知を失ってもDBから最新状態へ収束する
- [ ] 複数Tabで重複Matchや矛盾するHost状態を作らない

## Trouble and No-show Guidance

- [ ] Room setup開始から10分をServer時刻で判定できる
- [ ] 10分経過時にtrouble / No-show対応導線を強調する
- [ ] 10分経過だけでは自動キャンセルされない
- [ ] 10分経過後もHost変更と定型メッセージを利用できる
- [ ] 単発の離脱・通信事故へ即時の重いペナルティを課さない
- [ ] No-show / cancellationの履歴を将来のAdmin処理へ渡せる

## Quality

- [ ] 主要フローを日本語・英語で利用できる
- [ ] 主要フローをスマートフォンとPCブラウザで完了できる
- [ ] Keyboardとスクリーンリーダーで主要操作を利用できる
- [ ] 重要操作がServer-side validationとRLSで保護される
- [ ] Backend処理が将来React Native / Expo Clientから再利用可能な境界を持つ
- [ ] Error時に部分成功や不正な状態遷移を残さず再試行・復元できる

---

# 14. Out of Scope

- Match Roomでの相手承認・拒否フロー
- 自由入力チャット
- Voice Chat
- DM
- Character情報による対戦前選別
- SF6またはCAPCOM APIとの直接連携
- Custom Roomの自動作成
- SF6側のRoom作成・参加・対戦開始・対戦中状態の自動検証
- Start FT3ボタン
- 外部ゲーム内進行専用の追加status
- SF6ユーザーコードのワンタップコピー
- QRコード
- SF6への自動入力
- 高度なDeep Link
- Ping測定
- ゲーム画面認識
- 自動勝敗取得
- Native Push通知
- ネイティブアプリ
- Result Reporting / Rating計算の詳細
- Dispute判定・Admin解決の詳細
- No-show / cancellationペナルティの具体値
- 本格的なチャットモデレーション
- 高度な不正検知

---

# 15. Open Questions

以下はMatch Roomの実装開始を止めるBlockerではない。関連Feature Specで確定するか、合理的な初期値をAssumptionとして扱う。

## OQ-01 No-show / Cancellation Flow

**Open Question — Cross-feature / Non-blocking**

- 10分経過後に誰がどの操作でNo-showを申告できるか
- 相手の確認を必要とするか
- 両者が異なる主張をした場合に即disputeへ進めるか
- No-show履歴と一時的Matchmaking制限をどう連動させるか
- 取消理由ごとのRating / 戦績への影響

Dispute / Admin Feature Specで定義する。10分経過による自動キャンセルは行わない。

## Resolved — Active Rated Match During Dispute

**Resolved by Result Reporting / Admin / Dispute**

Rated Matchは`disputed`の間もActive Rated Match Gateを維持する。Admin Resolutionまたは双方のMutual No-Rating Resolutionにより`completed | cancelled`へ遷移した時点でgateを解除する。Result-reporting nonresponseはfirst reportから30分の手動Close、24時間の自動Closeで長期Blockを避ける。

## OQ-02 Match Event Retention

**Open Question — Low Impact**

- Timelineに一度に表示する件数
- 古いeventの保持期間
- Completed Matchで参加者へどのeventsを表示し続けるか
- Admin監査用保持期間

MVPではActive Matchに必要なeventsを取得し、表示件数に上限を設ける。

## OQ-03 Active Match Profile Changes

**Open Question — Low Impact**

- Active Match中のSF6プレイヤーネーム変更を禁止するか
- Active Match中のSF6ユーザーコード変更を禁止するか
- Match成立時Snapshotと現在値のどちらを合流情報に使うか

MVPでは対戦中の合流情報不整合を避けるため、Active Match中は該当情報を変更不可とする案を第一候補とする。

## OQ-04 Host Assignment Algorithm

**Open Question — Implementation Detail**

- 完全ランダム、前回Host履歴との交互化、または偏りを抑える別方式
- Host変更履歴を次回選出へ反映するか

プロダクト要件は「片方へ不合理に偏らないこと」であり、具体方式はImplementation Planで決める。

## OQ-05 Preset Message Set

**Open Question — Validation**

- MVP開始後に追加すべき定型メッセージ
- 各Message Typeの利用頻度
- 「Room recreated」「Ready」等が必要か

初期セットはRoom created / Joined / Can't find the room / Please try again / Please waitとし、実利用で検証する。
