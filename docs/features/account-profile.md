# Account / Profile — Feature Spec

Status: Reviewed — Phase 2 Decisions Formalized
Product: SF6-Rating
Feature: Account / Profile
Related Documents: `docs/product-spec.md`, `docs/architecture.md`, `docs/phase-2-account-onboarding-decisions.md`

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
5. 「次へ」で入力内容をServerへ確定保存し、保存成功後に次へ進む

OAuthの表示名が取得済みの場合、それをSF6-Ratingユーザー名の初期候補として利用できる。Step 2より前にSF6プレイヤーネームは未入力のため、MVPではSF6プレイヤーネームからの自動候補生成を必須にしない。

### Step 2 — SF6 Player Info

1. SF6プレイヤーネームを入力する
2. SF6ユーザーコードを入力する
3. 国を選択する
4. 国に対応する大まかな地域を選択する
5. 「次へ」で入力内容をServerへ確定保存し、保存成功後に次へ進む

### Step 3 — Rating Setup

1. 現在のメインキャラクターを選択する
2. SF6ランクを選択する
3. Masterの場合はMRを入力する
4. Product Specの換算ルールから初期仮レートを算出する
5. 初期仮レートと「最初の10セットはPlacementである」ことを表示する
6. ユーザーが内容を確認し、Server / Databaseのatomicかつidempotentな処理でオンボーディングを完了する
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
- Supabase Authを認証情報、Provider identity、Email verification stateのSource of Truthとし、ProfileへPasswordを保存しない
- MVPでは独自Account Linking UIを提供しない
- 認証済みユーザーだけがオンボーディングを完了できる

## Requirement 2 — Onboarding

- オンボーディングはAccount、SF6 Player Info、Rating Setupの3ステップで構成する
- 各ステップは「次へ」でServerへ確定保存し、保存成功後だけ次のステップへ進む
- 「次へ」前の入力途中値はClient stateで保持できるが、復元可能性を保証するSource of Truthにはしない
- 途中離脱後は最初の未完了ステップから再開できる
- 全必須項目が揃うまでオンボーディング完了扱いにしない
- オンボーディング未完了ユーザーはマッチングへ参加できない
- 完了時にProfile公開、初期仮レート、Placement状態、matching eligibilityをatomicかつidempotentなServer / Database処理で作成する

## Requirement 3 — Username

- SF6-Ratingユーザー名を必須とする
- ユーザー名は3〜20文字とする
- 日本語を含むUnicodeの文字・数字と`_`、`-`を許可する
- 表示値とは別にUnicode normalizationとcase-insensitive normalizationを適用した比較値を持ち、その値を一意にする
- MVPの比較値はtrimした表示値へ`NFKC`とUnicode default case foldingを適用する
- OAuth表示名を初期候補として利用できる
- 初期候補が既に使用中の場合は別のユーザー名を求める
- Ownerはユーザー名を変更できる
- ユーザー名変更は前回変更の確定時刻から30日に1回までとする
- オンボーディング完了前の修正は30日変更クールダウンへ数えない
- 変更してもAccount、Rating、Match、Rating Historyの紐付けは維持する
- Profile URLと永続参照にはUsernameではなくimmutable Public User IDを使用する

## Requirement 4 — SF6 Player Identity

- SF6プレイヤーネームを必須とする
- SF6プレイヤーネームはゲーム内で人間が検索しやすい表示名として保持し、重複を許可する
- SF6プレイヤーネームには30日変更制限を設けない
- SF6ユーザーコードを必須とする
- SF6ユーザーコードはcanonical SF6 identityとする
- SF6ユーザーコードは正規化後のASCII 10桁数字として検証する
- 1アカウントが保持できる有効なSF6ユーザーコードは1つとする
- 同じ正規化済みSF6ユーザーコードを複数アカウントへ同時登録できない
- OwnerはSF6ユーザーコードを変更できる
- ユーザーコード変更は前回変更の確定時刻から30日に1回までとする
- Public ProfileではSF6プレイヤーネームとSF6ユーザーコードを公開しない
- Active Match Roomでは現在の対戦相手にSF6プレイヤーネームとSF6ユーザーコードを表示する
- Owner / Adminには既存の権限境界どおり両方を表示する
- `matched | room_setup | reporting | disputed`のActive Match中はSF6プレイヤーネームとSF6ユーザーコードを変更できない
- MVPではSF6ユーザーコードの厳格な所有確認を必須にしない
- 重複やなりすましの問題はAdminが調査・修正できる余地を残す

## Requirement 5 — Region

- 国はISO 3166-1 alpha-2 country codeとして登録する
- 大まかな地域はstable codeを持つ管理master dataから登録し、自由入力を許可しない
- 国は公開プロフィールに表示する
- 大まかな地域は公開プロフィールに表示せず、マッチング内部で利用する
- 日本の初期区分は北海道、東北、関東、中部、関西、中国・四国、九州・沖縄とする
- Country / Broad Region masterは将来追加、名称変更、廃止でき、既存参照用codeを表示名変更で変えない
- 地域更新後のマッチングへの適用方法はMatchmaking Feature Specで定義する

## Requirement 6 — Initial Rating Inputs

- 現在のメインキャラクターとSF6ランクを登録する
- Masterの場合はMRを登録する
- MRは自己申告とし、versioned / configurableなsanity validation rangeを適用する
- MVP初期rangeは1〜5000（inclusive）とし、範囲外は保存を拒否する
- 初期仮レートはProduct Specに定義されたRank / MR換算ルールで算出する
- MasterのStarting RatingはPlacement Specどおり1800〜2200へclampする
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
- upload inputはJPEG、PNG、WebPの静止画だけを許可する
- SVG、animated GIF、その他のanimated imageはMVPで許可しない
- upload上限は5 MBとする
- Contentを検証し、metadataを除去してWeb表示向けの正方形crop / resizeを行う

## Requirement 8 — Public Profile

- オンボーディング完了後のプロフィールは常に公開する
- MVPではプロフィールの非公開設定を提供しない
- 基本公開項目はユーザー名、アイコン、国、現在レート、Placement状態とする
- Placement中はその状態を示し、ランキング対象外であることを明確にする
- 自己紹介文を提供しない
- SF6プレイヤーネーム、SF6ユーザーコード、詳細地域、Email、OAuth認証情報、運営情報を公開プロフィールに表示しない
- Main Character、SF6 Rank、MRをMVPの通常公開プロフィールに表示しない
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
- Active Match、unresolved Result、Disputeがある場合は削除を即時実行せず、削除要求をpendingとして保持する
- deletion pending中は新しいMatchmakingを許可せず、既存Match / Result / Disputeの解消に必要な操作だけを許可する
- blocking state解消後に個人情報を匿名化し、Supabase Auth accountを削除する
- 削除済みSF6ユーザーコードは自動的に再利用可能にせず、Adminの明示的なreclaim / releaseだけを許可する
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
8. OAuth表示名はSF6-Ratingユーザー名の初期候補にできる。SF6 Player NameとUsernameは別の情報として管理する。
9. 1 SF6ユーザーコードは1 SF6-Ratingアカウントにのみ紐付ける。
10. 1アカウントが保持できる有効なSF6ユーザーコードは1つとする。
11. SF6ユーザーコードは30日に1回まで変更できる。
12. 国は公開し、大まかな地域は非公開でマッチング内部にのみ利用する。
13. メインキャラクター、Rank、MRは初回仮レート算出にのみ使用する。
14. オンボーディング完了後のメインキャラクター、Rank、MR変更はSF6-Ratingへ影響しない。
15. プロフィールアイコンはOAuth画像、デフォルト画像、本人アップロード画像のいずれかを使用できる。
16. MVPでは自己紹介文を提供しない。
17. プロフィールは常に公開し、非公開設定を提供しない。
18. SF6 Player Name、SF6 User Code、詳細地域、Email、認証情報、運営情報は公開しない。
19. Rating、Rating History、Placement、戦績はユーザーが直接編集できない。
20. アカウント削除後も過去MatchとRating Historyは匿名化して保持する。
21. ユーザー名およびユーザーコードの30日制限はそれぞれ独立して管理する。
22. 30日の起点は各変更がServerで正常に確定した時刻とする。
23. Usernameと正規化済みSF6 User CodeはそれぞれDatabase制約でも一意にする。
24. Profile URLと履歴の関連付けにはimmutable Public User IDを使用する。
25. SF6 Player Nameは重複可能で変更クールダウンを設けず、SF6 User Codeをcanonical identityとする。
26. Active Match中はSF6 Player NameとSF6 User Codeを変更できない。
27. CountryはISO code、Broad Regionは管理master dataとし、Countryだけを公開する。
28. Avatar uploadはJPEG / PNG / WebPの5 MB以下の静止画に限定する。
29. Active Match、unresolved Result、Disputeがある削除要求はpendingにし、解消後に匿名化とAuth削除を行う。
30. 削除済みSF6 User CodeはAdminの明示的なreclaim / releaseなしに再利用しない。

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

trimした表示値へ`NFKC`とUnicode default case foldingを適用した比較値で一意性を判定する。正規化後に同じ値となる大文字・小文字、全半角等の候補は競合として拒否する。Unicode confusableをすべて同一視する過度な変換は行わず、なりすましはAdmin moderationでも扱う。

## SF6 User Code Conflict

入力したSF6ユーザーコードが別アカウントへ登録済みの場合、保存を拒否する。厳格な所有確認はMVPでは行わないため、心当たりがない場合のAdmin問い合わせ導線を用意する。

## SF6 Identity Change During Active Match

`matched | room_setup | reporting | disputed`のMatchへ参加中は、対戦相手が参照するidentityを固定するためSF6 Player NameとSF6 User Codeの変更をServer側で拒否する。Matchが`completed | cancelled`になった後に再試行できる。

## Cooldown Boundary

30日経過判定はClient時刻ではなくServer時刻を使用する。ユーザー名とSF6ユーザーコードのクールダウンは独立して判定する。

## Rank and MR Inconsistency

Master以外でMRが入力された場合は保存を拒否する。MasterのMRが設定済みsanity range（MVP初期値1〜5000 inclusive）を満たさない場合は仮レートを確定しない。

## User Changes Rank after Onboarding

プロフィール表示用データは更新できるが、現在レート、過去の初期レート、Placement進行度は変更しない。レーティングが再計算されないことを保存前に明示する。

## Interrupted Onboarding

ブラウザ終了、通信切断、別端末への移動後も保存済みステップを復元する。未保存の入力が失われる可能性は明示し、完了済みステップを巻き戻さない。

## Concurrent Editing

複数タブ・端末から同時更新された場合、古い更新で新しい確定値を意図せず上書きしない。競合時は最新状態を再取得してユーザーへ案内する。

## Avatar Upload Failure

画像アップロード失敗時も既存アイコンを維持し、プロフィール全体を壊さない。再試行またはデフォルト画像への切替を可能にする。

## Account Deletion with Active Match

Active Match、unresolved Result、Disputeがある場合は削除要求をpendingとして保存し、新しいMatchmakingを禁止する。既存案件の解消に必要な操作は許可し、blocking state解消後に匿名化とAuth削除をidempotentに再試行する。運営上の明示的なlegal / security holdがある場合だけAdminがfinalizationを保留できる。

## Duplicate Account Deletion Request

同じ削除要求が複数回送信されても、匿名化と認証削除を安全に一度だけ適用する。

## Deleted SF6 User Code Reuse

匿名化時に生のSF6 User Codeを公開・Profile領域から削除する一方、自動再利用を防ぐprivateなreclaim記録を保持する。Adminが監査対象のreclaim / releaseを明示的に実行するまで、同じ正規化済みcodeの登録を拒否する。

## Deleted Opponent in Match History

他ユーザーの対戦履歴では削除済みユーザーを匿名表示し、Match結果とRating Historyの数値は保持する。

## Region Option Changes

地域マスタの変更後も既存ユーザーを不正な状態にしない。廃止地域の再選択を促す場合でも、現在レートへ影響させない。

## Interrupted Step Before Next

「次へ」前の入力途中値はClient stateにだけ存在できるため、browser終了や別端末への移動で失われることがある。最後にServerへ確定保存されたstepを復元し、未保存値を保存済みとして表示しない。

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
- Active Match外では自分のSF6 Player Nameをクールダウンなしで変更できる
- 自分の非公開SF6情報と詳細地域を確認できる
- 自分のアカウント削除を開始・確定できる
- 自分の認証情報以外へアクセスできない

## Admin

- 運営上必要な範囲でProfile、SF6ユーザーコード、変更履歴、削除状態を確認できる
- 重複・なりすまし・入力ミス等の調査と修正を行える
- ユーザー本人では解決できないSF6ユーザーコード問題へ対応できる
- 削除済みSF6ユーザーコードを監査対象操作としてreclaim / releaseできる
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
- Immutable Public User ID（Phase 1の`profiles.id`）
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
- Processed Width / Height
- Processing Version
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
- SF6 User Code Reclaim Digest / State（private / Admin only）

## Region Master

- Country ISO 3166-1 alpha-2 Code
- Country Display Names（ja / en）
- Broad Region Stable Code
- Broad Region Display Names（ja / en）
- Country Relationship
- Active / Deprecated State
- Sort Order / Version Metadata

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
- ISO 3166-1 alpha-2 Country masterと管理されたBroad Region master
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
- Email、SF6プレイヤーネーム、SF6ユーザーコード、詳細地域、認証情報、運営情報を公開レスポンスへ含めない
- 変更系操作は毎回認証・所有権・入力値・変更期限をServer側で検証する
- ユーザー名とSF6ユーザーコードの一意性をDatabase制約でも保証する
- AvatarアップロードはOwnerだけに許可し、JPEG / PNG / WebP、5 MB上限、静止画、decode後の画像制約を検証する
- 任意HTMLや実行可能ファイルをAvatarとして受け付けない
- アカウント削除は再認証または同等の確認を要求する
- 分析イベントへEmail、SF6ユーザーコード、詳細地域等の不要な個人情報を送信しない
- 認証・登録・メール再送・プロフィール更新・Avatarアップロードへ適切なRate Limitを適用する
- 必要になった場合にSupabase Auth対応CAPTCHAを追加できる

## Privacy

- 公開プロフィールと非公開Profile情報を明確に分離する
- 国だけを公開し、大まかな地域はマッチング用途に限定する
- SF6プレイヤーネームとSF6ユーザーコードはOwner、現在のMatch相手、Admin等の必要な主体にのみ限定公開する
- アカウント削除時は個人情報を削除または匿名化し、履歴保持の目的を事前に説明する

## Reliability

- PostgreSQLをProfileとオンボーディング状態のSource of Truthとする
- オンボーディング最終確定、Profile公開、初期仮レート作成、Placement開始、matching eligibilityは部分成功を許可しない
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
- [ ] Supabase Authが認証・Provider identity・Email verification stateのSource of Truthである
- [ ] MVPに独自Account Linking UIが存在しない
- [ ] OAuthの表示名または画像がなくても登録を継続できる
- [ ] XログインがなくてもMVP必須要件を満たす

## Onboarding

- [ ] Account、SF6 Player Info、Rating Setupの3ステップが提供される
- [ ] 各ステップは「次へ」でServerへ確定保存され、成功後だけ次へ進む
- [ ] 「次へ」前の入力途中値をClient stateで保持できる
- [ ] 途中離脱後、次回ログイン時に未完了ステップから再開できる
- [ ] オンボーディング未完了ユーザーはマッチングへ参加できない
- [ ] 必須情報が欠けている場合は完了できない
- [ ] 完了時に初期仮レートと10セットのPlacementが作成される
- [ ] 最終確定の二重送信でProfile公開、初期レート、Placement、matching eligibilityが重複・部分作成されない
- [ ] 完了画面で初期仮レートとPlacementの説明を確認できる

## Username and SF6 Identity

- [ ] Usernameは正規化後3〜20文字の許可文字だけを受け付ける
- [ ] OAuth表示名をSF6-Ratingユーザー名の初期候補として利用できる
- [ ] SF6-Ratingユーザー名とSF6プレイヤーネームが別項目として保持される
- [ ] 同じ正規化済みユーザー名を複数アカウントが取得できない
- [ ] 大文字・小文字、互換等価、全半角の差だけのUsernameが競合する
- [ ] Profile URLと履歴参照がimmutable Public User IDを使用する
- [ ] ユーザー名変更後30日間は再変更できない
- [ ] 30日経過後は再変更できる
- [ ] SF6 Player Nameは重複可能で、Active Match外では30日制限なしに変更できる
- [ ] 1アカウントに有効なSF6ユーザーコードを1つだけ登録できる
- [ ] SF6 User Codeが正規化後10桁数字でない場合は保存できない
- [ ] 同じ正規化済みSF6ユーザーコードを複数アカウントへ登録できない
- [ ] SF6ユーザーコード変更後30日間は再変更できない
- [ ] Active Match中はSF6 Player NameとSF6 User Codeを変更できない
- [ ] Active Match Roomでは対戦相手がSF6 Player NameとSF6 User Codeを閲覧できる
- [ ] ユーザー名とユーザーコードのクールダウンが独立して動作する
- [ ] Client時刻を変更しても30日制限を回避できない

## Region and Rating Inputs

- [ ] 国と大まかな地域を登録できる
- [ ] CountryはISO country code、Broad Regionは管理masterの値だけを保存できる
- [ ] 日本で7つの初期Broad Regionを選択できる
- [ ] 公開プロフィールには国だけが表示される
- [ ] 大まかな地域は公開プロフィールの取得結果に含まれない
- [ ] メインキャラクターとRankを登録できる
- [ ] Masterの場合はMRを扱える
- [ ] Master MRのMVP初期sanity rangeが1〜5000 inclusiveである
- [ ] Product Specのルールに基づく初期仮レートが算出される
- [ ] 登録後にメインキャラクター、Rank、MRを変更しても現在レート、初期レートSnapshot、Placement進行度が変化しない

## Avatar and Public Profile

- [ ] OAuthアイコンを初期値として利用できる
- [ ] OAuthアイコンがない場合はデフォルトアイコンが表示される
- [ ] Ownerが許可された画像をアップロードしてAvatarを変更できる
- [ ] JPEG / PNG / WebPの5 MB以下の静止画だけをAvatar uploadとして受け付ける
- [ ] SVG、animated GIF、その他のanimated imageを拒否する
- [ ] upload画像がWeb表示向けにcrop / resizeされる
- [ ] Avatar更新失敗時に既存Avatarが維持される
- [ ] Owner以外はAvatarを変更・削除できない
- [ ] 完了済みプロフィールが常に公開される
- [ ] MVPにプロフィール非公開設定が存在しない
- [ ] MVPに自己紹介文が存在しない
- [ ] 公開プロフィールにSF6 Player Name、SF6 User Code、詳細地域、Email、OAuth情報、運営情報が表示されない
- [ ] 公開プロフィールにMain Character、SF6 Rank、MRが表示されない
- [ ] Rating、Rating History、Placement、戦績をプロフィール編集から変更できない

## Account Deletion

- [ ] Ownerが自分のアカウント削除を開始できる
- [ ] 削除前に個人情報の削除・匿名化と履歴保持が説明される
- [ ] 削除確定に再認証または同等の確認が必要である
- [ ] 削除後はログイン、編集、マッチング参加ができない
- [ ] 削除後に個人プロフィール情報が公開されない
- [ ] Active Match、unresolved Result、Disputeがある削除要求はpendingになり即時匿名化されない
- [ ] pending中は新しいMatchmakingへ参加できず、既存案件解消に必要な操作を行える
- [ ] blocking state解消後に個人情報が匿名化され、Supabase Auth accountが削除される
- [ ] 過去MatchとRating Historyが匿名データとして保持される
- [ ] 削除直後のSF6 User Codeは自動再利用できず、Adminだけがreclaim / releaseできる
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

Phase 2の機能実装を停止するHuman Decisionは残っていない。判断根拠と実装Defaultは`docs/phase-2-account-onboarding-decisions.md`をSource of Truthとする。

## Closed by Phase 2 Decision

- Usernameの長さ、許可文字、一意性normalization、30日変更制限、永続URL key
- SF6 Player Name / SF6 User Codeの分離、重複、正規化、一意性、変更制限、公開範囲、Active Match gate
- Country / Broad Regionの入力方式、公開範囲、日本の初期区分、master更新可能性
- Avatarの対応形式、5 MB上限、静止画限定、crop / resize、Owner権限
- MVP認証方式、Email verification、Supabase AuthのSource of Truth、独自Account Linking UI非採用
- 各Onboarding stepの「次へ」保存と最終Completionのatomicity / idempotency
- Master MRの設定可能なvalidation rangeとMVP初期値1〜5000、Starting Rating 1800〜2200 clamp
- Public Profileの基本公開 / 非公開項目
- Active Match / unresolved Result / DisputeがあるAccount deletionのpending処理、匿名履歴保持、User Code reclaim、idempotency

## AI-owned Assumptions — Non-blocking

- Usernameの具体的なNFKC / Unicode case folding、grapheme count、最小reserved-word list
- SF6 Player Nameの初期長1〜32 grapheme clustersとcontrol / format文字拒否
- 全ISO country masterと、未細分countryのcountry-wide Broad Region option
- Avatarの1:1 center crop、最大512×512、WebP再encode、metadata除去
- Supabase Auth project defaultを基準にしたpassword policy、verification期限、resend、reset UX
- Step 1はOAuth表示名だけをUsername候補にし、オンボーディング完了前の修正をcooldownへ数えない
- deletion grace periodは0日とし、blocker解消後にtrusted worker / actionが再試行する
- 削除済みUser Codeのprivate keyed digest ledger、削除後Usernameの再利用許可
- Country / Broad Region変更にPhase 2 cooldownを設けず、待機中の反映をPhase 3で定義する

## Deferred — Non-blocking / Owning Feature

- 公開Match Historyの具体項目と初期件数: Public Profile / Phase 6
- 地域変更がWaiting中のcandidate / snapshotへ与える影響: Matchmaking / Phase 3
- 不適切Username / Avatarの通報・削除運用: Admin / Dispute / Phase 8
- CAPTCHAと具体的Rate Limit: Hardening / Phase 9（abuseが先に顕在化した場合は前倒し）
- X login、SF6 User Code所有確認、OAuth画像再同期: Post-MVP
- 法令・規約による追加retention / legal hold: launch前の運用・法務確認

## Blocking Questions

None.
