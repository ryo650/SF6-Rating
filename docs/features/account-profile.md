# Account / Profile — Feature Spec

Status: Draft  
Product: SF6-Rating  
Feature: Account / Profile  
Related Documents: `docs/product-spec.md`, `docs/architecture.md`

---

# 1. Feature Overview

## Feature Name

Account / Profile

## Summary

ユーザーがGoogle、Discord、またはEmailでアカウントを作成し、3ステップのオンボーディングでSF6プレイヤー情報と初期レーティング情報を登録して、公開プロフィールとマッチング参加資格を得る機能。

## Purpose

レーティング、Placement、戦績、対戦履歴を一人のプレイヤーへ安全に紐付け、ユーザーが最小限の迷いでSF6-Ratingの対戦体験を開始できるようにする。

この機能は次の課題を解決する。

- レーティングと対戦履歴を継続的なユーザーアカウントへ紐付ける
- マッチングとカスタムルーム合流に必要なSF6情報を事前に揃える
- SF6ランク / MRを使って初回Placementの開始地点を決める
- 公開プロフィールに必要な情報と、対戦相手または運営だけが扱う情報を分離する
- モバイル利用でも登録負荷を抑え、途中離脱後に再開できるようにする

---

# 2. User

## Target User

Street Fighter 6をプレイし、SF6-Ratingで3先のレート戦へ参加したいすべてのプレイヤー。

初期ローンチでは日本のプレイヤーを中心とするが、日本語・英語UIを提供し、海外ユーザーも登録可能とする。

## User Goal

ユーザーはこの機能を使って、次を達成したい。

- 利用しやすい認証方法でアカウントを作成する
- 自分のSF6プレイヤー情報を登録する
- 初期仮レートとPlacementの説明を確認する
- 公開プロフィールを作成する
- オンボーディングを完了し、マッチングへ参加できる状態になる
- 登録後に許可されたプロフィール情報を更新する
- 必要な場合は自分でアカウントを削除する

---

# 3. User Flow

## 3.1 OAuth Registration

1. Guestが登録画面を開く
2. GoogleまたはDiscordを選択する
3. OAuth Providerで認証する
4. 認証成功後、オンボーディング状態を作成または復元する
5. OAuthの表示名・アイコンが取得できる場合は初期候補として利用する
6. ユーザーを未完了のオンボーディングステップへ移動する

## 3.2 Email Registration

1. GuestがEmailとPasswordを入力する
2. アカウントを仮作成する
3. 確認メールを送信する
4. ユーザーがメール認証を完了する
5. 認証完了後、オンボーディングを開始する
6. メール認証前はオンボーディング完了およびマッチング参加を許可しない

## 3.3 Three-Step Onboarding

### Step 1 — Account

1. ユーザーがSF6-Ratingの一意なユーザー名を設定する
2. OAuthからアイコンを取得できる場合は初期アイコンとして表示する
3. アイコンがない場合はデフォルトアイコンを表示する
4. ユーザーは任意で画像をアップロードできる
5. 入力内容を保存して次へ進む

SF6プレイヤーネームが入力済みまたは取得済みの場合、それをSF6-Ratingユーザー名の初期候補としてコピーできる。最終保存時には一意性を検証する。

### Step 2 — SF6 Player Info

1. SF6プレイヤーネームを入力する
2. SF6ユーザーコードを入力する
3. 国を選択する
4. 国に対応する大まかな地域を選択する
5. 入力内容を保存して次へ進む

### Step 3 — Rating Setup

1. 現在のメインキャラクターを選択する
2. SF6ランクを選択する
3. Masterの場合はMRを入力する
4. Product Specの換算ルールから初期仮レートを算出する
5. 初期仮レートと「最初の10セットはPlacementである」ことを表示する
6. ユーザーが内容を確認してオンボーディングを完了する
7. マッチング参加資格を有効にする

## 3.4 Resume Onboarding

1. オンボーディング途中で離脱したユーザーが再度ログインする
2. 保存済みのオンボーディング状態を取得する
3. 最初の未完了ステップへ自動的に移動する
4. 保存済みの入力内容を表示する
5. ユーザーが続きから完了する

## 3.5 Edit Profile

1. Logged-in Userが自分のプロフィール設定を開く
2. 変更可能な項目を編集する
3. 変更制限と公開範囲を確認する
4. Server側の検証後に変更を保存する
5. 公開対象項目は公開プロフィールへ反映する

メインキャラクター、SF6ランク、MRを登録後に更新しても、現在のSF6-Ratingおよび完了済みPlacementの結果は再計算しない。

## 3.6 Delete Account

1. Ownerがアカウント削除を選択する
2. 影響と匿名化方針を明示する
3. 再認証または同等の本人確認を行う
4. 削除を明示的に確定する
5. 個人プロフィール情報と認証上必要なデータを削除または匿名化する
6. 過去MatchとRating Historyは匿名ユーザーへ紐付けて保持する
7. 削除後はログインとマッチングを利用できない

---

# 4. Functional Requirements

## Requirement 1 — Authentication

- MVPではGoogle、Discord、Email / Passwordによる登録・ログインを提供する
- Xログインは追加候補とし、MVP必須要件には含めない
- Email / Password登録はメール認証を必須とする
- 認証情報はSupabase Authで管理し、ProfileへPasswordを保存しない
- 認証済みユーザーだけがオンボーディングを完了できる

## Requirement 2 — Onboarding

- オンボーディングはAccount、SF6 Player Info、Rating Setupの3ステップで構成する
- 各ステップの完了内容と進行状態を永続保存する
- 途中離脱後は最初の未完了ステップから再開できる
- 全必須項目が揃うまでオンボーディング完了扱いにしない
- オンボーディング未完了ユーザーはマッチングへ参加できない
- 完了時に初期仮レートとPlacement状態を安全なServer / Database処理で作成する

## Requirement 3 — Username

- SF6-Ratingユーザー名を必須とする
- ユーザー名は大文字・小文字等の正規化ルールを含めて一意性を保証する
- SF6プレイヤーネームを初期候補としてコピーできる
- 初期候補が既に使用中の場合は別のユーザー名を求める
- Ownerはユーザー名を変更できる
- ユーザー名変更は前回変更の確定時刻から30日に1回までとする
- 変更してもAccount、Rating、Match、Rating Historyの紐付けは維持する

## Requirement 4 — SF6 Player Identity

- SF6プレイヤーネームを必須とする
- SF6ユーザーコードを必須とする
- 1アカウントが保持できる有効なSF6ユーザーコードは1つとする
- 同じSF6ユーザーコードを複数アカウントへ同時登録できない
- OwnerはSF6ユーザーコードを変更できる
- ユーザーコード変更は前回変更の確定時刻から30日に1回までとする
- MVPではSF6ユーザーコードの厳格な所有確認を必須にしない
- 重複やなりすましの問題はAdminが調査・修正できる余地を残す

## Requirement 5 — Region

- 国と、その国に対応する大まかな地域を登録する
- 国は公開プロフィールに表示する
- 大まかな地域は公開プロフィールに表示せず、マッチング内部で利用する
- 国・地域の値は自由入力ではなく管理された選択肢を基本とする
- 地域更新後のマッチングへの適用方法はMatchmaking Feature Specで定義する

## Requirement 6 — Initial Rating Inputs

- 現在のメインキャラクターとSF6ランクを登録する
- Masterの場合はMRを登録する
- 初期仮レートはProduct Specに定義されたRank / MR換算ルールで算出する
- 最初の10セットをPlacementとして開始する
- メインキャラクター、Rank、MRは初回仮レート算出時にのみレーティングへ影響する
- オンボーディング完了後にこれらを変更しても、現在レート、Rating History、Placement進行度を変更または再計算しない
- レート戦のマッチ成立前にはキャラクター関連情報を表示しない

## Requirement 7 — Avatar

- OAuth Providerから取得できるアイコンを初期値として利用できる
- OAuthアイコンがない場合はデフォルトアイコンを使用する
- Ownerは任意で画像をアップロードしてアイコンを変更できる
- アイコンは公開プロフィールおよび募集一覧で表示可能とする
- アップロードされた画像は本人だけが変更・削除できる
- 対応形式、容量、解像度、加工方法はOpen Questionsで定義する

## Requirement 8 — Public Profile

- オンボーディング完了後のプロフィールは常に公開する
- MVPではプロフィールの非公開設定を提供しない
- 公開対象には少なくともユーザー名、アイコン、国、現在レート、公開対象の戦績・対戦履歴を含められる
- Placement中はその状態を示し、ランキング対象外であることを明確にする
- 自己紹介文を提供しない
- SF6ユーザーコード、詳細地域、Email、OAuth認証情報、運営情報を公開プロフィールに表示しない
- SF6プレイヤーネームとSF6ユーザーコードのMatch Roomでの限定公開はMatch Room Feature Specで定義する

## Requirement 9 — Profile Editing

- Ownerは許可されたプロフィール項目を編集できる
- 更新はServer側で認証、所有権、入力値、変更クールダウンを検証する
- 一意項目はDatabase制約でも競合を防ぐ
- 一部の更新が失敗した場合に不完全なプロフィール状態を作らない
- レート、Rating History、Placement完了数、戦績はプロフィール編集から直接変更できない

## Requirement 10 — Account Deletion

- Ownerは自分でアカウント削除を開始できる
- 削除前に不可逆性と匿名データ保持方針を説明する
- 誤操作防止のため再認証または同等の強い確認を要求する
- 個人プロフィール情報を削除または匿名化する
- 過去MatchおよびRating Historyは整合性・監査性のため匿名データとして保持する
- 削除済みアカウントはログイン、プロフィール編集、マッチング参加ができない
- 削除処理は重複実行されても二重削除や参照破損を起こさない

---

# 5. Product Rules

1. MVP必須の認証方法はGoogle、Discord、Email / Passwordとする。
2. Xログインは追加候補であり、MVP必須ではない。
3. Email / Password登録ではメール認証完了を必須とする。
4. オンボーディングは3ステップで構成し、途中状態を保存する。
5. オンボーディング完了まではマッチングへ参加できない。
6. SF6-Ratingユーザー名は一意とする。
7. ユーザー名は30日に1回まで変更できる。
8. SF6プレイヤーネームはSF6-Ratingユーザー名の初期候補としてコピーできるが、両者は別の情報として管理する。
9. 1 SF6ユーザーコードは1 SF6-Ratingアカウントにのみ紐付ける。
10. 1アカウントが保持できる有効なSF6ユーザーコードは1つとする。
11. SF6ユーザーコードは30日に1回まで変更できる。
12. 国は公開し、大まかな地域は非公開でマッチング内部にのみ利用する。
13. メインキャラクター、Rank、MRは初回仮レート算出にのみ使用する。
14. オンボーディング完了後のメインキャラクター、Rank、MR変更はSF6-Ratingへ影響しない。
15. プロフィールアイコンはOAuth画像、デフォルト画像、本人アップロード画像のいずれかを使用できる。
16. MVPでは自己紹介文を提供しない。
17. プロフィールは常に公開し、非公開設定を提供しない。
18. SF6ユーザーコード、詳細地域、Email、認証情報、運営情報は公開しない。
19. Rating、Rating History、Placement、戦績はユーザーが直接編集できない。
20. アカウント削除後も過去MatchとRating Historyは匿名化して保持する。
21. ユーザー名およびユーザーコードの30日制限はそれぞれ独立して管理する。
22. 30日の起点は各変更がServerで正常に確定した時刻とする。

---

# 6. States

## Authentication States

### Guest

未認証。公開プロフィールとランキングの閲覧は可能だが、オンボーディング、編集、マッチングは利用できない。

### Email Verification Pending

Emailアカウントは作成済みだがメール未認証。確認案内、再送、Email修正またはログイン導線を表示し、オンボーディング完了とマッチングを無効にする。

### Authenticated

認証済み。オンボーディング状態に応じて次の画面へ進む。

### Authentication Error

OAuth拒否・失敗、期限切れリンク、認証情報不正等。原因を安全な範囲で説明し、再試行または別方式を提示する。

## Onboarding States

### Not Started

認証済みだがオンボーディング開始前。Step 1へ移動する。

### Account In Progress

Step 1を入力中または保存済み。ユーザー名・アイコンの状態を表示する。

### SF6 Info In Progress

Step 1完了、Step 2未完了。SF6プレイヤー情報と地域を入力する。

### Rating Setup In Progress

Step 1・2完了、Step 3未完了。メインキャラクター、Rank / MR、初期仮レートを扱う。

### Completion Processing

最終確定処理中。二重送信を防ぎ、同じ完了処理を複数回適用しない。

### Completed / Placement

オンボーディング完了。仮レートが設定され、10セットのPlacement中。マッチング可能だがランキング対象外。

### Completed / Rated

Placement完了後の通常状態。Account / Profileとしては閲覧・編集可能。

### Onboarding Error

保存または最終確定に失敗。保存済み状態を保持し、再試行を可能にする。

## Profile States

### Loading

公開または自分のプロフィールを取得中。スケルトン等で待機状態を示す。

### Active

通常の公開プロフィール。公開可能な情報だけを表示する。

### Editing

Ownerが変更可能な項目を編集中。変更不可項目とクールダウンを明示する。

### Change Cooldown

ユーザー名またはSF6ユーザーコードの変更から30日未満。次回変更可能時刻を表示し、対象の保存操作を無効にする。

### Deleted / Anonymized

アカウント削除済み。個人プロフィールは表示せず、過去履歴では匿名プレイヤーとして扱う。

### Profile Error

取得または保存失敗。既存の確定済みデータを失わず、再試行を案内する。

---

# 7. Edge Cases

## OAuth Data Is Missing

OAuth Providerから表示名または画像が取得できない場合、空の必須入力またはデフォルトアイコンを使用し、オンボーディングを継続できる。

## OAuth Data Changes Later

Provider側の表示名や画像が変わっても、ユーザーが明示的に選択しない限りSF6-Ratingのユーザー名やアップロード済みアイコンを自動上書きしない。

## Email Verification Link Is Expired

期限切れを説明し、確認メールを再送できる。未認証のままオンボーディング完了扱いにしない。

## Username Conflict

候補または保存しようとしたユーザー名が既に使用中の場合、既存所有者の情報を開示せず、別の名前を求める。同時保存時もDatabaseの一意制約で一方だけ成功させる。

## Username Case and Normalization Conflict

大文字・小文字、全半角、Unicode正規化等で見た目が同じまたは紛らわしい値をどう扱うかは共通の正規化ルールに従う。詳細はOpen Questionsとする。

## SF6 User Code Conflict

入力したSF6ユーザーコードが別アカウントへ登録済みの場合、保存を拒否する。厳格な所有確認はMVPでは行わないため、心当たりがない場合のAdmin問い合わせ導線を用意する。

## Cooldown Boundary

30日経過判定はClient時刻ではなくServer時刻を使用する。ユーザー名とSF6ユーザーコードのクールダウンは独立して判定する。

## Rank and MR Inconsistency

Master以外でMRが入力された場合は利用しない、または保存を拒否する。MasterでMRが必要条件を満たさない場合は仮レートを確定しない。

## User Changes Rank after Onboarding

プロフィール表示用データは更新できるが、現在レート、過去の初期レート、Placement進行度は変更しない。レーティングが再計算されないことを保存前に明示する。

## Interrupted Onboarding

ブラウザ終了、通信切断、別端末への移動後も保存済みステップを復元する。未保存の入力が失われる可能性は明示し、完了済みステップを巻き戻さない。

## Concurrent Editing

複数タブ・端末から同時更新された場合、古い更新で新しい確定値を意図せず上書きしない。競合時は最新状態を再取得してユーザーへ案内する。

## Avatar Upload Failure

画像アップロード失敗時も既存アイコンを維持し、プロフィール全体を壊さない。再試行またはデフォルト画像への切替を可能にする。

## Account Deletion with Active Match

進行中Match、未確定Result、dispute、または運営制限がある場合の削除実行タイミングはOpen Questionsとする。少なくとも参照整合性を壊す即時削除は行わない。

## Duplicate Account Deletion Request

同じ削除要求が複数回送信されても、匿名化と認証削除を安全に一度だけ適用する。

## Deleted Opponent in Match History

他ユーザーの対戦履歴では削除済みユーザーを匿名表示し、Match結果とRating Historyの数値は保持する。

## Region Option Changes

地域マスタの変更後も既存ユーザーを不正な状態にしない。廃止地域の再選択を促す場合でも、現在レートへ影響させない。

---

# 8. Error Handling

- エラー文は日本語・英語で提供する
- 何が失敗したか、ユーザーが次に何をできるかを明示する
- 認証エラーでは内部情報、存在するEmail、他ユーザー情報を不要に開示しない
- 一意性競合は入力項目の近くへ表示し、他の保存済み項目を失わない
- オンボーディング保存失敗時は完了扱いにせず、最後に確定したステップから再試行できる
- 最終完了処理の一部だけを成功させない
- 仮レート作成とPlacement開始に失敗した場合、マッチングを有効にしない
- Profile更新失敗時は直前の確定値を維持する
- Avatar更新失敗時は既存画像を維持する
- Cooldown中の変更要求はServer側でも拒否し、次回変更可能時刻を返す
- 同じ送信が再試行されても重複Profile、重複Placement、重複削除を作らない
- 外部OAuth Provider障害時は利用可能な別の認証方法を提示する
- DatabaseまたはStorage障害時は成功表示を行わない
- 削除処理が完了できない場合はアカウントを中途半端に公開状態へ残さず、復旧可能な状態と運営確認手段を確保する

---

# 9. Permissions

## Guest

- 公開プロフィールを閲覧できる
- 公開ランキングからプロフィールへ移動できる
- Google、Discord、Email / Passwordで登録・ログインできる
- 非公開データを閲覧できない
- Profile編集、オンボーディング完了、マッチング参加はできない

## Logged-in User

- 自分のオンボーディング状態を閲覧できる
- 自分のオンボーディング入力を保存できる
- オンボーディング完了後にマッチングへ参加できる
- 他ユーザーの公開プロフィールを閲覧できる
- 他ユーザーの非公開情報や編集画面を閲覧できない
- Rating、Rating History、Placement、戦績を直接変更できない

## Owner

- 自分の許可されたプロフィール情報を編集できる
- 自分のAvatarをアップロード・変更・削除できる
- 30日ルールの範囲で自分のユーザー名とSF6ユーザーコードを変更できる
- 自分の非公開SF6情報と詳細地域を確認できる
- 自分のアカウント削除を開始・確定できる
- 自分の認証情報以外へアクセスできない

## Admin

- 運営上必要な範囲でProfile、SF6ユーザーコード、変更履歴、削除状態を確認できる
- 重複・なりすまし・入力ミス等の調査と修正を行える
- ユーザー本人では解決できないSF6ユーザーコード問題へ対応できる
- 個人情報へのアクセスは最小限とし、一般ユーザー向けAPIからAdmin権限を利用できない
- Ratingの変更はAccount / Profile編集ではなく、Rating / Dispute側の信頼された処理に限定する

すべての公開テーブルではRLSを基本有効化し、Owner判定、公開読取、Admin操作をDatabase側でも制御する。Service Role等の秘密鍵はBrowserへ公開しない。

---

# 10. Data

実際のテーブル・カラム設計ではなく、このFeatureが必要とするプロダクトデータを示す。

## Auth Account

- Auth User ID
- Authentication Provider
- Email
- Email Verified At
- Account Created At
- Last Sign-in At
- Account Status

## Profile

- Auth User ID
- Public User ID
- Username
- Username Normalized Value
- Username Changed At
- Avatar Source
- Avatar Reference
- Country
- Broad Region
- Profile Status
- Onboarding Status
- Onboarding Current Step
- Onboarding Completed At
- Created At
- Updated At
- Deleted / Anonymized At

## SF6 Player Info

- Profile
- SF6 Player Name
- SF6 User Code
- SF6 User Code Normalized Value
- SF6 User Code Changed At
- Current Main Character
- Current SF6 Rank
- Current SF6 Rank Tier
- Current MR
- Updated At

## Initial Rating Setup

- Profile
- Rank / MR Snapshot Used for Initial Rating
- Initial Rating
- Placement Required Sets
- Placement Completed Sets
- Placement Status
- Initial Rating Calculated At

初期値算出後に現在のRank / MRが変わっても、上記SnapshotとInitial Ratingを上書きしない。

## Avatar Asset

- Owner
- Storage Reference
- Source Type: OAuth / Default / Upload
- Content Type
- Size
- Created At
- Active Status

## Profile Change Metadata

- Username Last Changed At
- SF6 User Code Last Changed At
- Profile Updated At
- 必要に応じた変更監査情報

## Deleted Account Representation

- Anonymous Player IDまたは同等の参照
- Deleted At
- Match / Rating History保持用の非個人参照
- 個人情報削除・匿名化状態

---

# 11. Dependencies

- Supabase Auth
- Google OAuth
- Discord OAuth
- Email配信およびメール認証
- Supabase PostgreSQL
- Row Level Security
- Next.jsのServer-side validation / trusted operations
- Supabase StorageのAvatar用Public bucket
- Product Specの初期レート換算ルール
- Placement / Rating機能
- 公開Profile / Ranking / History機能
- Match Roomの限定公開ルール
- Matchmakingの参加資格・地域利用ルール
- Admin機能
- 日本語・英語の国・地域・ランク・キャラクターマスタ
- アカウント削除時にMatch / Rating Historyを保持できるデータモデル

---

# 12. Non-Functional Requirements

## Performance

- 認証後にオンボーディング状態を取得し、不要な全履歴を読み込まず適切なステップへ遷移できる
- 公開プロフィールは必要な公開情報だけを取得する
- AvatarはWeb表示向けに過度な容量を配信しない
- Profile取得・更新にN+1クエリを発生させない
- 初期想定の登録ユーザー1,000〜10,000人規模で、一意性確認と公開プロフィール取得に適切なIndexを利用できる

## Security

- PasswordとOAuth SecretをProfileへ保存しない
- Email、SF6ユーザーコード、詳細地域、認証情報、運営情報を公開レスポンスへ含めない
- 変更系操作は毎回認証・所有権・入力値・変更期限をServer側で検証する
- ユーザー名とSF6ユーザーコードの一意性をDatabase制約でも保証する
- AvatarアップロードはOwnerだけに許可し、許可形式と容量を検証する
- 任意HTMLや実行可能ファイルをAvatarとして受け付けない
- アカウント削除は再認証または同等の確認を要求する
- 分析イベントへEmail、SF6ユーザーコード、詳細地域等の不要な個人情報を送信しない
- 認証・登録・メール再送・プロフィール更新・Avatarアップロードへ適切なRate Limitを適用する
- 必要になった場合にSupabase Auth対応CAPTCHAを追加できる

## Privacy

- 公開プロフィールと非公開Profile情報を明確に分離する
- 国だけを公開し、大まかな地域はマッチング用途に限定する
- SF6ユーザーコードは現在のMatch相手とAdmin等、必要な主体にのみ限定公開する
- アカウント削除時は個人情報を削除または匿名化し、履歴保持の目的を事前に説明する

## Reliability

- PostgreSQLをProfileとオンボーディング状態のSource of Truthとする
- オンボーディング最終確定、初期仮レート作成、Placement開始は部分成功を許可しない
- 再送・二重クリックで重複Profileや重複Placementを作らない
- RealtimeやClient状態が失われても再ログイン時にDatabaseから復元できる
- 外部OAuth障害時も別の認証方式が利用可能である

## Accessibility

- すべてのフォーム項目に明確なLabelとエラー関連付けを提供する
- Keyboardだけで登録、オンボーディング、編集、削除確認を操作できる
- Focus順序とFocus表示を維持する
- 色だけで必須、成功、エラー、公開範囲を伝えない
- スクリーンリーダーへステップ、検証エラー、保存完了を通知する

## Mobile

- モバイルファーストで3ステップを完了できる
- 小さい画面でフォーム、ランク選択、MR入力、Avatar操作、確認内容が欠けない
- 途中保存と再開がスマートフォンでも機能する
- タップ対象と入力UIをモバイル利用に適した大きさにする
- PCブラウザでも同じ機能を利用できる

## Localization

- 主要UI、Validation、Error、メール認証案内、削除確認を日本語・英語で提供する
- 国、地域、ランク、キャラクターは内部IDと表示名を分離する
- 日時と30日後の変更可能時刻をLocale / Timezoneに応じて表示し、判定はServer上の絶対時刻で行う

---

# 13. Acceptance Criteria

## Authentication

- [ ] GuestがGoogleで登録・ログインできる
- [ ] GuestがDiscordで登録・ログインできる
- [ ] GuestがEmail / Passwordで登録できる
- [ ] Email登録者はメール認証完了前にオンボーディングを完了できない
- [ ] Email確認メールを再送できる
- [ ] OAuthの表示名または画像がなくても登録を継続できる
- [ ] XログインがなくてもMVP必須要件を満たす

## Onboarding

- [ ] Account、SF6 Player Info、Rating Setupの3ステップが提供される
- [ ] 各ステップの確定内容と進行状態が保存される
- [ ] 途中離脱後、次回ログイン時に未完了ステップから再開できる
- [ ] オンボーディング未完了ユーザーはマッチングへ参加できない
- [ ] 必須情報が欠けている場合は完了できない
- [ ] 完了時に初期仮レートと10セットのPlacementが作成される
- [ ] 最終確定の二重送信で初期レートやPlacementが重複作成されない
- [ ] 完了画面で初期仮レートとPlacementの説明を確認できる

## Username and SF6 Identity

- [ ] SF6プレイヤーネームをSF6-Ratingユーザー名の初期候補としてコピーできる
- [ ] SF6-Ratingユーザー名とSF6プレイヤーネームが別項目として保持される
- [ ] 同じ正規化済みユーザー名を複数アカウントが取得できない
- [ ] ユーザー名変更後30日間は再変更できない
- [ ] 30日経過後は再変更できる
- [ ] 1アカウントに有効なSF6ユーザーコードを1つだけ登録できる
- [ ] 同じ正規化済みSF6ユーザーコードを複数アカウントへ登録できない
- [ ] SF6ユーザーコード変更後30日間は再変更できない
- [ ] ユーザー名とユーザーコードのクールダウンが独立して動作する
- [ ] Client時刻を変更しても30日制限を回避できない

## Region and Rating Inputs

- [ ] 国と大まかな地域を登録できる
- [ ] 公開プロフィールには国だけが表示される
- [ ] 大まかな地域は公開プロフィールの取得結果に含まれない
- [ ] メインキャラクターとRankを登録できる
- [ ] Masterの場合はMRを扱える
- [ ] Product Specのルールに基づく初期仮レートが算出される
- [ ] 登録後にメインキャラクター、Rank、MRを変更しても現在レート、初期レートSnapshot、Placement進行度が変化しない

## Avatar and Public Profile

- [ ] OAuthアイコンを初期値として利用できる
- [ ] OAuthアイコンがない場合はデフォルトアイコンが表示される
- [ ] Ownerが許可された画像をアップロードしてAvatarを変更できる
- [ ] Avatar更新失敗時に既存Avatarが維持される
- [ ] Owner以外はAvatarを変更・削除できない
- [ ] 完了済みプロフィールが常に公開される
- [ ] MVPにプロフィール非公開設定が存在しない
- [ ] MVPに自己紹介文が存在しない
- [ ] 公開プロフィールにSF6ユーザーコード、詳細地域、Email、OAuth情報、運営情報が表示されない
- [ ] Rating、Rating History、Placement、戦績をプロフィール編集から変更できない

## Account Deletion

- [ ] Ownerが自分のアカウント削除を開始できる
- [ ] 削除前に個人情報の削除・匿名化と履歴保持が説明される
- [ ] 削除確定に再認証または同等の確認が必要である
- [ ] 削除後はログイン、編集、マッチング参加ができない
- [ ] 削除後に個人プロフィール情報が公開されない
- [ ] 過去MatchとRating Historyが匿名データとして保持される
- [ ] 他ユーザーの対戦履歴が参照破損しない
- [ ] 削除要求の重複送信でデータ不整合が起きない

## Quality

- [ ] Guest、Logged-in User、Owner、Adminの権限がRLSとServer-side validationで守られる
- [ ] 通信切断後にオンボーディング状態を復元できる
- [ ] 同時更新や一意性競合で重複データが作成されない
- [ ] エラー時に確定済みデータを失わず再試行できる
- [ ] 主要フローを日本語・英語で利用できる
- [ ] 主要フローをスマートフォンとPCブラウザで完了できる
- [ ] Keyboardとスクリーンリーダーで主要フォームを操作できる

---

# 14. Out of Scope

- XログインのMVP必須化
- Apple、Twitch、GitHub等の追加OAuth Provider
- SF6ユーザーコードの厳格な本人確認
- SF6またはCAPCOM APIとの直接連携
- SF6プレイヤー情報の自動取得・自動同期
- Profileの非公開設定
- 自己紹介文
- SNSリンク
- フレンド、フォロー、DM、コメント
- キャラクター別レーティング
- 登録後のRank / MR変更によるSF6-Rating再計算
- レート戦マッチ成立前のキャラクター情報表示
- 高度なAvatarモデレーション
- ネイティブアプリ
- Matchmaking / Waiting Poolの詳細仕様
- Match Roomの詳細仕様
- Result Reporting / Ratingの詳細仕様
- Placement / Seasonの詳細仕様
- Ranking / Historyの詳細仕様
- Dispute / Adminの詳細仕様

---

# 15. Open Questions

## Username

- ユーザー名の最小・最大文字数
- 使用可能文字、予約語、禁止語
- 大文字・小文字、全半角、Unicodeの正規化方式
- プロフィールURLをユーザー名に連動させるか、変更されないPublic User IDを使うか
- 過去ユーザー名を予約・履歴保持するか
- なりすましや不適切名に対するAdmin運用

## SF6 Player Information

- SF6ユーザーコードの正確な形式と正規化ルール
- SF6プレイヤーネームの文字数・使用可能文字
- SF6ユーザーコード重複時の問い合わせ・所有権移管フロー
- SF6ユーザーコード所有確認を将来導入する条件
- Rank / MRの入力値検証範囲
- Master初期レート下限の具体値

## Region

- 対応する国の初期一覧
- 各国の大まかな地域区分
- 国・地域マスタの更新手順
- 登録後の国・地域変更にクールダウンを設けるか
- 地域変更が待機中・進行中Matchへ与える影響

## Avatar

- 対応画像形式
- 最大ファイル容量
- 最小・最大解像度
- Crop、Resize、圧縮の方式
- アニメーション画像を許可するか
- 不適切画像の通報・削除フロー
- OAuth画像を再取得・同期する操作を提供するか
- 古いアップロード画像の保持・削除方針

## Authentication

- Email Password Policy
- Email確認リンクの有効期限と再送制限
- Password Resetの詳細UX
- OAuth Account Linkingと同一Emailの扱い
- XログインをMVP後のどの条件で追加するか
- 認証・登録へCAPTCHAを導入する条件
- 認証系Rate Limitの具体値

## Onboarding

- Step 1でSF6プレイヤーネームを先に入力するUIにするか、Step 2入力後にユーザー名候補へ反映するか
- 各ステップで自動保存するか、「次へ」で保存するか
- 完了後にオンボーディングをやり直す手段を提供するか
- オンボーディング未完了データの保持期間
- 初期仮レート計算結果の丸め方（Rating Feature Specと整合させる）

## Public Profile

- 公開プロフィールに表示する戦績・対戦履歴の正確な項目と件数
- Placement中の仮レートを公開するか
- SF6プレイヤーネームを通常の公開プロフィールへ表示するか
- メインキャラクター、Rank、MRを通常の公開プロフィールへ表示するか
- 削除済みユーザーの表示名とAvatar表現

## Account Deletion

- 削除の猶予期間と取消可否
- 進行中Match、未確定Result、dispute、制限中に削除要求が出た場合の処理
- 法令・規約・監査要件に基づく保持期間
- OAuth Provider側の連携解除範囲
- 削除後のユーザー名とSF6ユーザーコードを再利用可能にする時期
- 匿名Player参照の具体的なデータモデル
- 削除処理失敗時の再試行・運営復旧手順
