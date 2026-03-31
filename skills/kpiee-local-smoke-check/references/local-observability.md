# Local Observability

## Goal

ローカル確認で「どの process が応答し、どの log を見ればよいか」を固定する。

## Process Ownership

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

## Main Logs

最初に見るログ:

- `backend/go/logging.log`
- `backend/rails/log/logging.log`

例:

```bash
tail -f backend/go/logging.log | jq -r .
tail -f backend/rails/log/logging.log
```

## What To Look For

### 起動・初期化

- auth 初期化失敗
- DB 接続失敗
- port bind 失敗

### request tracing

- 期待 endpoint の request が本当に来ているか
- status code
- middleware / usecase でどこまで進んでいるか

### app-specific hints

- workspace / user 解決失敗
- policy / IP restriction / validation error
- external dependency call failure

## Lightweight Checks

### Listen port

```bash
lsof -nP -iTCP -sTCP:LISTEN | rg 'node|air|rails|go'
```

### Health-like check

副作用のない endpoint を叩いて status を見る。

```bash
curl -i -s http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

### Process tree

```bash
ps -ef | rg 'air|rails|vite|node'
```

## When Browser Lies

browser で見えている画面と、実際に叩いている server が違うことがある。
その場合は browser を信じず、process ownership と curl の結果を信じる。

## Reporting Contract

報告には次を含める。

- target port
- process path
- どの log を見たか
- 決定打になった log line
