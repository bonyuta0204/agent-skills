---
name: github-create-pr
description: GitHub の Pull Request をレビューア向け説明で作成・更新するスキル。PR 本文やタイトルの新規作成・改善・更新を求められたときに使い、AGENTS.md / CLAUDE.md の repo 固有ルールや PR template がある場合はそれを優先する。
---

# GitHub Create PR

## Overview

GitHub の PR を、実装者メモではなく初見のレビューアが判断しやすい説明として整える skill です。

この skill は次の両方で使う。

- 新規 PR を作成するとき
- 既存 PR のタイトル、本文、milestone、draft 状態を更新するとき

新規作成と更新で workflow を分ける前に、まず共通 preflight を通す。

## When To Use

- 現在の branch から新規 PR を作成したい
- 既存 PR の本文やタイトルを repo ルールに合わせて更新したい
- milestone や related issue / spec / related PR を含めて PR を整えたい
- kpiee 系 repo の PR template と Danger ルールに合わせたい

## Core Principles

- repo 固有ルールを本文より先に解決する
- create / update の mode を最初に確定する
- create / update どちらでも共通 preflight を必ず通す
- update では既存の人手追記を消さず、必要箇所だけ差分更新する
- base branch、milestone、draft 判定は本文生成より前に決める

## Workflow

### 0. Determine Mode

- PR URL や PR 番号が与えられていれば `update`
- 指定がなくても `gh pr view --head <current-branch>` で既存 PR が見つかれば `update`
- 既存 PR が見つからなければ `create`

同じ head branch で既存 PR があるのに新規作成へ進まない。

### 1. Common Preflight

PR を作る前、または更新する前に、現在の workspace で次を確認する。

- `AGENTS.md`
- `CLAUDE.md` があれば読む
- PR template は次の順で探索する
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `.github/PULL_REQUEST_TEMPLATE/*.md`
  - `PULL_REQUEST_TEMPLATE.md`
  - `docs/PULL_REQUEST_TEMPLATE/*.md`

`dx-kpiee` のように `.github` 直下ではなく `docs/PULL_REQUEST_TEMPLATE/devin_pr_template.md` を official template として `AGENTS.md` から参照している repo もある。`AGENTS.md` / `CLAUDE.md` に template の参照先が明記されている場合は、その指示を最優先する。

ここで少なくとも次を確定する。

- 現在の branch 名
- branch 名に含まれる開発 ID
- 想定 base branch
- 既存 PR の有無
- milestone 必須かどうか
- draft にすべきかどうか
- issue / spec / design doc / related PR の必須度

branch 名、commit message、milestone、PR 必須項目は repo ごとに違う。一般論で埋めない。

### 2. Reviewer Context

次を実コード・差分・テスト・既存 PR 本文から確認する。

- 何が起きていたか
- なぜ起きていたか
- 何をどう直したか
- どこまで影響しうるか
- 何を確認済みで、何が未確認か

説明の主語は、まず UI 操作や API の結果に置く。payload 名や内部メソッド名から書き始めない。

悪い例:

- `item: 'calendar' と value を持つ payload で 500`

良い例:

- `IF文で日時型カラムに対して「2025/06/05 00:00:00 より後」を設定して保存すると、POST /cleansing_tasks が 500 を返して登録できない`

### 3. Root Cause

原因欄では、次の対応がレビューアに見えるように書く。

- 入力の実体
- backend / frontend の前提
- どこでズレたか
- 何が壊れたか

`from/to が前提` のような内部用語だけで終わらせない。必要なら最小の request 例を添える。

例:

- 単一比較は `when_value.value`
- 期間比較は `when_value.from / when_value.to`
- 今回は前者の request なのに、前処理が後者前提で `from/to` を触って 500

### 4. Fix Explanation

解消方針は抽象論で終わらせず、今回の変更で受けられるようになった入力例を短く添える。

特に API shape や条件分岐が論点のときは、今回の論点に必要な範囲だけ JSON を載せる。
大きい request 全体は貼らず、`conditions[]` など関係部分だけ抜粋する。

### 5. Verification

動作確認欄は次の順で書く。

- 動作確認観点
- 自動確認の結果
- 自動確認未実施の理由
- 手動確認 TODO

手動確認を他の人が行う想定なら、TODO として残す。
UI 改修では、スクリーンショットや動画の添付を TODO ではなく必須証跡として扱う repo もある。repo ルールがあればそちらを優先する。

### 6. Impact Investigation

影響範囲調査では、調査コマンドだけで終わらせない。
最低限、次の 3 点を入れる。

- 調査方法
- 調査結果
- 結論

レビューアが知りたいのは「どこに影響しうるか」と「結果として問題があるのかないのか」。
変更が直接箇所をまたぐ場合は、どこまで見て、何が問題なかったかを書く。

### 7. Similar Defect Investigation

類似欠陥調査では、次を短く書く。

- 何を横断して見たか
- 同種の不整合があったか
- 今回追加した再発防止がどこを守るか

### 8. Keep It Tight

本文は具体的に書くが、長くしすぎない。

- まず現象
- 次に原因
- 次に修正内容
- 最後に確認範囲

この順で、1 段落 1 メッセージを意識する。

### 9. Create Flow

`mode=create` のときは次の順で進める。

1. current branch から開発 ID を確認する
2. 想定 base branch を repo ルールと現在の運用から決める
3. 同じ head branch の既存 PR が無いことを確認する
4. draft にすべきかを決める
5. milestone を先に決める
6. PR title と body を template に合わせて作る
7. `gh pr create` で base, title, body, draft を反映する
8. milestone が CLI 引数で付けられない場合は直後に `gh pr edit` で設定する

### 10. Update Flow

`mode=update` のときは、更新前に既存 PR の状態を読む。

- title
- body
- base branch
- milestone
- draft / ready 状態
- linked issue
- related PR

update では本文の全面再生成を既定にしない。

- 既存 section が template と整合しているなら残す
- 人手で追加された証跡、補足、関連リンクは削らない
- 不足 section の補完、古い説明の差し替え、milestone/title の修正を優先する
- 既存本文を壊しそうなら、どこを残してどこを更新するか明示してから編集する

### 11. Milestone and Base Branch Rules

特に kpiee 系 repo では次を先に確認する。

- PR タイトルや label に `WIP` を含めない
- milestone が必須なら作成前に候補を決める
- 同じ開発 ID の既存 PR があれば milestone を合わせる
- branch 名に `sprintXX` が含まれるなら `release-sprintXX` を優先候補にする
- release 系 branch への向き先制約がある場合は、それに従う

判定できないときは、候補を 1 つに絞ったうえでユーザー確認に回す。

### 12. Multi-Repo Notes for kpiee Family

`dx-kpiee`、`atlas-kpiee`、`atlas-core` は template の置き場所や補足説明に差があっても、PR で要求される情報の芯はかなり共通している。次の扱いで吸収する。

- まず実 repo の `AGENTS.md` / `CLAUDE.md` / template を source of truth とする
- bug fix なら `事象`、`原因`、`解消方針`、`影響範囲調査`、`類似欠陥調査` を重視する
- UI 改修なら証跡を必須として扱う
- non-default branch 運用では `Closes #...` だけに依存せず、本文に `関連Issue` を明記する
- 複数 repo をまたぐ変更では `関連PR` を積極的に埋める
- データコネクタ系など multi-repo の変更では、どの repo が何を担当するかを短く書く

## Operating Rules

- create / update のどちらでも、先に mode と preflight を確定してから本文を書く
- repo の official template があれば、その見出しと必須項目を優先する
- milestone 必須 repo では、本文より milestone を先に解決する
- base branch が曖昧な repo では、慣例で決め打ちしない
- update のときは既存 PR の手動追記を消さない
- 同一 branch で重複 PR を作らない

## Writing Rules

- PR は「変更を知っている本人」ではなく「初見のレビューア」に向けて書く
- payload 名や内部メソッド名を出すときは、その前に現象や責務を説明する
- 具体例は歓迎だが、論点に関係ない詳細は削る
- 未確認事項は曖昧にぼかさず、未実施として書く
- 既存 PR 更新では、元の情報を残したまま改善する
- repo の PR template がある場合は、その見出しと必須項目を優先する

## Output Checklist

PR を作る前に、次を満たしているか確認する。

- create / update の mode が確定している
- current branch と開発 ID を確認している
- タイトルが repo ルールに従っている
- base branch が repo ルールに合っている
- 既存 PR の重複作成を避けている
- milestone が必要なら設定している
- `WIP` がタイトルや label に入っていない
- issue / spec / related PR へのリンクがある
- 事象が UI 操作または API 結果として読める
- 原因が入力と内部前提のズレとして説明されている
- 解消方針に短い具体例がある
- 動作確認に自動確認と手動確認 TODO が分かれている
- 影響範囲調査に方法・結果・結論がある
- 類似欠陥調査に探し方がある
- update のときは既存の手動追記を不必要に消していない
