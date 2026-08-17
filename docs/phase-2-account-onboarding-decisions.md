# Phase 2 — Account & Onboarding Decision Record

Status: Accepted — Finalized for Implementation Planning
Decision date: 2026-08-15
Finalization audit: 2026-08-17
Scope: Phase 2 implementation contract; no feature code, migration, or Auth provider configuration is included

## 1. Decision

Phase 2のAccount / Profile / Onboardingを実装する前提として、以下を承認済みの契約とする。

### 1.1 Username and public identity

- UsernameはSF6-Rating独自の表示名とし、3〜20文字とする。
- 日本語を含むUnicodeの文字・数字と`_`、`-`を許可する。
- 表示値とは別にUnicode normalizationとcase-insensitive normalizationを適用した比較値を持ち、その値を一意にする。
- Profile URL、Match、Rating History等の永続参照には変更可能なUsernameを使わず、immutable Public User IDを使う。Phase 1の`profiles.id`をPublic User IDとして扱う。
- Usernameは前回の確定変更から30日に1回変更できる。初回オンボーディング完了前の修正は変更クールダウンへ数えない。

### 1.2 SF6 identity

- SF6 Player NameとSF6 User Codeを別フィールドとして保持する。
- SF6 Player Nameはゲーム内検索用の表示名であり、重複を許可し、30日変更制限を設けない。
- SF6 User Codeはcanonical SF6 identityとし、区切り文字等を除去してASCIIの10桁数字へ正規化・検証する。
- 正規化済みSF6 User Codeを一意にし、1 SF6-Rating accountにつき有効なUser Codeを1つだけ保持する。
- SF6 User Codeは前回の確定変更から30日に1回変更できる。
- Public ProfileではSF6 Player NameとSF6 User Codeを公開しない。Active Match Roomでは対戦相手に両方を表示し、Owner / Adminにも既存の権限境界どおり表示する。
- `matched | room_setup | reporting | disputed`のActive Match中はSF6 Player NameとSF6 User Codeを変更できない。

### 1.3 Region

- CountryはISO 3166-1 alpha-2 country codeとして保持する。
- Broad Regionは安定した内部codeと表示名を持つ管理master dataから選択し、自由入力を許可しない。
- Countryだけを公開し、Broad Regionは非公開でMatchmaking内部に利用する。
- 日本の初期Broad Regionは北海道、東北、関東、中部、関西、中国・四国、九州・沖縄の7区分とする。
- Country / Broad Region masterは追加、名称変更、廃止をmigrationまたは同等の管理された更新で行える構造にする。履歴参照用codeを表示名変更で変えない。

### 1.4 Avatar

- OwnerだけがAvatarをupload / change / deleteできる。
- Upload inputはJPEG、PNG、WebPに限定し、SVG、animated GIFその他のanimated imageはMVPで受け付けない。
- Upload上限は5 MBとする。
- 保存・配信前にContentを検証し、Web表示向けの正方形crop / resizeを行う。

### 1.5 Authentication

- MVPの認証方法はGoogle、Discord、Email / Passwordとする。
- Email / PasswordはEmail verificationを必須とする。
- Supabase Authを認証情報、provider identity、verification stateのSource of Truthとし、Passwordをapplication tablesへ保存しない。
- MVPでは独自Account Linking UIを作らない。

### 1.6 Account deletion

- Active Match、unresolved Result、またはDisputeがある場合は即時削除せず、削除要求をpendingとして保持する。
- pending中は新しいMatchmakingを開始させず、既存Match / Result / Disputeの解消に必要な操作だけを許可する。
- blocking state解消後に個人情報を匿名化し、Supabase Auth accountを削除する。
- Match / Rating Historyはimmutable Public User IDから切り離さず、公開表示を匿名化して保持する。
- 削除したSF6 User Codeは直後に自動再利用可能にしない。必要なreclaim / releaseはAdminの明示的な監査対象操作とする。
- 削除要求、匿名化、Auth削除、再試行を含む処理はidempotentにする。

### 1.7 Master MR and Starting Rating

- Master MRは自己申告とする。
- sanity validation rangeはversioned / configurableとし、MVP初期値を1〜5000（inclusive）とする。範囲外はWarningだけで通さずvalidation errorとする。
- Starting RatingはPlacement Specの式を使い、1800〜2200へclampする。

### 1.8 Onboarding persistence

- OnboardingはAccount、SF6 Player Info、Rating Setupの3 stepとする。
- 各stepは「次へ」でServerへ確定保存し、保存成功後だけ次stepへ進む。
- 「次へ」前の入力途中値はClient stateで保持できるが、復元可能性を保証するSource of Truthにはしない。
- 最終CompletionはServer / Database側でatomicかつidempotentに行い、Profile公開、Starting Rating、Placement開始、matching eligibilityの部分成功を許可しない。

### 1.9 Public Profile baseline

- MVPの基本公開項目はUsername、Avatar、Country、Current Rating、Placement状態とする。
- Email、Broad Region、SF6 Player Name、SF6 User Codeを公開しない。
- Main Character、SF6 Rank、MRもMVPの通常Public Profileでは公開しない。
- 公開取得経路はprivate / limited fieldsを列単位で除外し、Client側の非表示だけへ依存しない。

## 2. Context

Phase 1は後続Featureのためのnullable schema、RLS、public/private projection、transaction/idempotency基盤までを実装した。Phase 2着手前に、正規化、一意性、公開範囲、削除、master data、upload制約、MR入力範囲、onboarding保存境界を確定し、Phase 1の意図的な保留を実装可能な契約へ変える必要があった。

## 3. Options considered

### Mutable Usernameを永続keyにする案

却下。変更時のlink切れ、履歴誤接続、名前再利用による混同が生じるため、immutable Public User IDを採用する。

### SF6 Player Nameをcanonical identityにする案

却下。重複・変更があり得る検索用表示名であるため、10桁のSF6 User Codeをcanonical identityとする。

### Broad Regionの自由入力または公開

却下。Matchmakingの比較可能性とprivacyを損なうため、管理masterからの選択かつ非公開とする。

### Active dependencyを無視した即時物理削除

却下。Match / Result / Disputeの参照整合性と解決フローを破壊するため、pending deletionと匿名化を採用する。

### Client-only onboarding保存

却下。途中再開と最終確定の整合性を保証できないため、step確定値をServerへ保存する。

## 4. Decision reason

- immutable IDと正規化済み一意keyにより、表示名変更と履歴整合性を分離できる。
- public / private / active-opponentの公開範囲を明確にし、SF6 identityと地域情報の不要な露出を防げる。
- master data、MR range、画像加工値を変更可能にし、MVP後の調整を破壊的schema変更から分離できる。
- deletionとonboardingをatomic / idempotentなdomain actionとして扱い、再送、通信切断、並行操作に耐えられる。
- Supabase Authを認証Source of Truthに限定することで、独自認証・linkingの複雑性をMVPへ持ち込まない。

## 5. AI-owned assumptions

以下は承認済みProduct intentを変えず、設定または実装詳細としてPhase 2で採用できるDefaultである。検証結果により変更可能とする。

1. Usernameはtrim後の表示値を保持し、比較値は`NFKC`後にUnicode default case foldingを適用する。許可categoryはUnicode Letter / Mark / Decimal Numberと`_`、`-`とし、空白、control、format、emoji、その他の記号は許可しない。長さは正規化後のUnicode grapheme clusterで数える。
2. Usernameの予約語・禁止語は設定可能なcase-fold済みlistで拒否する。初期listはrouting / system roleと衝突する最小集合とし、一般的な不適切名はAdmin moderationで扱う。
3. SF6 Player Nameはtrimし、control / format文字を拒否する。初期長は1〜32 grapheme clustersの設定値とする。Player Nameはidentity検索用なのでcase normalizationによる一意性判定をしない。
4. SF6 User Codeの入力ではASCII / full-width digitsと一般的な区切り空白・hyphenを受け付け、NFKC後に区切りを除去して10桁ASCII数字へ変換する。それ以外の文字または10桁以外は拒否する。
5. ISO country masterはMVP開始時点のISO 3166-1 alpha-2一覧をversioned seedとして持つ。Broad Region未細分の国にはcountry-wideのmanaged optionを用意し、海外ユーザーの登録を妨げない。
6. Avatarはorientation補正とmetadata除去後、中央基準の1:1 crop、最大512×512、no-upscaleで処理し、WebPへ再encodeする。画質等は設定可能とする。decode後にも静止画であることを検証する。
7. Supabase Authのpassword policy、verification link期限、再送制限、provider側の同一Email挙動は、MVPではSupabaseの安全なproject設定を利用する。独自linkingは行わず、衝突時は汎用エラーと既存のsign-in / reset導線を提示する。
8. Step 1のUsername候補はOAuth display nameからのみ生成できる。Step 2より前にSF6 Player Nameが未入力のため、MVPではSF6 Player Nameからの自動候補生成を必須にしない。オンボーディング完了前は保存済みstepへ戻って修正できる。
9. Account deletionには任意のgrace periodを設けない。blocking state解消後に安全なworker / trusted actionがfinalizationを再試行する。生のSF6 User Codeは匿名化時に削除し、自動再利用防止にはprivateなkeyed digestのreclaim ledgerを用いる。
10. 削除後のUsernameは匿名化完了後に再利用可能とする。過去履歴とURLはimmutable Public User IDにより旧所有者へ誤接続しない。
11. Country / Broad Region変更自体にMVPのcooldownは設けない。待機中の変更反映とsnapshot整合性はPhase 3で扱い、Active Matchの既存snapshotを書き換えない。

## 6. Remaining question classification

### Blocking Human Decision

なし。Phase 2の機能実装開始を止めるProduct / Architecture / UX Decisionは残っていない。

Google / Discord credentials、redirect URL、Email delivery等のenvironment configurationは統合検証前に必要だが、未解決DecisionではなくHuman Action Pointである。本Decision作業では設定変更を行わない。

### Non-blocking AI-owned Assumption

§5の11項目を実装defaultとして扱う。Unicode data / image processing libraryのversion、pixel上限、password policy、application rate-limit値等は、実装時点のsupport / security検証に基づいて固定し、testsとimplementation evidenceへ記録する。Product intentを変えない範囲では追加Human Decisionを要求しない。

### Future / Out of Scope

- Waiting中のRegion変更反映とsnapshot整合性はPhase 3で扱う。
- Active Match Roomのidentity表示UIはPhase 4で扱い、Phase 2はread projectionと変更禁止gateを保証する。
- Public Match / Rating History、pagination、Username searchはPhase 6で扱う。
- Admin reclaim / moderation / legal-hold UIはPhase 8で扱い、Phase 2はprivate ledgerとAdmin-only server boundaryを用意する。
- Production rate-limit tuning、CAPTCHA、scheduled reconciliation、monitoring / alertingはPhase 9で扱う。
- Custom Account Linking UI、X login、公式SF6 identity verification、OAuth avatar継続同期、animated avatarはMVP対象外とする。

## 7. Expected impact

- Account / ProfileとPlacementのOpen Questionsを、Closed、AI-owned assumption、後続Phaseのquestionへ再分類できる。
- Phase 2はFeature code着手可能になる。
- Phase 1 schemaのnullable placeholderへPhase 2のvalidation、master、trusted actionsをforward migrationで追加する計画が立てられる。
- Public ProfileとActive Match Roomのprivacy contractが列単位で明確になる。

## 8. Files to update

- `docs/product-spec.md`
- `docs/architecture.md`
- `docs/features/account-profile.md`
- `docs/features/match-room.md`
- `docs/features/placement.md`
- `docs/features/public-profile.md`
- `docs/implementation-plan.md`
- `docs/tasks.md`
- `docs/phase-1-data-foundation.md`

## 9. Risks

- Unicodeの見た目が似た別code pointをすべて同一視することはできない。NFKC + case foldingとAdmin moderationを組み合わせ、過度なconfusable変換は行わない。
- User Code所有確認はMVPで行わないため、先取り・なりすましはAdmin問い合わせとreclaimで扱う。
- Account deletionの複数systemにまたがる処理は部分失敗し得る。状態machine、idempotency key、retry、監査記録を必須にする。
- Avatar decodeはresource exhaustionの入力になり得る。入力byte上限に加え、pixel / decode上限とserver-side re-encodeを実装時に設ける。
- Region master変更はMatchmakingの分布へ影響する。stable code、active flag、effective datesまたは同等のversioningを使う。

## 10. Review condition

次の場合に本Decisionを見直す。

- SF6 User Codeの公式形式または所有確認APIが変わる
- Username abuse / impersonationが運用上問題になる
- avatar storage / egressまたは画像処理負荷がMVP前提を超える
- Country / Broad RegionがMatchmaking品質を損なう
- 法令、規約、監査要件によりdeletion retentionを変更する必要がある
- Supabase Authのprovider linking仕様またはsecurity recommendationが変わる

## 11. Result

DecisionはFeature Specs、Architecture、Implementation Planへ反映済み。2026-08-17の最終監査で仕様間にPhase 2着手を妨げる矛盾がなく、Blocking Human Decisionが0件であることを確認した。詳細実装順と検証契約は`docs/phase-2-account-onboarding-implementation-plan.md`および`docs/phase-2-account-onboarding-tasks.md`をSource of Truthとする。

Phase 2の機能実装は未着手であり、migration、hosted Supabase、Auth provider、Production設定も変更していない。
