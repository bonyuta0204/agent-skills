# Presentation UI Kit

dax 社内スライド用の UI コンポーネント集。`slides/` テンプレートや
新規スライド作成時にコピーして使う。

## 使い方

1. `slides/` の `.html` を新規スライドのテンプレとしてコピー
2. ルートに `<link rel="stylesheet" href="../colors_and_type.css">` を追加
3. 本キット (`presentation.css`) も合わせて読み込み
4. スライド 1 枚 = `<section class="dax-slide">` 単位

## コンポーネント一覧

- **Slide shell** (`.dax-slide`) — 1920×1080 固定キャンバス
- **Slide background variants** — `.bg-white` / `.bg-solid-blue` / `.bg-solid-coral` / `.bg-shapes-pink` / `.bg-shapes-blue` / `.bg-shapes-multi` / `.bg-pattern-bdash`
- **Agenda nav** (`.dax-agenda`) — 右上のセクション切替
- **Footer** (`.dax-footer`) — b↘dash ロゴ + ページ番号
- **Hero text** (`.dax-hero-text`) — センター1語〜1行メッセージ
- **Callout card** (`.dax-callout`) — 左バー + タイトル + 本文
- **Before → After** (`.dax-baftr`) — 現状/目指す姿 の2カラム
- **Stat** (`.dax-stat`) — 大きな数値 + 単位 + 補足
- **Speaker** (`.dax-speaker`) — 発表者カード
- **Re-used tag** (`.dax-tag-resub`) — 再掲スライド用
