# Authenticated API Access

## Goal

認証付き API アクセスを毎回 ad-hoc に組み立てず、同じ順で最小再現を作る。

## Basic Policy

優先順位は次の通り。

1. unauth request で baseline を取る
2. browser session 由来の token / cookie を source にする
3. curl で同じ endpoint を最小再現する
4. browser E2E は最後に使う

## Pick A Small Endpoint

まずは副作用のない軽い endpoint を使う。

例:

- `GET /g/dxkp/api/v1/workspaces/<workspace_id>/default_colors`
- `GET /g/dxkp/api/v1/workspaces/<workspace_id>/me`

条件:

- 認証が必要
- workspace 文脈を通る
- 書き込みがない

## Unauth Baseline

最初に no auth で叩く。

```bash
curl -i -s \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

期待:

- `401` または認証切れ相当

ここで `500` なら auth の前に起動や初期化を疑う。

## Auth Sources

### Browser session

最優先。
すでに localhost にログインできている tab があれば、その session を source にする。

見るもの:

- cookie
- local storage / session storage の token

### Header token

Bearer token を直接付ける。

```bash
curl -i -s \
  -H "Authorization: Bearer <token>" \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

### Cookie replay

server が cookie auth 前提なら、browser session の cookie を再送する。

```bash
curl -i -s \
  -H 'Cookie: kptoken=<token>' \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

どちらが正しいかは endpoint と middleware の実装に合わせる。
迷ったら browser の実 request を見て揃える。

## Auth Initialization Failures

次が出ていたら、その server の auth は信用しない。

- JWKS 取得失敗
- issuer mismatch
- audience mismatch
- decrypt / cipher key error

その場合は、コードの挙動確認に進む前に `.env.local` と再起動を見直す。

## Minimal Comparison

auth source を決めたら、少なくとも次を比べる。

- no auth
- auth あり

必要ならさらに次を比べる。

- token header
- cookie replay

## Reporting Contract

報告には次を含める。

- endpoint
- no auth status
- auth あり status
- auth source
- token を header で使ったか cookie で使ったか
- 関連ログ 1-3 行
