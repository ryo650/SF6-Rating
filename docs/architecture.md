# SF6-Rating — Architecture

Status: Draft  
Product: SF6-Rating  
Related: [Product Spec](./product-spec.md)  
Template: `AI-Development-OS/templates/architecture.md`

---

# 1. Architecture Overview

## Summary

SF6-Ratingは、Next.jsで構築するレスポンシブWebアプリケーションである。Vercelへデプロイし、SupabaseのPostgreSQL、Auth、Realtime、Storageを利用する。

システム設計では、PostgreSQLに保存された状態を唯一の正しい状態（Source of Truth）とする。マッチ成立、結果確定、レーティング更新、シーズン処理、利用制限などの重要な状態変更は、信頼されたServer / Database処理でトランザクションとしてAtomicに確定する。Supabase Realtimeは状態を決定するためではなく、確定済みの変更をクライアントへ速やかに通知するために使用する。

MVPでは専用の常駐Backend、Redis、専用Matchmaking Serverを導入しない。Next.js + Supabase + Vercelで開始し、実測でボトルネックが確認された場合にのみ追加インフラを検討する。

---

# 2. Technology Stack

## Frontend

- Next.js
- React
- TypeScript
- Next.js App Router
- レスポンシブWeb UI
- モバイルファースト
- 日本語 / 英語の国際化対応

## Backend

- Next.js Server Actions / Route Handlers
- Supabase Postgres Functions / RPC
- PostgreSQL Transaction
- Supabase Realtime

ブラウザは操作要求を送信するだけとし、重要なビジネスルールと状態遷移はServer / Database側で検証・実行する。

## Database

- Supabase PostgreSQL
- SQL MigrationをGitで管理
- Row Level Security（RLS）
- Foreign Key、Unique Constraint、Check Constraint、Index
- 現在レートとRating Historyを分離して保存

## Authentication

Supabase Authを利用する。

MVP必須:

- Google OAuth
- Discord OAuth
- Email / Password

追加候補:

- X OAuth

認証ユーザーIDを`profiles`と紐づける。認証プロバイダーの秘密情報やパスワードをアプリケーションテーブルへ保存しない。

## Hosting

- Vercel
- GitHub連携によるPreview Deployment / Production Deployment

## Storage

Supabase Storageを利用する。

- `avatars`: Public bucket
- 将来disputeの証拠画像を扱う場合: Private bucket

プロフィール画像は公開閲覧可能とするが、アップロード・更新・削除は本人だけに許可する。

## External Services

- Supabase
- Vercel
- Google OAuth
- Discord OAuth
- X OAuth（MVP追加候補）
- Street Fighter 6 Custom Room（外部ゲーム内フロー。API連携は行わない）

---

# 3. System Components

## Web Client

役割:

- アカウント登録・ログインUI
- プロフィール、ランキング、募集一覧の表示
- 対戦待機、手動マッチ要求
- Match Room表示と定型メッセージ操作
- 対戦結果報告
- Realtimeイベントの購読
- 再接続時の最新状態再取得

クライアントの保持状態を正解とはみなさず、画面復元時はDatabaseから最新状態を取得する。

## Application Server

役割:

- セッションと権限の確認
- 入力値の検証
- 信頼されたPostgres Function / RPCの呼び出し
- 公開・限定公開・非公開データの境界適用
- Rate Limiting
- 管理者操作の認可

Service Role等の秘密鍵はServer側だけで使用し、ブラウザへ公開しない。

## PostgreSQL / Domain Logic

役割:

- 永続的なシステム状態の管理
- 待機・マッチ成立の競合制御
- Matchステートマシン
- 双方の結果報告の整合確認
- Rated / Unrated判定
- Elo計算、Rating History作成、現在レート更新
- Placement、シーズン、24時間再戦制限
- dispute、放置履歴、利用制限
- Transaction、制約、Idempotencyによる整合性保護

## Supabase Realtime

役割:

- 募集一覧の更新通知
- マッチ成立通知
- Match Room状態・定型メッセージの更新通知
- 結果報告・確定状態の更新通知

Realtime通知が欠落してもデータを失わない設計とし、再接続時はDatabaseから状態を再取得する。

## Supabase Auth

役割:

- Google / Discord / Email認証
- セッション管理
- JWTを利用したRLSとの連携

## Supabase Storage

役割:

- 公開プロフィール画像の保存
- 将来必要になった場合の非公開dispute証拠保存

## Admin Interface

役割:

- disputeの確認と解決
- Match結果の確定または無効化
- 放置・問題行動履歴の確認
- 一時的なマッチング制限の付与・解除

---

# 4. Data Flow

## Authentication

```text
User
↓
Next.js UI
↓
Supabase Auth
↓
Session / JWT
↓
RLSを適用してProfileを取得
↓
UI
```

## Waiting and Match Creation

```text
Player A
↓
対戦待機開始 / Player Bへの対戦要求
↓
Next.js Server
↓
Postgres Function / Transaction
├─ AとBが現在waitingか確認
├─ 両者に進行中Matchがないか確認
├─ Rated / Unrated資格を判定
├─ 対象行を競合しない形で確保
├─ waiting_entriesを更新
└─ Matchを1件だけ作成
↓
Commit
↓
Supabase Realtime
↓
両プレイヤーをMatch Roomへ誘導
```

同じ待機プレイヤーに複数の要求が同時到着しても、成立するMatchは1件だけとする。

## Match Room

```text
Match成立
↓
DatabaseにMatch状態とホスト担当を保存
↓
Realtimeで両者へ通知
↓
定型メッセージ / 状態変更をServerで検証
↓
match_eventsへ保存
↓
相手へ通知
```

Match状態は次のステートマシンで管理する。

```text
matched
→ room_setup
→ reporting
→ completed

分岐:
reporting → disputed → completed / cancelled
matched / room_setup / reporting / disputed → cancelled
```

勝敗が正式に存在する終了だけを`completed`、勝敗なしの終了を`cancelled`とする。終了理由は`resolution_type`、後日の結果無効化は`result_validity`、Rating処理は`rating_status`としてlifecycleから分離する。

## Result Confirmation and Rating Update

```text
各Playerが結果を報告
↓
Serverで参加者・Match状態・重複を検証
↓
result_reportsへ保存
↓
双方の報告を比較
├─ 一致しない → 再入力 / disputed
└─ 一致する
    ↓
    1 Transaction内で
    ├─ Rated / Unratedを再確認
    ├─ Elo変動を計算
    ├─ rating_historyを作成
    ├─ profilesの現在レートを更新
    ├─ Matchをcompletedへ更新
    └─ シーズン戦績を更新
    ↓
    Commit
    ↓
    Realtimeで両者へ通知
```

処理途中で失敗した場合は全体をRollbackし、レートだけが更新される等の部分成功を許可しない。

---

# 5. Data Model

詳細なカラム、型、Index、制約はFeature Spec / Implementation Planningで確定する。Architecture段階では以下を主要Entityとする。

## profiles

- Auth Userに1対1で紐づく
- ユーザー名、アイコン、地域
- SF6プレイヤーネーム、SF6ユーザーコード
- 現在レート
- Placement状態・完了セット数
- 公開プロフィール情報
- ユーザー権限

## matches

- Player A / Player B
- Rated / Unrated
- `status`: `matched | room_setup | reporting | disputed | completed | cancelled`
- `resolution_type`: `normal | forfeit | admin_result | mutual_cancel | nonresponse_no_rating | mutual_no_rating | admin_invalid_no_rating | season_boundary_no_rating`
- `result_validity`: result-bearing Matchについて`valid | invalidated`
- `rating_status`: `not_applicable | pending | applied | correction_pending | corrected`
- ホスト担当
- 最終スコア、勝者
- シーズン
- 成立・開始・完了・キャンセル時刻

1ユーザーが複数の進行中Rated Matchへ同時参加しないよう、Server処理とDatabase制約で保護する。

## result_reports

- Match
- 報告者
- 自分と相手のスコア
- 提出時刻
- 再入力状態

`Match × User`ごとに有効な報告を一意に扱う。

## rating_history

- Match
- Player
- Season
- Rating Before
- Rating Change
- Rating After
- Placement倍率
- 計算に使用したパラメータ
- 作成理由・時刻

`Rated Match × Player`ごとにレーティング変更を一度だけ記録する。

## waiting_entries

- Player
- 現在レート
- 地域
- 待機状態
- 待機開始時刻
- マッチング検索に必要な情報

自動マッチングと募集一覧は同じ待機プールを利用する。

## seasons

- シーズン名
- 開始・終了時刻
- 状態
- Rating計算・ソフトリセットに必要な設定

## season_player_records

- Season
- Player
- 現在 / 最終レート
- 順位
- Rated勝敗
- Placement / ランキング資格
- シーズン成績

## match_events

- Match
- Actor
- Event Type
- 定型メッセージ
- 作成時刻

自由入力チャットは保存しない。

## user_restrictions

- Player
- 制限種別
- 理由
- 開始・終了時刻
- Admin
- 有効状態

## disputes

- Match
- 両者の報告内容
- 状態
- 運営判断
- 対応Admin
- 解決時刻

## Relationships

- Auth User has one Profile
- Profile has many Matches as Player A or Player B
- Match has many Result Reports
- Match has zero or two Rating History records when Rated and completed
- Match has many Match Events
- Match has zero or one Dispute
- Season has many Matches and Season Player Records
- Profile has zero or one active Waiting Entry
- Profile has many User Restrictions

---

# 6. Authentication and Authorization

全公開スキーマの対象テーブルでRLSを基本有効化する。UIで非表示にするだけではなく、Database側でも権限を制御する。

## Guest

可能:

- 公開ランキングの閲覧
- 公開プロフィールの閲覧
- 公開対象となる戦績・対戦履歴の閲覧

不可:

- 待機・マッチング参加
- Match Room利用
- 結果報告
- 限定公開・非公開情報の閲覧

## Logged-in User

可能:

- 自分のプロフィールの許可された項目を編集
- 自分のプロフィール画像を管理
- 待機開始・終了
- 自分が参加するMatch Roomの閲覧・操作
- 自分が参加するMatchの結果報告
- 許可されたRating Historyの閲覧

不可:

- 現在レートやRating Historyの直接更新
- Matchの勝者・完了状態の直接確定
- 他人のResult Reportの変更
- SeasonやRestrictionの変更
- 他人の限定公開情報の閲覧

## Admin

可能:

- dispute情報の閲覧・解決
- Match結果の確定・無効化
- 放置・問題行動履歴の確認
- 一時的なマッチング制限の付与・解除
- 運営に必要な限定・非公開情報へのアクセス

Admin操作もServer側で認証・権限を確認し、可能な範囲で監査可能な履歴を残す。

## Data Visibility

公開:

- SF6-Ratingユーザー名
- プロフィールアイコン
- レーティング
- 地域
- ランキング順位
- 公開対象の戦績・対戦履歴

限定公開:

- SF6プレイヤーネーム
- SF6ユーザーコード

限定公開情報は現在マッチしている相手とAdminだけが確認できる。

非公開:

- メールアドレス
- OAuth認証情報
- 制限・不正調査情報
- disputeの非公開情報

---

# 7. Security

## Core Policy

RLS、Server-side Validation、Database Constraints、Atomic Transaction、Rate Limitingを重ねて使用する。クライアントからの入力はすべて改変可能なものとして扱う。

## Authentication / Authorization

- Supabase Authで本人を識別する
- ServerとDatabaseの双方で権限を確認する
- Service Role等の秘密鍵をブラウザへ公開しない
- 最小権限を原則とする

## Input Validation

- Server側でSchema Validationを行う
- Match ID、スコア、状態遷移、参加者、期限を検証する
- DatabaseへParameter BindingされたAPI / RPC経由でアクセスする
- React / Next.jsの標準エスケープを維持し、任意HTMLを許可しない

## CSRF

- Cookieベース認証を利用する変更系エンドポイントではOrigin等を検証する
- Next.js / Supabaseの推奨セッション管理に従う
- GETで状態を変更しない

## Database Protection

- SF6ユーザーコードは原則一意
- Result Reportは`Match × User`で重複適用しない
- Rating Historyは`Match × User`で一意
- Match確定・レーティング更新は一度だけ
- 不正な状態遷移をCheck / Server / Functionで拒否
- 重要処理はTransactionで実行

## Rate Limiting

対象例:

- 認証・登録・パスワードリセット
- 待機開始・終了
- 手動マッチ要求
- Result Report
- 定型メッセージ
- dispute作成

通常利用を妨げず、Bot・連打・大量操作を抑止する値をFeature Specで定める。必要に応じてSupabase Auth対応のCAPTCHAを導入する。

## Abuse Prevention

- 同一相手とのRated対戦は結果確定から24時間に1セット
- 双方の報告が一致した場合のみ結果確定
- 放置・dispute履歴を保存
- AdminがMatch無効化・一時制限を実施可能
- 高度な不正検知はMVP外とし、実データを得てから検討

SF6ユーザーコードの厳格な所有確認はMVPでは行わず、なりすましリスクを受容する。問題化した場合は所有確認フローを追加する。

---

# 8. Performance

## Initial Scale

MVPの初期設計目標:

- 登録ユーザー: 1,000〜10,000人
- 同時接続: 100〜300人程度

Supabase Freeの実際のプラン上限を運用開始前と運用中に確認し、目標同時接続と契約上限が一致しない場合はProへの移行または配信設計の調整を行う。

## Performance Requirements

- 募集一覧はページングまたは件数制限を行う
- 全世界の全待機ユーザー情報を全クライアントへ配信しない
- `waiting_entries`のrating、region、status、created_at等へ適切なIndexを設定
- ランキングを毎回全履歴から再計算しない
- Rating Historyと対戦履歴を無制限に読み込まない
- Vercel FunctionsとSupabase Databaseのリージョンを可能な範囲で近づける
- N+1クエリと不要なRealtime購読を避ける

MVPではRedis、専用Cache、専用Matchmaking Serverを導入しない。計測で待機検索、DB、Realtimeのいずれかがボトルネックと確認された場合にのみ検討する。

---

# 9. Reliability

## Source of Truth

PostgreSQLを唯一の正しい状態とする。Realtime通知やブラウザ内状態は補助的なものとして扱う。

- Current Rating: `profiles.current_rating`
- Rating履歴: `rating_history`
- Current SeasonのRated W/L、Match Count、Win Rate、score breakdown: active Seasonの`season_player_records`
- 過去Season成績: completed Seasonの`season_player_records`固定Snapshot
- Public Profileの主要read source: `profiles` + active Seasonの`season_player_records`

completed SeasonのFinal Rating / Ranking / Stats Snapshotは後日のMatch無効化でも変更しない。

## State Recovery

- 進行中MatchをDatabaseへ永続化
- ブラウザを閉じても再ログイン時に進行中Matchを検出
- Realtime再接続時に最新状態を再取得
- 通知欠落だけでMatchや結果を失わない

## Atomicity

以下は1つのTransactionとして処理する。

- マッチ成立と両者の待機解除
- Match結果確定
- Rating History作成
- 現在レート更新
- シーズン戦績更新
- Completed Match無効化時のRating correctionとStats correction

処理の一部だけが成功する状態を許可しない。

## Idempotency

- Match作成は1回
- Result Reportは同じ送信を重複適用しない
- Rating Historyは1 Match / 1 Playerにつき1件
- Match確定は1回
- シーズンリセットは同じSeasonに二重適用しない

Unique Constraintと状態確認を併用する。

## Failure Handling

- DB接続失敗時は重要更新を成功扱いにしない
- Realtime停止時も読取・更新後の再取得で復元可能にする
- 外部OAuth障害時は利用可能な別の認証方式を提示する
- デプロイ失敗時はProductionを更新せず、Vercel上の直前成功版を維持する
- RetryはIdempotencyが保証された処理に限定して使用する

---

# 10. Cost

## Development

- Local: Supabase CLI
- Preview / Test: Supabase Free
- Vercel: 既存Pro契約を利用
- GitHub: 既存リポジトリを利用

## Initial Production

- Supabase Freeで開始
- Vercel Proの既存契約を利用
- ドメイン費用
- Speed Insights、Sentry、Supabase Branching、有料Add-onは初期不採用

Freeプランの停止条件、バックアップ、Database、MAU、Realtime、Storage、Egress等の上限を公開前に再確認する。本番継続性や利用量の観点から必要になった時点でSupabase Proへ移行する。

## Scaling

実測で必要になった場合のみ、次を検討する。

- Supabase Pro
- Realtime上限の拡張
- 専用エラー監視
- Cache / Redis
- 専用Matchmaking Server
- Supabase Branching

---

# 11. Deployment

```text
GitHub Feature Branch
↓
Pull Request
↓
Vercel Preview Deployment
↓
AI Verification / Review
↓
Human Review
↓
mainへMerge
↓
Vercel Production Deployment
```

- Productionは`main`を基準とする
- Database変更はMigrationファイルとしてGit管理する
- Production Databaseを手作業で直接変更しない
- MigrationはLocalとPreview / Testで検証してからProductionへ適用する
- ProductionデータをPreviewへコピーしない

---

# 12. Environments

## Local

- Next.jsローカル開発
- Supabase CLIによるLocal Auth / Database / Storage / Realtime
- Seed Dataを利用
- Migrationの作成・検証

## Preview / Test

- Pull RequestごとのVercel Preview
- 共有の非本番Supabase Freeプロジェクト
- Productionとは異なる認証情報・Database
- Productionの実ユーザーデータを使用しない

Supabase BranchingはMVPでは採用しない。共有Test Databaseでの競合が問題になった場合、またはMigrationの並行検証が必要になった場合に再評価する。

## Production

- `main`ブランチ
- Vercel Production
- Production用Supabaseプロジェクト
- 実ユーザー、Match、Rating、Seasonを保存
- 環境変数と秘密情報をPreview / Testから分離

---

# 13. Observability

## MVPで採用

- Vercel Web Analytics
- Vercel標準ログ / Observability
- Supabase Logs
- SF6-Rating固有のCustom Events

Speed InsightsとSentryは初期不採用とする。性能調査やエラー追跡が標準機能では困難になった場合に導入を検討する。

## Product Events

最低限の候補:

- `signup_completed`
- `matchmaking_started`
- `match_found`
- `matchmaking_cancelled`
- `match_room_opened`
- `match_started`
- `match_completed`
- `result_submitted`
- `result_confirmed`
- `result_disputed`
- `placement_completed`

## Product Metrics

- Match成立率
- 平均Match成立時間
- 対戦完了率
- 1ユーザーあたりのRated 3先数
- 初回利用後の再利用率

## Technical Signals

- Match作成失敗
- 同時マッチ競合の拒否
- Result確定失敗
- Rating Transaction失敗
- Realtime再接続
- dispute率
- Server / Database Error
- Supabase Free利用量と上限への接近

分析イベントへメールアドレス、SF6ユーザーコード等の不要な個人情報を送信しない。

---

# 14. Technical Constraints

- 個人開発を前提とする
- コア対戦体験の品質を優先する
- MVP外の機能へ広げない
- 初期固定費を抑える
- Webサービスとして提供する
- スマートフォンとPCに対応し、モバイルファーストとする
- 日本語・英語へ対応する
- SF6との直接API連携を前提にしない
- 手動結果報告でもRatingの整合性を守る
- 重要な状態変更をクライアントへ委ねない
- PostgreSQLをSource of Truthとする
- 不要なインフラと外部サービスを増やさない
- Feature Specと実装は本Architectureの承認後に進める

---

# 15. Architecture Decisions

## Decision 1 — Next.js + Supabase + Vercel

### Reason

PostgreSQL、Auth、Realtime、Storageを少ないサービス数で利用でき、関連データの多いSF6-RatingをMVPとして速く安全に構築できるため。

## Decision 2 — Server / PostgreSQLで重要状態をAtomicに確定

### Reason

二重マッチ、レート改ざん、部分更新を防ぐため。Realtimeは通知用途に限定し、DatabaseをSource of Truthとする。

## Decision 3 — OAuth + Email Authentication

### Decision

Google、Discord、Email / PasswordをMVP必須とし、Xを追加候補とする。

### Reason

ゲームユーザーとの親和性と登録間口を両立しつつ、MVP必須範囲を抑えるため。

## Decision 4 — 現在レートとRating Historyを分離

### Reason

各Matchによる変動を追跡し、dispute、不正調査、シーズン履歴、将来の再計算へ対応しやすくするため。

## Decision 5 — RLSと公開範囲の分離

### Reason

公開プロフィール、Match相手だけに必要なSF6情報、認証・運営情報をDatabase側でも分離し、最小権限を保つため。

## Decision 6 — DBステートマシンとIdempotency

### Reason

通信切断、再送、ブラウザ終了、同時操作が発生しても、MatchとRatingを一貫した状態へ保つため。

## Decision 7 — Local / Preview / Production

### Reason

Productionデータと開発を分離し、PRごとにUIとフローを確認してから安全に公開するため。Supabase BranchingはMVPではコストと複雑性に見合わないため採用しない。

## Decision 8 — MVP初期は追加インフラなし

### Reason

登録1,000〜10,000人、同時接続100〜300人程度を初期目標とし、実測前にRedisや専用Matchmaking Serverを導入する過剰設計を避けるため。

## Decision 9 — 標準Observabilityから開始

### Reason

初期コストとサービス数を抑えるため、Vercel Web Analytics、標準ログ、Supabase Logs、Custom Eventsを採用する。Speed InsightsとSentryは必要性が確認されてから追加する。

## Decision 10 — Supabase Freeで開始

### Reason

MVPの需要検証ではFreeで開始できるため。利用量、継続性、バックアップ、Realtime上限等から必要になった時点でProへ移行する。

## Decision 11 — Match lifecycleとresolutionを分離

`status`は進行状態だけを表す。`resolution_type`、`result_validity`、`rating_status`を別属性にし、No-Ratingや後日無効化を追加statusとして表現しない。

### Canonical transition table

| From | Operation | To | Authority |
| --- | --- | --- | --- |
| `matched` | Initialize room | `room_setup` | Server |
| `room_setup` | Enter result reporting | `reporting` | Either participant through validated server action |
| `matched` / `room_setup` | Mutual cancel or authorized no-show close | `cancelled` | Both participants, timed participant action, or Admin as specified |
| `reporting` | Matching valid reports / confirmed forfeit | `completed` | Server |
| `reporting` | Reconfirmed mismatch | `disputed` | Server |
| `reporting` | 30-minute manual or 24-hour automatic nonresponse close | `cancelled` | Reporting participant via Server / System job |
| `reporting` | Mutual No-Rating agreement | `cancelled` | Both participants via Server |
| `disputed` | Confirm a result | `completed` | Admin domain action |
| `disputed` | Mutual No-Rating or Admin invalidation | `cancelled` | Both participants or Admin domain action |
| any nonterminal state | Season boundary close | `cancelled` | System rollover job |

Rated Match gateは`matched | room_setup | reporting | disputed`の間維持し、`completed | cancelled`で解除する。`reporting`のnonresponseはfirst reportから5分でUnresponsive導線、30分で手動No-Rating Close、24時間で自動No-Rating Closeとする。`disputed`はAdmin ResolutionまたはMutual No-Rating Resolutionまでgateを維持する。

## Decision 12 — Rated pair cooldownをDatabaseで直列化

Player pairを順序非依存canonical pair keyで表す。Match作成Transaction内でpair単位Lockまたは同等の直列化を行い、24時間cooldown判定とMatch作成を同一Transactionで処理する。Rated / Unrated判定をClient指定だけに依存させない。

## Decision 13 — Completed Match correction

Current Season中のCompleted Match無効化では、元結果を`result_validity=invalidated`として監査用に保持し、RatingとStatsを同じidempotent Domain Actionで補正する。Rated W/L、Rated Match Count、Win Rate、3-0 / 3-1 / 3-2 breakdownから除外し、Rankingへ修正後Ratingを反映し、Public Match Historyから隠す。Placement countは巻き戻さない。`source_match_id + correction_type`等の一意性で二重適用を防止する。

## Decision 14 — Season boundary closes pending Rated Matches

Season終了30分前から新規Rated Matchmakingを停止する。Season終了時点でRating未確定の旧Season Rated Matchは`cancelled + season_boundary_no_rating`で終了する。Dispute / Incidentの監査記録は保持できるが、後からRated結果として復活させず、Soft Reset後のlate deltaを発生させない。

---

# 16. Risks

## Realtime Scale

同時接続や配信イベントが増えると、Supabase Realtimeのプラン上限・メッセージ量・配信方式が制約になる可能性がある。利用量を監視し、Pro移行、購読範囲の縮小、Broadcast設計の改善、専用層を段階的に検討する。

## Concurrent Match Creation

複数ユーザーが同じ待機プレイヤーを同時に選択する可能性がある。PostgreSQL Transaction、行ロックまたは同等の競合制御、Unique Constraint、状態条件付き更新で1件だけ成立させる必要がある。

## Rating Finalization Atomicity

Match確定、Rating History、現在レート、シーズン戦績の一部だけが更新されると整合性が壊れる。1 TransactionとIdempotencyを必須とする。

## Realtime Disconnection

Realtime通知が欠落・遅延する可能性がある。通知へ正しさを依存せず、再接続・再表示時にDatabaseから復元する。

## Historical Rating Recalculation after Dispute

過去Matchを無効化・修正すると、その後のMatchで使用した期待勝率も変化する。単純な差分取消、時系列再計算、補正Entryのいずれを採用するか未決定であり、運用と監査性へ大きく影響する。

## SF6 User Code Impersonation

MVPではSF6ユーザーコードの厳格な本人確認を行わないため、他人のコードを登録するリスクがある。一意制約とAdmin対応で開始し、問題化した場合は所有確認を追加する。

## Initial Rating Accuracy

SF6 Rank / MRから初期レートへの換算が実態とずれる可能性がある。Placementと実運用データで補正し、換算表を再評価する。

## Matchmaking Expansion Rules

許容レート差、地域条件、待ち時間による拡張速度が、対戦品質と成立速度を左右する。Feature Specと運用データで調整する。

## Free Plan Limits

Database、MAU、Realtime、Storage、Egress、停止条件、バックアップ等が本番要件を満たさなくなる可能性がある。利用量と継続性を監視し、必要時にProへ移行する。

## External Dependencies

Vercel、Supabase、OAuth Provider、SF6の障害や仕様変更により一部または全部の機能が利用不能になる。MVPではマルチクラウド冗長化を行わず、状態の永続化、再試行、利用可能な認証手段の複数化で影響を限定する。

---

# 17. Open Questions for Implementation Planning

横断レビューで解決済みのMatch state、Rating丸めとClamp、Master初期Rating境界、同順位、Soft Reset丸め、Dispute evidence、Progressive Restriction、Compensating Correction、データ正本、24時間cooldownのDB保証はここへ残さない。

- Season開始日 / 命名規則
- Nearby country grouping
- Candidate score weights
- Waiting heartbeat間隔
- Match History初期ページ件数
- Rate Limit具体値
- Admin Queue SLA / 通知
- Username検索をMVP必須にするか
- Forfeit時の途中Score任意保存
