# HTTP And Auth Checks

## Goal

browser の前に、HTTP 単位で「未認証ならどうなるか」「認証を付けるとどうなるか」を確定する。

## 1. Pick A Small Endpoint

まずは副作用のない軽い endpoint を使う。

例:

- `GET /g/dxkp/api/v1/workspaces/<workspace_id>/default_colors`
- `GET /g/dxkp/api/v1/workspaces/<workspace_id>/me`

ポイント:

- 認証が必要
- workspace 文脈を通る
- 書き込みがない

## 2. Unauth Baseline

最初に no auth で叩く。

```bash
curl -i -s \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

期待:

- `401` または認証切れに相当する応答

ここで `500` なら、アプリ初期化や routing の問題を先に疑う。

## 3. Auth Source

browser session があるなら、まず既存 session を使う。
`http://localhost/...` を開いている tab の cookie や token を source にする。

最低限確認したいのは:

- token が現在の localhost session と対応しているか
- 想定ユーザー種別か

## 4. Auth Request

```bash
curl -i -s \
  -H "Authorization: Bearer <token>" \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

ここで確認する:

- `401` から期待 status に変わるか
- `403` なら認可や IP 制限か
- `500` なら auth 後の下流失敗か

## 5. Auth Initialization Failures

ログに次が出ていたら、その server の auth は信用しない。

- JWKS 取得失敗
- issuer mismatch
- audience mismatch
- decrypt / cipher key error

その場合は、コードの挙動確認に進む前に `.env.local` と再起動を見直す。

## 6. Prefer curl Over Browser

browser E2E は最後に回す。

先に curl で次を固定する:

- endpoint
- header
- token source
- expected status

browser は、その再現が UI からも起きることの確認に使う。

## 7. Report

結果報告には次を含める。

- endpoint
- unauth status
- auth status
- token source
- 関連ログ 1-3 行
