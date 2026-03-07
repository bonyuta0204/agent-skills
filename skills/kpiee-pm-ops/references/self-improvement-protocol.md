# Self Improvement Protocol

PMスキルを自己改善するための運用手順。

## 1) 学びの収集

毎セッションで最低1件、以下を記録する。

- 何が起きたか（signal）
- どう対処したか（action）
- どこに効くか（scope）
- 根拠（evidence）

記録先: `memory/learning-log.md`

## 2) 学びの分類

分類は次の4種とする。

- `workflow`: 進行手順に関する学び
- `governance`: ルール順守に関する学び
- `risk`: 障害・遅延・ブロッカーに関する学び
- `communication`: ユーザー連携に関する学び

## 3) 昇格ルール

- 一度限りの事象は learning-log のみ。
- 同種事象が3回以上出たら playbook へ昇格。
- playbook昇格時は update-proposals に変更提案を残す。

## 4) スキル更新ルール

自動反映してよい変更:

- チェックリストの順序最適化
- 失敗時の分岐追加
- 既存ルールの明確化（文言改善）

ユーザー確認を要する変更:

- ガバナンスの意味を変える変更
- 役割分担の大幅変更
- リリース判定基準の変更

## 5) 反映サイクル

1. `scripts/review_learnings.sh` で反復パターンを確認
2. `scripts/propose_skill_update.sh` で更新候補を追加
3. 承認済み候補をSKILL/refsへ反映
4. learning-logへ更新記録を追記
