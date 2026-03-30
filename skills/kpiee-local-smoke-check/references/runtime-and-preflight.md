# Runtime And Preflight

## Goal

最初に「どのコードを、どの環境で、どの process が動かしているか」を固定する。
ここが曖昧なまま browser や E2E に進むと、review worktree の検証をしているつもりで `ghq` 側の常駐 process を見ている、という事故が起きやすい。

## 1. Repo Discovery

repo path は決め打ちしない。

```bash
ghq list -p | rg '/(dx-kpiee|zelda-kpiee|atlas-kpiee)$'
```

必要なら review worktree も列挙する。

```bash
find ~/.codex -maxdepth 3 -type d | rg '/(dx-kpiee|zelda-kpiee|atlas-kpiee)$'
```

## 2. Runtime Ownership

対象 port を listen している process を確認する。

```bash
lsof -nP -iTCP:8082 -sTCP:LISTEN
ps -o pid,ppid,command= -p <PID>
pwdx <PID>
```

見るポイント:

- 実行ファイルや `air` / `rails` / `node` の起動元 path
- review worktree なのか `ghq` repo なのか
- 同じ port を別 process が取り直していないか

## 3. `.env.local` Diff

review worktree だけ挙動が変なら、まず `ghq` 側との差分を見る。

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

## 4. Schema Drift

localhost 500 は、まず schema drift を疑う。
アプリのバグと決めつけない。

必要に応じて `ghq` 側 repo で schema を適用する。

```bash
cd /path/to/ghq/zelda-kpiee
bundle exec rake ridgepole:apply FORCE_DROP_TABLE=true
bundle exec rake account_record:ridgepole:apply_all FORCE_DROP_TABLE=true
```

`dx-kpiee` 側も schema 差分が疑わしいなら、repo の標準手順に従って同期する。

## 5. Local Logs

最初に見るログ:

- `backend/go/logging.log`
- `backend/rails/log/logging.log`

例:

```bash
tail -f backend/go/logging.log | jq -r .
tail -f backend/rails/log/logging.log
```

見る観点:

- auth 初期化失敗
- DB 接続失敗
- 期待 endpoint の request が本当に来ているか
- middleware / usecase でどこまで進んでいるか

## 6. Exit Criteria

次の 4 つが言える状態になってから、個別の不具合調査に入る。

- どの repo / worktree を触っているか
- どの process が対象 port を持っているか
- `.env.local` が期待どおりか
- schema drift が主要因ではないか
