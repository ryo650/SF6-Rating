# SF6-Rating

SF6-RatingのWebアプリケーションです。Phase 0では、Next.js App Router、ja/en、Supabase接続、テスト、CI、Vercel Previewのための基盤だけを提供します。

## Requirements

- Node.js 22 (see `.nvmrc`)
- npm 10+
- Docker-compatible runtime（Supabase local stackを使う場合のみ）

## Local setup

```sh
nvm use
npm ci
cp .env.example .env.local
npm run dev
```

`http://localhost:3000` は日本語の `/ja` へ移動します。英語は `/en` です。Supabaseを利用するコードを呼び出すには、`.env.local` にDashboardのProject URLとpublishable keyを設定してください。`service_role` keyはブラウザ公開変数へ設定しないでください。

## Quality checks

```sh
npm run verify
```

個別には `lint`、`format:check`、`typecheck`、`test`、`build` を実行できます。CIはpushとpull requestで同じ品質Gateを実行します。

## Supabase workspace

CLIはproject dependencyとして固定しています。

```sh
npm run supabase -- start
npm run supabase -- db reset --local
npm run supabase -- stop
```

Phase 0にはdomain migrationやseed dataはありません。Phase 1以降では `supabase/migrations/` にmigrationを追加し、まずlocal stackで検証してください。

Remote projectを操作するコマンドは明示的な確認後にだけ実行します。特に `db push --linked` や `db reset --linked` を通常のlocal workflowで使わないでください。初回linkにはDashboard URLのproject refが必要です。

```sh
npm run supabase -- login
npm run supabase -- link --project-ref <project-ref>
```

CLIのlogin token、link state、database passwordはcommitしません。

## Vercel Preview

VercelのProject Settingsで次をPreview/Productionそれぞれに設定します。

- `NEXT_PUBLIC_SUPABASE_URL`: 対象Supabase projectのURL
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: 対象projectのpublishable key

Framework PresetはNext.js、Install Commandは`npm ci`、Build Commandは`npm run build`です。Previewでproduction dataを暗黙に共有しない運用を推奨します。Auth providerをPhase 2で設定する際は、Supabaseのredirect allow listと各OAuth providerにVercel環境別callback URLを登録します。

秘密情報はVercel/Supabase Dashboardへ直接設定し、GitHub、`.env.example`、ドキュメントには記録しません。
