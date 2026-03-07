# Release Gate

リリース判定を Go / No-Go で行うためのチェックリスト。

## Go Criteria

以下をすべて満たしたら Go とする。

1. 主要タスクが完了している。
2. 重大バグ（P0/P1）が未解決で残っていない。
3. 必須CIがすべて通過している。
4. デプロイ手順とロールバック手順が確認済み。
5. 監視ポイントと一次対応担当が明確。
6. ユーザー影響がある変更は告知文案が準備済み。

## No-Go Criteria

1つでも該当したら No-Go とする。

1. 仕様未確定のまま実装が必要なタスクが残っている。
2. データ破壊または認可崩壊の可能性が未評価。
3. 失敗したCIに妥当な受容理由がない。
4. ロールバック不能または復旧手順が未検証。
5. 依存PRのマージ順が未確定で整合性リスクが高い。

## Release Decision Log Template

```markdown
## Release Decision

- Decision: Go / No-Go
- Scope: <対象機能>
- Milestone: <release-sprintXX など>
- Date: <YYYY-MM-DD>

### Evidence
- CI: <pass/fail summary>
- Validation: <手動検証結果>
- Risk: <残リスク>

### Follow-ups
- <担当> <期限> <対応内容>
```

## Post-Release Checklist

1. 監視アラート異常の有無を確認
2. 主要ユースケースのサニティチェック
3. 既知制約の再掲
4. 次リリースへの持ち越し項目整理
