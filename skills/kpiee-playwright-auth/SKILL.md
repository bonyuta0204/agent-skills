---
name: kpiee-playwright-auth
description: dx-kpiee を Playwright で軽く調査・自動化するときの認証を安定化する skill。認証情報ファイルは持たず、人間が一度ログインして作った storageState を環境別・用途別に安全に再利用したいときに使う。
---

# KPIEE Playwright Auth

dx-kpiee を Playwright で触るときに、認証を「毎回の UI ログイン」ではなく再利用可能な `storageState` で扱う runbook。

## State Directory

```
STATE_DIR = ~/.local/state/kpiee-playwright-auth/
```

- 呼び出し元ディレクトリに依存しない固定パス
- なければ `mkdir -p` で作る
- repo 内 (`playwright/.auth/` 等) には置かない

### 命名規約

`{host}_{env}_{user-or-workspace}_{用途}.json`

- 軸の区切りは `_`、軸内のハイフンは `-`
- 用途がなければ `default`

例:

- `app-kpiee_prod_userA_default.json`
- `stg-kpiee_stg_ws72_investigation.json`

## Core Rules

- 認証 state の取得・更新は本作業と独立した step にする
- `storageState` は host / user / workspace / env ごとに分離する
- state が怪しいときは DOM 操作を続けず、先に auth を再生成する
- MFA や SSO を毎回 AI に突破させない
- 認証情報 (password, token) は AI に渡さない — ログイン結果の state だけを扱う
- 本番・共有環境の credential を `.env` や json に平文で置かない
- 常用ブラウザ profile を AI に共有しない
- local / stg / prod で同じ state file を使い回さない

## Auth Capture (人間ログイン → state 保存)

認証の基本フローは「headed browser で人間が一度ログインし、state だけ保存する」。

```typescript
import { chromium } from "playwright";

const browser = await chromium.launch({ headless: false });
const context = await browser.newContext();
const page = await context.newPage();

await page.goto("https://<target-host>/login");

// --- 人間がログインを完了するまで待つ ---
await page.pause();

// --- ログイン後に state を保存 ---
await context.storageState({
  path: `${process.env.HOME}/.local/state/kpiee-playwright-auth/<file-name>.json`,
});
await browser.close();
```

repo に既存の API ログイン (`/ajax/auth/sign_in` 等) があり、秘密情報の取り扱いルールに反しなければそちらを使ってもよい。
persistent browser profile は最後の手段。

## Workflow

### 1. state を確認する

`STATE_DIR` に対象環境の file があるか確認する。有効な state があればそのまま使う。

なければ repo 内の auth 導線 (`auth.setup`, ログイン API 等) を参考に、上記 Auth Capture で state を作る。

### 2. auth を検証する

state を使って対象 URL を開く前に確認する。

- ログイン画面へ redirect されていない
- workspace selector や report title など画面固有の要素が見える
- 401 / 403 / 302-to-login になっていない

失敗したら step 1 に戻って state を再生成する。

### 3. 本作業を実行する

認証確認後にだけ snapshot と UI 操作に進む。
1 context 1 task を基本とし、前回のタブ状態を引きずらない。

### 4. 失効時

途中で認証切れが起きたら:

1. login redirect / 401 / 403 を確認
2. state を再生成 (必要なら人間に再ログインしてもらう)
3. 新しい context で開き直す

無限リトライしない。

## dx-kpiee Specific Notes

`dx-kpiee` では `e2e-test/tests/auth.setup.ts` と `e2e-test/playwright.config.ts` に既存の auth パターンがある。
これらのファイルが見つからなければ、repo 構成が変わったと判断し headed login にフォールバックする。

注意点:

- `base URL` は origin にし、対象 URL は別で持つ
- state 生成と操作対象 URL を混ぜない
- `app.kpiee.com` 用 state を `localhost` や `stg` へ流用しない

## Reporting Contract

結果報告には最低限これを含める。

- どの host で使う認証か
- どの方法で state を作ったか
- 使った state file のパスと生成/更新時刻
- 認証確認に使った URL / 要素
- 失効時に再生成したかどうか
