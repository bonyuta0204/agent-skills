# KPIEE Governance Baseline

PM/Opsとして最低限守る運用ルール。

## 1) Branch / Commit Naming

基準: zelda-docs の資源管理ルール。

- ブランチ命名
  - Feature: `feat/<実装ID>_<変更内容>`
  - Internal improvement: `chore/<内部改善ID>_<変更内容>`
  - Rollback: `detach/<実装ID>_<変更内容>`
- 1ブランチ1IDを厳守する。
- コミットメッセージ先頭にIDを付ける。
  - `[実装ID] ...`
  - `[内部改善ID] ...`
  - `[DETACH_実装ID] ...`

## 2) PR Governance (Danger想定)

最低チェック:

- ブランチ名と改修IDが整合している。
- コミットプレフィックスが改修IDと整合している。
- PRタイトル/ラベルに `WIP` を含めない。
- milestoneを必ず設定する。
- baseブランチ制約に違反しない。

## 3) Milestone Policy

候補優先順:

1. 同一改修IDの既存PRと同じmilestone
2. branch名に `sprintXX` があれば `release-sprintXX`
3. リリース列車対象外のCHOREは `chore-milestone`
4. 不明時は最新 `release-sprintXX` を提案し、最終判断はユーザー確認

## 4) Long-Lived Branch Conflict Rule

`develop` と `integration/*` / `staging*` 間の衝突解消は専用ブランチ運用を使う。

- 例: `chore/CHORE0333_fix_confict`
- 長期ブランチへ直接pushしない。
- 専用ブランチからPRで反映する。

## 5) CI Waiting Approval Rule (dx-kpiee)

`test` 環境保護で `waiting` になる場合がある。  
必要なときは `pending_deployments` を承認して進める。

運用ポイント:

- `gh run list` で対象runを特定する。
- `pending_deployments` APIで待機状態を確認する。
- `--input` にJSONを渡して承認する。
- `gh pr checks --watch` または `gh run watch` で完了確認する。

## 6) Non-Bypass Policy

- `--no-verify` でフックを回避しない。
- husky/commitlintを無効化しない。
- force-pushはしない（明示指示がある場合を除く）。

## 7) PM Practical Rule

- ガバナンス違反は実装作業より先に修正する。
- CI失敗時は「仕様/実装/運用」の3分類で切り分ける。
- 不明点は早期にユーザーへエスカレーションする。
