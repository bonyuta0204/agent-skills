# Data Prerequisites

## Goal

ローカル確認で、コードより前に「データ前提が満たされているか」を確認する。

## First Rule

ローカルでは「実装が効いていない」のではなく「前提データが無い」だけ、が頻発する。
特に権限制御、IP 制限、workspace 単位設定は、関連レコードを確認してから挙動を読む。

## Schema Drift

localhost 500 は、まず schema drift を疑う。
アプリのバグと決めつけない。

必要に応じて `ghq` 側 repo で schema を適用する。

```bash
cd /path/to/ghq/zelda-kpiee
bundle exec rake ridgepole:apply FORCE_DROP_TABLE=true
bundle exec rake account_record:ridgepole:apply_all FORCE_DROP_TABLE=true
```

`dx-kpiee` 側も schema 差分が疑わしいなら、repo の標準手順に従って同期する。

## Multi DB Awareness

kpiee は DB が分かれている。
少なくとも次を意識する。

- `dx-kpiee` application / account DB
- `zelda-kpiee` 側の user / workspace 系 DB
- KP account DB

どの制御がどの DB を見ているかを確認しないと、空レコードの原因を見誤る。

## Common Checks

見るべきもの:

- workspace の有効化フラグ
- policy / role / user 種別
- whitelist / permitted IP / feature flag
- 対象レコードの件数

## Minimum Evidence

挙動を結論づける前に、最低限これを揃える。

- 関連レコードが存在するか
- 比較対象の値が何か
- その値がどの DB に入っているか

## Reporting Contract

報告には次を含める。

- どの DB / schema を見たか
- 関連レコードの有無
- 挙動に効くフラグや値
- 必要なら実行した SQL
