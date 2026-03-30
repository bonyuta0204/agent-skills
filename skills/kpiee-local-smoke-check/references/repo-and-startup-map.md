# Repo And Startup Map

## Goal

最初に「どの repo が何の役割を持ち、どこから何を起動するか」を固定する。
ここを曖昧にすると、差分確認のつもりで別 repo の常駐 process を見続ける。

## Repo Roles

### `ghq` 側 repo

通常はこちらがローカル開発の正本。

主な役割:

- 長時間起動している server
- browser session
- 既存の `.env.local`
- 日常的な localhost 動作確認

### review worktree

主な役割:

- PR 差分の確認
- review 対象コードの局所起動
- `ghq` 側と切り分けての比較

原則:

- browser session や常駐 server の母体は `ghq` 側に残りやすい
- review worktree で確認したいなら、その service を本当に worktree から起動し直す

## Repo Discovery

repo path は決め打ちしない。

```bash
ghq list -p | rg '/(dx-kpiee|zelda-kpiee|atlas-kpiee)$'
```

必要なら review worktree も確認する。

```bash
find ~/.codex -maxdepth 3 -type d | rg '/(dx-kpiee|zelda-kpiee|atlas-kpiee)$'
```

## Common Directories

### `dx-kpiee`

- frontend: `frontend/kpiee/`
- Go backend: `backend/go/`
- Rails backend: `backend/rails/`

### `zelda-kpiee`

- Rails app root: repo root または `backend/rails/` ではなく、repo 構成を見て合わせる
- schema / user / workspace 系の確認元

## Startup Commands

### All services

```bash
pnpm dev
```

### `dx-kpiee` frontend only

```bash
pnpm dev --filter frontend-kpiee
```

### `dx-kpiee` Go API only

```bash
cd backend/go
make dev/api
```

### `dx-kpiee` Go all services

```bash
cd backend/go
make dev
```

### `dx-kpiee` Rails

```bash
cd backend/rails
make dev
```

### Mixed startup

review worktree の Go API だけ差し替えたい、のような場面では「必要な service だけ worktree 側で起動し、他は `ghq` 側のまま」にする。
ただし、そのときは port ownership を必ず確認する。

## Typical Ports

まずは実測を優先するが、確認対象として意識しておく port は次の通り。

- localhost frontend
- Go API
- Rails API
- debug port

固定値だと決めつけず、listen 中の process を実測する。

## `.env.local`

review worktree の挙動だけ変なら、まず `ghq` 側と差分を見る。

```bash
diff -u \
  /path/to/ghq/dx-kpiee/backend/go/.env.local \
  /path/to/review-worktree/backend/go/.env.local
```

特に疑う項目:

- Cognito / issuer / audience
- DB host / port
- 暗号化キー
- 外部 URL

`.env.local` は watch されないことがあるので、変更後は対象 server を再起動する。

## Exit Criteria

次の 4 つが言える状態になってから、HTTP 再現や UI 確認に進む。

- どの repo / worktree を使うか
- どの command で起動したか
- どの process が対象 port を持っているか
- `.env.local` が期待どおりか
