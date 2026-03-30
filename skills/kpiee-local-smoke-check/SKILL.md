---
name: kpiee-local-smoke-check
description: kpiee のローカル動作確認や localhost E2E 切り分けを進める skill。`dx-kpiee` / `zelda-kpiee` の ghq 管理 repo と review worktree を使い分け、`.env.local` 差分、schema drift、認証、DB seed、IP 制限のどこで詰まっているかを短時間で切り分けたいときに使う。
---

# KPIEE Local Smoke Check

## Overview

この skill は、kpiee のローカル確認で「コードは直っているはずなのに localhost では再現しない / 500 になる / auth が怪しい / DB が空かもしれない」を順番に潰すためのものです。

特に次のような場面で使います。

- review worktree の Go / Rails 変更を localhost で E2E 確認したい
- `dx-kpiee` と `zelda-kpiee` のどちらが原因か切り分けたい
- `.env.local` 差分や JWKS 初期化失敗で auth が壊れていそう
- IP 制限や権限制御が DB seed 不足で見えていないか確かめたい

## First Rule

repo の役割を混ぜない。

- `ghq` 側 repo: 長時間起動しているローカル server、browser session、既存 `.env.local` の正本
- review worktree: 差分確認、修正、review 対象コードの起動

long-running process は `ghq` 側に残りやすいので、まずどの process がどの path から起動しているか確認する。

```bash
lsof -nP -iTCP:8082 -sTCP:LISTEN
ps -o pid,ppid,command= -p <PID>
```

## Repo Discovery

repo path は決め打ちせず `ghq` から確認する。

```bash
ghq list -p | rg '/(dx-kpiee|zelda-kpiee)$'
```

## Preflight

### 1. `.env.local` 差分

review worktree で auth や外部接続がだけ壊れるときは、まず `ghq` 側との差分を見る。

```bash
diff -u \
  /path/to/ghq/dx-kpiee/backend/go/.env.local \
  /path/to/review-worktree/backend/go/.env.local
```

特に見る項目:

- `COGNITO_USER_POOL_ID`
- `COGNITO_APP_CLIENT_ID`
- DB host / port
- `CIPHER_KEY`

`.env.local` は Air の watch 対象外になりやすい。変更後は server を明示的に再起動する。

### 2. zelda schema drift

localhost 画面が 500 のときは、まず zelda 側 schema を疑う。Rails / Go のバグと決めつけない。

`ghq` 側 `zelda-kpiee` で必要に応じて schema を合わせる。

```bash
bundle exec rake ridgepole:apply FORCE_DROP_TABLE=true
bundle exec rake account_record:ridgepole:apply_all FORCE_DROP_TABLE=true
```

### 3. auth 初期化

`backend/go/logging.log` に JWKS 取得失敗が出ていたら、その server では auth を信用しない。

見るべきログ例:

- `failed to create JWKS from resource at the given URL`
- Cognito / issuer mismatch

## Local Auth Check

browser session を使う。`http://localhost/dx/...` を開いている tab から `kptoken` cookie を取る。

最低限の確認:

1. unauth request が `401` になる
2. same endpoint に `Authorization: Bearer <kptoken>` を付けると `200` か期待どおりの制御になる

example:

```bash
curl -i -s \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors

curl -i -s \
  -H "Authorization: Bearer <kptoken>" \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

## IP Restriction Check

### daX user path

`zelda_kpiee_development` 側の seed を見てから判断する。空のままでは結論を出さない。

```sql
UPDATE workspaces SET dax_restriction_enabled = 1 WHERE id = 1;
DELETE FROM dax_whitelist_ips;
INSERT INTO dax_whitelist_ips (ip_address_range, created_at, updated_at)
VALUES ('10.0.0.1', NOW(), NOW());
```

### general user path

`permitted_ip_addresses` は kp account DB 側にある。`Exists` が false なら制限しない実装があり得るので、レコード有無を確認してから挙動を読む。

## E2E Pattern

IP 制限の再現は plain IP と `host:port` を並べて比較する。

```bash
curl -s -o /tmp/plain.out -w '%{http_code}\n' \
  -H "Authorization: Bearer <kptoken>" \
  -H 'X-Forwarded-For: 10.0.0.1' \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors

curl -s -o /tmp/port.out -w '%{http_code}\n' \
  -H "Authorization: Bearer <kptoken>" \
  -H 'X-Forwarded-For: 10.0.0.1:8080' \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

あわせて `backend/go/logging.log` を見る。

- request path
- status code
- invalid client IP
- user / workspace 解決失敗

## Debug Order

迷ったら次の順で潰す。

1. process が本当に狙った repo / worktree から起動しているか
2. `ghq` 側と review worktree の `.env.local` が一致しているか
3. localhost 500 が schema drift ではないか
4. unauth `401` と auth request の基本疎通
5. DB seed が空ではないか
6. 期待 endpoint に対して curl で最小再現
7. browser E2E は最後

## Report Format

結果報告では次を必ず含める。

- どの repo / worktree を起動したか
- 叩いた endpoint
- auth source (`kptoken`, no auth, etc.)
- 関連 DB seed 状態
- plain IP と `host:port` の HTTP status
- 決定打になったログ 1-3 行
