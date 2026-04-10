---
name: kpiee-playwright-auth
description: dx-kpiee を Playwright で軽く調査・自動化するときの認証を安定化する skill。認証情報ファイルは持たず、人間が一度ログインして作った storageState を環境別・用途別に安全に再利用したいときに使う。
---

# KPIEE Playwright Auth

## Overview

この skill は、dx-kpiee を Playwright で触るときに認証を「毎回の UI ログイン」ではなく、再利用可能な `storageState` 管理として扱うための runbook です。

特に次のケースで使います。

- 軽い調査や spot automation で、AI に認証済みブラウザを渡したい
- 毎回ログイン画面を踏む運用をやめたい
- `app.kpiee.com` / `it` / `stg` など環境ごとに state を分けたい
- 認証情報そのものは AI に持たせず、ログイン結果だけを再利用したい

## Core Rules

- 本作業の前に、認証 state の取得または更新を独立した step として扱う
- 既定では human-in-the-loop で一度ログインし、その結果を `storageState` として保存する
- repo に既存の auth bootstrap があるなら、それを流用する
- `storageState` は host / user / workspace / env ごとに分離する
- state が怪しいときは DOM 操作を続けず、先に auth を再生成する
- MFA や SSO を毎回 AI に突破させる設計にしない

## Secret Handling

認証情報ファイルは作らない。秘密情報は AI に渡さず、人間が一度ログインして `storageState` を作る。

推奨順:

1. headed browser を開く
2. 人間がログインを完了する
3. ログイン後の `storageState` だけを保存する
4. 以後の Playwright 操作はその state を再利用する

避けること:

- 本番や共有環境の認証情報を repo 配下の `.env` や json に平文で置く
- 常用ブラウザ profile を AI に共有する
- local / stg / prod で同じ state file を使い回す

## Default Workflow

### 1. 既存の auth 導線を探す

最初に repo 内で次を探す。

- `storageState`
- `auth.setup`
- `/ajax/auth/sign_in` のようなログイン API
- `playwright/.auth` のような既存保存先

既存実装があれば、それに寄せる。新しい UI ログイン手順を勝手に増やさない。

### 2. 認証方式を選ぶ

優先順は次の通り。

- 一度だけ headed で人間がログインし、`storageState` を保存する
- repo 既存の API ログインが安定していて、かつ秘密情報の取り扱いルールに反しないならそれを使う
- persistent browser profile は最後の手段

### 3. state file を分ける

少なくとも次の軸で分ける。

- host
- user
- workspace
- 用途

例:

- `playwright/.auth/app-kpiee-prod-userA.json`
- `playwright/.auth/stg-kpiee-ws72-investigation.json`

state は保存してよいが、credential の代替として扱わない。

### 4. 本作業前に auth を検証する

認証済み前提で対象 URL を開く前に、次を確認する。

- ログイン画面へ redirect されていない
- workspace selector や report title など、その画面固有の要素が見える
- 401 / 403 / 302-to-login になっていない

ここで失敗したら、先に state を更新する。

### 5. 本作業を実行する

認証確認後にだけ snapshot と UI 操作に進む。
調査・自動化は 1 context 1 task を基本とし、前回のタブ状態を引きずらない。

### 6. 失効時の扱いを固定する

途中で認証切れが起きたら次の順で戻す。

1. login redirect / 401 / 403 を確認
2. state を再生成する
3. 必要なら人間に再ログインしてもらう
4. 新しい context で開き直す

無限リトライしない。

## dx-kpiee Specific Notes

`dx-kpiee` では、まず `e2e-test/tests/auth.setup.ts` と `e2e-test/playwright.config.ts` を確認する。

この repo には次の既存パターンがある。

- `/ajax/auth/sign_in` を叩いて auth state を作る
- `playwright/.auth/user.json` に保存する
- その state を Playwright 側で再利用する

ただし軽い調査や AI automation では、credential を持たずに「人間が一度ログインして state だけ残す」運用を第一候補にする。

注意点:

- `base URL` は origin にし、対象 URL は別で持つ
- state 生成と操作対象 URL を混ぜない
- `app.kpiee.com` 用 state を `localhost` や `stg` へ流用しない
- state を更新した時刻と対象 host を分かるようにしておく

## Reporting Contract

結果報告には最低限これを含める。

- どの host で使う認証か
- どの方法で state を作ったか
- どの state file を使ったか
- 認証確認に使った URL / 要素
- 失効時に再生成したかどうか
