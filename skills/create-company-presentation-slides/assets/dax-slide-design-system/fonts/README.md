# Fonts

dax 社内スライドのプライマリフォントは **Meiryo (メイリオ)** です。
Meiryo は Microsoft / Windows 同梱フォントであり、**商用再配布が
認められていない** ため、このリポジトリでは .ttc ファイルを同梱して
いません。

## Web での代替

`colors_and_type.css` で以下の順でフォントを指定しています:

```
"Meiryo", "メイリオ",
"Hiragino Kaku Gothic ProN", "Hiragino Sans",
"Noto Sans JP",
"Yu Gothic", "Yu Gothic UI",
sans-serif
```

- **Windows**: Meiryo が自動採用（最も忠実）。
- **macOS**: Hiragino Kaku Gothic ProN が採用（近いが少し細い）。
- **それ以外**: Google Fonts の **Noto Sans JP** がロードされ採用。

## ⚠️ フラグ

- Noto Sans JP は **Meiryo より字面が若干細く丸い** ため、タイトル
  スライドの重さがわずかに落ちます。社内運用では Meiryo 搭載の
  Windows 環境で最終確認してください。
- 英数字は原本で **Arial** が使用されています。Arial はほとんどの
  環境に同梱されています。
- Meiryo の代替として見た目が近い Google Fonts: M PLUS 1p Bold。
  必要であれば colors_and_type.css の中で有効化できます。

## フォントファイルが必要な場合

社内の正式配布 Meiryo / 追加の webfont があればこのフォルダに配置し、
`colors_and_type.css` の `@font-face` を有効化してください。
