---
name: slack-ng-to-issue
description: Slack の NG報告スレッド (#kpiee_ng報告) から NG 情報を取得し、GitHub Issue として起票するスキル。NG一覧IDを指定して使う。
---

# Slack NG報告 → GitHub Issue 起票

## Overview

`#kpiee_ng報告` チャンネル (C05Q5NWENKY) に NG起票通知bot が投稿する NG レポートを読み取り、GitHub Issue を作成する。

- ユーザーが **NG一覧ID** (`kp_ng_XXXXXX`) を 1 つ以上指定する
- Slack から該当スレッドを検索・取得し、NG 情報を構造化する
- 指定リポジトリ (デフォルト: カレントリポジトリ) に Issue を起票する

## When To Use

- NG報告を GitHub Issue として管理したいとき
- Slack の NG スレッドから Issue を素早く作りたいとき

使わない場面:
- NG の修正実装まで進めるとき (起票のみ担当)
- NG一覧スプレッドシートを直接操作したいとき

## Inputs

### Required

- `ng_ids`: NG一覧ID の配列 (例: `kp_ng_010611`, `kp_ng_010339`)

### Optional

- `repo`: Issue 起票先リポジトリ (`owner/repo` 形式)。省略時はカレントリポジトリ
- `labels`: Issue に付与するラベル (カンマ区切り)

## Workflow

### Step 1: Slack から NG 情報を取得

1. `#kpiee_ng報告` チャンネル (ID: `C05Q5NWENKY`) で NG一覧ID をキーワード検索する
   - `slack_search_public` で `kp_ng_XXXXXX in:<#C05Q5NWENKY>` を検索
   - 見つからない場合は `slack_search_public_and_private` にフォールバック
2. 該当メッセージの **親メッセージ** (NG起票通知bot の投稿) を特定する
   - 検索結果が返信の場合は `slack_read_thread` で親を取得
3. スレッド全体を `slack_read_thread` で読み取る

### Step 2: NG 情報をパースする

親メッセージ (bot 投稿) のコードブロックから以下のフィールドを抽出する:

| フィールド | キー |
| --- | --- |
| NG一覧ID | `ng_id` |
| 改修ID | `fix_id` |
| 検知デバイス | `detected_device` |
| 再現デバイス | `repro_device` |
| リリース予定日 | `release_date` |
| テスト種別 | `test_type` |
| バグ検知環境 | `detected_env` |
| 開発対象ID | `dev_target_id` |
| テストケースリンク | `testcase_link` |
| NG事象 | `description` |
| 再現方法 | `repro_steps` |
| 証跡リンク | `evidence_link` |
| 事象発生時間 | `occurrence_time` |
| NG一覧リンク | `ng_list_link` |

スレッド返信から追加コンテキストも収集する:
- デプロイ完了メッセージの有無
- 起票者・担当者のメンション

### Step 3: デプロイ済み判定

スレッド内に `:white_check_mark: *【デプロイ完了】*` が含まれる場合:

- **ユーザーに確認する**: 「この NG (kp_ng_XXXXXX) は既にデプロイ完了済みですが、Issue を起票しますか？」
- ユーザーが不要と判断すればスキップする

### Step 4: 起票先リポジトリの決定

1. `repo` が明示指定されていればそれを `target_repo` として採用する
2. 省略時はカレントリポジトリの `owner/repo` を `gh repo view --json nameWithOwner` で取得し、それを `target_repo` とする
3. NG 内容から原因が別サービスにありそうな場合は、ユーザーに起票先を確認する
4. **以後の GitHub CLI 操作はすべて `target_repo` に対して行う**
   - 例: `gh issue list -R "$target_repo" ...`
   - 例: `gh issue create -R "$target_repo" ...`

### Step 5: リポジトリ固有の Issue ルールを確認

起票先リポジトリに以下のファイルがあれば読み、Issue フォーマットや必須ラベルなどの指示に従う:

- `CLAUDE.md` / `AGENTS.md`
- `.github/ISSUE_TEMPLATE/` 配下のテンプレート

リポジトリ固有の指示がある場合はそちらを **優先** する。
この確認も `target_repo` を基準に行い、現在の作業ディレクトリの repo を暗黙に使わない。

### Step 6: GitHub Issue を作成

リポジトリ固有テンプレートがない場合のデフォルトフォーマット:

```markdown
## タイトル

[NG事象の1行要約] (NG一覧ID)

## 本文

### NG 概要

| 項目 | 値 |
| --- | --- |
| NG一覧ID | kp_ng_XXXXXX |
| 改修ID | IMP_KPXXXXXX |
| 開発対象ID | KP3_XXXXX |
| 検知環境 | STG |
| 再現デバイス | PC（ブラウザ） |
| リリース予定日 | Sprint XX |
| テスト種別 | XXXX |

### NG 事象

{NG事象の内容をそのまま転記}

### 再現方法

{再現方法をそのまま転記。ない場合は省略}

### 参考リンク

- [NG一覧]({ng_list_link})
- [証跡]({evidence_link})
- [Slack スレッド]({slack_thread_permalink})
```

Issue 作成には `gh issue create -R "$target_repo"` を使用する。

### Step 7: 結果報告

起票した Issue の URL をユーザーに報告する。複数件の場合はサマリテーブルで一覧化する。

## Operating Rules

1. **Slack チャンネル ID はハードコード**: `C05Q5NWENKY` (`#kpiee_ng報告`)
2. **NG 情報は bot の親メッセージが正**: デプロイ完了メッセージではなく、NG起票通知bot の投稿からフィールドを抽出する
3. **リポジトリ固有ルール優先**: `CLAUDE.md` / `AGENTS.md` / Issue テンプレートの指示はこの skill のデフォルトより優先する
4. **確認が必要な場面**:
   - デプロイ完了済みの NG を起票しようとしているとき
   - NG 内容から起票先が現在のリポジトリではなさそうなとき
5. **Slack パーマリンクを必ず含める**: Issue 本文にスレッドへのリンクを入れ、元情報へのトレーサビリティを確保する
6. **重複チェック**: 起票前に、同じ NG一覧ID で既存 Issue がないか `gh issue list -R "$target_repo" -S "kp_ng_XXXXXX"` で確認する。既存 Issue がある場合はユーザーに報告し、起票をスキップする
