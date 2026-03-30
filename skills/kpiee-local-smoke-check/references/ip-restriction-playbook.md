# IP Restriction Playbook

## Goal

IP 制限の不具合を「ヘッダ解釈の問題」「DB seed 不足」「ユーザー種別の取り違え」に分解して見る。

## First Rule

IP 制限は DB レコードが空だと何も起きない実装がある。
seed を確認せずに「通った」「落ちた」を結論にしない。

## 1. Identify The Path

まず、どの経路の制御かを決める。

- daX user 向け whitelist
- general user 向け permitted IP

必要ならユーザー種別と workspace 文脈をログや DB で確認する。

## 2. Confirm Related Records

見るべきもの:

- workspace 側の制限有効フラグ
- daX whitelist の有無
- permitted IP の有無

`Exists == false` で制限しない実装は珍しくない。
空のままでは再現条件になっていない可能性がある。

## 3. Build A Minimal Comparison

plain IP と `host:port` を並べて同じ endpoint に流す。

```bash
curl -s -o /tmp/plain.out -w '%{http_code}\n' \
  -H "Authorization: Bearer <token>" \
  -H 'X-Forwarded-For: 10.0.0.1' \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors

curl -s -o /tmp/port.out -w '%{http_code}\n' \
  -H "Authorization: Bearer <token>" \
  -H 'X-Forwarded-For: 10.0.0.1:8080' \
  http://localhost:8082/g/dxkp/api/v1/workspaces/1/default_colors
```

この比較で見たいのは:

- plain IP は通るか
- `host:port` 付きでだけ落ちるか
- `X-Real-IP` でも同じか

## 4. Check Header Extraction

ログやコードで確認する観点:

- `X-Forwarded-For` のどの要素を使っているか
- `host:port` を剥がしているか
- IPv4 / IPv6 の両方を正規化しているか
- header が無いときに `RemoteAddr` fallback になるか

## 5. Check The Seed, Not Only The Code

ローカル DB が空だと、コードが正しくても制御は見えない。

最低限確認する:

- whitelist / permitted IP レコード件数
- 比較対象の IP 文字列
- workspace 側の有効化フラグ

## 6. Logs To Capture

決定打として使いやすいログ:

- client IP 抽出結果
- invalid client IP
- user / workspace 解決失敗
- IP 制限で forbidden を返した行

## 7. Report

報告には次を含める。

- 対象経路
- 関連レコードの有無
- plain IP の status
- `host:port` の status
- 使った header
- 決定打ログ
