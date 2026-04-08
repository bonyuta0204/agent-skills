# Output Contracts

サブエージェントの出力はすべてJSONで返す。  
PM本体はこのJSONを統合して意思決定する。

## 1) architecture-reader

```json
{
  "component_map": [
    {
      "name": "backend/go",
      "responsibility": "集計APIとバッチ処理",
      "is_in_scope": true,
      "reason": "対象機能でAPI拡張が必要"
    }
  ],
  "domain_boundaries": [
    "認証境界はzelda-kpiee側",
    "KPI算出境界はdx-kpieeのGo層"
  ],
  "unknowns": [
    "仕様書上でエラー時UIが未定義"
  ]
}
```

## 2) impact-analyst

```json
{
  "impacts": [
    {
      "surface": "API",
      "risk": "medium",
      "detail": "レスポンス項目追加でフロント型更新が必要",
      "mitigation": "orval再生成と型チェックを必須化"
    }
  ],
  "regression_points": [
    "既存フィルタ条件",
    "エクスポート処理"
  ],
  "test_focus": [
    "request spec",
    "go unit test",
    "frontend typecheck"
  ]
}
```

## 3) task-planner

```json
{
  "tasks": [
    {
      "id": "TASK-01",
      "title": "API仕様更新",
      "estimate_day": 1.0,
      "depends_on": [],
      "owner_role": "backend",
      "acceptance_criteria": [
        "OpenAPI更新済み",
        "クライアント生成済み",
        "互換性テスト通過"
      ]
    }
  ],
  "critical_path": [
    "TASK-01",
    "TASK-03",
    "TASK-05"
  ],
  "parallel_lanes": [
    ["TASK-01", "TASK-02"],
    ["TASK-04"]
  ]
}
```

## 4) ops-executor

```json
{
  "operation": "ci_watch",
  "target": "PR#12345",
  "status": "failed",
  "evidence": [
    "check-backend-go: lint error",
    "danger: milestone missing"
  ],
  "next_actions": [
    "milestone設定",
    "lint修正後に再実行"
  ],
  "needs_user_decision": false
}
```

## 5) reporter

```json
{
  "summary": {
    "done": 5,
    "in_progress": 2,
    "blocked": 1
  },
  "blockers": [
    {
      "task_id": "TASK-07",
      "reason": "仕様未確定",
      "owner": "PM",
      "eta": "2026-03-05"
    }
  ],
  "next_24h": [
    "CI失敗2件の解消",
    "stagingデプロイ",
    "リリース判定資料の更新"
  ]
}
```

## 6) PM Consolidated Board

PMが最終的に保持する要約フォーマット。

```json
{
  "goal": "カスタムレポートの改善をリリースする",
  "milestone": "release-sprint42",
  "tasks": [
    {
      "id": "TASK-01",
      "state": "done",
      "owner": "worker-backend",
      "last_update": "OpenAPI再生成まで完了"
    }
  ],
  "risks": [
    {
      "id": "RISK-01",
      "level": "high",
      "detail": "仕様未確定項目が1件残存",
      "decision_needed": true
    }
  ],
  "next_actions": [
    "仕様確認後にTASK-07再開",
    "staging検証の結果を反映"
  ]
}
```
