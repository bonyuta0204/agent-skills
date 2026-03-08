---
name: create-mermaid-diagram
description: Mermaid diagram を壊れにくく作成・修正するスキル。新規の mermaid 図を書くとき、syntax error やエスケープ崩れを直したいとき、style と layout をベストプラクティスに寄せたいときに使う。
---

# Create Mermaid Diagram

## Overview

この skill は Mermaid 図を「とりあえず書く」のではなく、壊れやすい書き方を避けながら、ローカルで render 検証してから出すための workflow を提供する。

特に次のケースで使う。

- 新しい Mermaid 図を作る
- 既存の Mermaid 図の syntax error を直す
- 文字列の quoting / escaping が怪しい図を直す
- inline style だらけの図を整える
- 見た目や layout をベストプラクティスに寄せる

## Workflow

### 1. Pick the Smallest Diagram Type

まず図の目的を 1 文で固定する。迷ったら次で選ぶ。

- `flowchart`: 分岐、依存、処理フロー
- `sequenceDiagram`: 登場人物ごとのやり取り
- `stateDiagram-v2`: 状態遷移
- `classDiagram`: 型や責務の関係
- `erDiagram`: データ構造
- `gantt`: 日程

図の目的が複数あるなら 1 枚に詰め込まず、図を分ける。

### 2. Draft With Safe Defaults

- 1 行目は diagram declaration だけにする
- node id は短く安定させ、表示文言は label 側へ寄せる
- punctuation を含む label は quote する
- うまく通らない文字は entity code でも逃がす
- `style` の多用より `classDef` / `class` を優先する
- flowchart が絡み始めたら向き (`LR` / `TD`) を見直す
- コメントは `%%` を使い、`{}` を含めない

壊れやすい例と修正パターンは [references/best-practices.md](references/best-practices.md) を読む。

### 3. Validate Before Delivering

作成後は必ず `scripts/check_mermaid.sh` を通す。

```bash
./skills/create-mermaid-diagram/scripts/check_mermaid.sh path/to/diagram.mmd
./skills/create-mermaid-diagram/scripts/check_mermaid.sh path/to/doc-with-mermaid.md
./skills/create-mermaid-diagram/scripts/check_mermaid.sh --strict path/to/diagram.mmd
```

この script は次を行う。

- `mmdc` で render 検証する
- markdown 内の ```mermaid ブロックも検査する
- 壊れやすい label / style / comment の heuristic warning を出す
- `--strict` のときは warning も失敗扱いにする

### 4. Repair In This Order

検証で失敗したら、次の順で直す。

1. diagram type declaration の誤り
2. quote / escape 不足
3. reserved word や breaker word
4. inline style や classDef 内の syntax
5. layout の詰まり

parser error と style warning を同時に抱えているときは、先に parser error を消す。

### 5. Deliverables

ユーザーへ返すときは次を含める。

- 最終的な Mermaid code
- 実行した validation command
- warning が残る場合は、その理由と残す判断

ユーザーがファイル編集を求めていない限り、返却は ```mermaid fenced block を優先する。

## References

- ベストプラクティスと壊れやすい例: [references/best-practices.md](references/best-practices.md)
- ローカル検証 script: [scripts/check_mermaid.sh](scripts/check_mermaid.sh)

## Operating Rules

- render 検証なしで「多分通る」と言わない
- 複雑な 1 枚を無理に保たず、図を分割する
- label の見た目を優先しすぎて id の意味を失わない
- style 調整は局所 `style` より再利用可能な class に寄せる
- Markdown へ埋め込むときも fenced block を壊さない
