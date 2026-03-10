---
name: review-design-doc
description: GitHub PR 上の kpiee-designs 設計書をレビューする skill。kpiee-designs を dedicated worktree に pull して、文書品質レビューと設計妥当性レビューを分けて行い、必要に応じて関連実装や Notion / Figma を読み、日本語の inline review と総評を返すときに使う。
---

# Review Design Doc

kpiee-designs の設計書 PR をレビューする skill。

目的は、設計書を「実装メモ」ではなく、意図・仕組み・判断理由を共有できる文書として保つことです。

## いつ使うか

- `kpiee-designs` の PR URL / PR 番号を渡されて、設計書レビューを頼まれたとき
- 「設計書レビューして」「PR の設計書をチェックしてコメントして」と依頼されたとき
- GitHub 上にレビューコメントを書く前提で、template 準拠と内容品質を確認したいとき

## 基本方針

- まず repo ルールと template を確認する
- `kpiee-designs` 本体は current workspace ではなく dedicated worktree で開く
- レビューは「文書品質」と「設計妥当性」の 2 ステップに分ける
- PR の最新 head を必ず取り直してからレビューする
- changed files の判定で `git show --name-only` は使わない
- 関連実装や外部仕様は、設計妥当性の確認に必要な範囲だけ読む
- `dx-kpiee` や `zelda-kpiee` などの関連 repo を読む場合も、必要なら dedicated worktree を使う
- Notion / Figma / 関連 repo は必要時だけ開き、不要にコンテキストを増やさない
- レビューコメントは原則日本語で書く
- inline comment は「diff 上の changed line にだけ」付ける
- diff 上に乗らない指摘は summary comment に寄せる
- 新しい要求を足すのではなく、設計書として必要な説明の不足や矛盾を指摘する

## Workflow

### 1. 入力を確認する

- PR URL または PR 番号を確認する
- 対象 repo が `kpiee-designs` か確認する
- PR 番号だけが渡された場合は owner / repo を確認する
- local の `kpiee-designs` repo path を `ghq` で確認する

不足情報がある場合だけ確認する。scope が曖昧なら設計書レビューかどうかを明示的に確認する。

repo path の確認例:

```bash
ghq list -p | rg '/kpiee-designs$'
```

### 2. kpiee-designs の review worktree を準備する

- review は dedicated worktree で行う
- `kpiee-designs` の main repo 直下の current branch は触らない
- まず repo root で `git fetch origin` する
- review 用 path を決める
  - 例: `/tmp/kpiee-designs-pr-<PR番号>`
- 既存 worktree があれば、古い review 状態を引きずらないよう再作成または branch を作り直す

PR head を worktree に展開する例:

```bash
cd <kpiee-designs-repo>
git fetch origin pull/<PR番号>/head
git worktree add -B review-pr-<PR番号> /tmp/kpiee-designs-pr-<PR番号> FETCH_HEAD
```

`gh` を使う場合も、review の実作業は worktree 側で行う。primary checkout 上で `gh pr checkout` してそのまま進めない。

既存 worktree を再利用するなら、次の 2 点を満たすこと。

- PR の最新 head を fetch し直している
- review 用 branch / path が今回の PR に対応している

### 3. review worktree 上で PR metadata と review scope を取る

以降の確認は原則 review worktree 側で行う。

まず PR metadata を取る。

```bash
gh pr view <PR番号> --json url,title,baseRefName,headRefName,headRefOid,files
```

確認する項目:

- base branch
- head SHA (`headRefOid`)
- changed files 一覧
- 設計書以外に画像や template 関連ファイルが含まれているか

changed files の把握は次の優先順で行う。

1. `gh pr view --json files`
2. `gh pr diff --name-only <PR番号>`
3. `git diff --name-only origin/<baseRefName>...HEAD`

`git show --name-only` は最後の commit しか見えないため使わない。

### 4. repo 固有ルールと template を読む

最低限次を読む。

- review worktree 内の `AGENTS.md`
- review worktree 内の `CLAUDE.md` があればそれも読む
- `docs/onboarding/` 配下の対応 template

確認すること:

- 文書種別ごとの template
- file path / naming rule
- 必須 section
- 日本語/英語の運用

### 5. 補助コンテキストを必要最小限で集める

- review worktree 上の設計書本体を起点に、設計妥当性の確認に必要な情報だけ追加で読む
- まず PR 本文、`AGENTS.md`、設計書本文中の参照先から当たりを付ける
- Notion の要件定義書 / 仕様書や Figma が示されていることが多いが、常に読む前提にしない
- 仕様差分や画面要件の確認が必要なときだけ、該当 section や該当 frame に絞って読む
- 画像参照がある場合は `img/` などの関連 asset も含める

関連実装を読むルール:

- 設計妥当性の判断に必要なら、関連する実装 repo を読む
- 関連 repo も、可能なら main checkout ではなく dedicated worktree で読む
- 基本的には `develop` または `main` を最新化した状態で読む
- stale な local branch のまま根拠にしない

更新の目安:

```bash
git fetch origin
git switch develop && git pull --ff-only
# develop が無い repo は main を使う
```

関連 repo を worktree で読む例:

```bash
cd <related-repo>
git fetch origin
git worktree add -B review-read-<topic> /tmp/<repo>-review-<topic> origin/develop
# develop が無い repo は origin/main を使う
```

レビューのためのコードリーディングでは、既存の作業 branch や未コミット変更を抱えた checkout を根拠にしない。

`dx-kpiee` / `zelda-kpiee` の connector 設計では、必要に応じて `atlas-kpiee` と `atlas-core` も確認する。

- repo path は `ghq` で探す
- 必要なら `dx-kpiee` / `zelda-kpiee` / `atlas-kpiee` / `atlas-core` それぞれに review 用 worktree を切る
- connector 境界、共通基盤、schema / API 契約の置き場所を優先して読む
- 設計判断に関係しない広い探索はしない

例:

```bash
ghq list -p | rg '/(atlas-kpiee|atlas-core)$'
```

### 6. 2 ステップでレビューする

#### Step 1. 文書品質レビュー

書き方、文章構成、template 準拠、説明の分かりやすさを見る。ここではまず「文書として読めるか」を判定する。

次は MUST 観点で確認する。

- section structure, heading, numbering が template と一致しているか
- empty section や placeholder が残っていないか
- file placement / naming が正しいか
- image path が正しいか
- 画像ファイルが適切な配置にあるか
- コードを読まなくても目的と仕組みが理解できるか
- 背景、前提、非目的が言語化されているか
- 重要な判断に理由があるか
- failure / retry / re-execution 時の扱いが説明されているか

#### Step 2. 設計妥当性レビュー

関連する実装、仕様、必要な外部資料を読んだうえで、設計として成立しているかを見る。文書品質が通っていても、ここで設計の抜けや矛盾があれば別途指摘する。

確認観点:

- 既存仕様や関連実装と矛盾していないか
- 責務分割、境界、data flow、failure behavior が現実のシステム構造に照らして妥当か
- 既存の API / schema / event / transaction 境界と噛み合っているか
- 再実行、冪等性、 rollback / retry の扱いが既存の前提に沿っているか
- 必要な参照元を読まずに推測で評価していないか

#### 基本設計

- What / Why / Purpose が明確か
- 問題設定と背景が平易に説明されているか
- 実装詳細に寄りすぎていないか

#### 詳細設計

- `How` を、処理手順ではなく仕組み・責務境界・データの流れ・不変条件として説明しているか
- 特定の class 名、helper 名、変数名に説明が依存しすぎていないか
- 大きい code block や source dump が無いか
- snippet が必要な場合も、意図を補助する最小限に留まっているか

次の問いにコードを開かず答えられなければ、説明不足として戻す。

- 何の問題を解くのか
- 何が保証されるのか
- どこで責務が分かれるのか
- 失敗時と再実行時にどうなるのか

`skills/review-design-doc/references/detail-design-bad-good-samples.md` は、詳細設計が実装メモに崩れていないかを見る基準として必要時だけ読む。

### 7. 指摘を整理する

severity は次で分ける。

- MUST: template 違反、必須 section 欠落、内容の矛盾、コード依存の説明、大きすぎる code block
- SHOULD: 理由不足、境界説明不足、曖昧表現、読み手前提の飛躍
- QUESTION: 意図確認や前提確認が必要な箇所

コメント方針:

- concrete issue は inline comment を優先する
- PR 全体の評価、良い点、inline に載らない指摘は summary comment にまとめる
- レビューコメントは原則日本語で書く
- ユーザーが明示的に別言語を求めたときだけ、その言語に合わせる

summary comment では、次を分けて書く。

- 文書品質レビューでの総評
- 設計妥当性レビューでの総評
- 今回読んだ関連資料と、読んでいないもの

### 8. GitHub に inline review を投稿する

inline review を promised workflow にするので、ここは手順を固定する。

1. `gh pr view <PR番号> --json headRefOid` で `commit_id` を取る
2. `gh pr diff <PR番号> --patch` で、指摘したい file と line が diff 上の changed line か確認する
3. diff 上に存在する指摘だけを inline comment にする
4. payload を JSON file にして `gh api` で review を作成する

review payload の例:

```json
{
  "commit_id": "<HEAD_SHA>",
  "event": "REQUEST_CHANGES",
  "body": "詳細は inline comment を参照してください。",
  "comments": [
    {
      "path": "feature/foo/bar/detail_design.md",
      "line": 42,
      "side": "RIGHT",
      "body": "MUST: この節だけだと再実行時の振る舞いが読み取れないため、冪等性の扱いを文章で明記してください。"
    }
  ]
}
```

送信例:

```bash
gh api \
  repos/<owner>/<repo>/pulls/<PR番号>/reviews \
  -X POST \
  --input review.json
```

運用ルール:

- inline comment は changed line に限定する
- diff に存在しない論点を無理に inline 化しない
- diff に載らない指摘は summary comment に回す
- MUST が 1 件でもあれば `REQUEST_CHANGES`
- SHOULD / QUESTION のみなら `COMMENT`

### 9. ユーザーへ報告する

- 何をレビューしたか
- `kpiee-designs` をどの worktree path で読んだか
- 文書品質レビューと設計妥当性レビューをどう進めたか
- 読んだ関連 repo / Notion / Figma が何か
- MUST / SHOULD / QUESTION の件数
- 代表的な指摘
- GitHub へ投稿したか、下書き止まりか

必要なら follow-up を短く添える。

## Notes

- local checkout と PR 画面で差があるときは、もう一度 fetch し直して確認する
- 設計書レビューでは、新しい仕様提案より既存記述の不足・矛盾・分かりにくさを優先して指摘する
- 実装レビュー用の観点が主題なら `pr-architecture-review` を使い分ける
- Notion / Figma / 関連 repo は「必要になった理由」を言語化できるときだけ開く
