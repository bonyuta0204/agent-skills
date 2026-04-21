# Company Slide Design System

## 目的

この document は、社内 slide を SVG / PowerPoint に仕上げるときの visual design system です。

story や slide copy を考えるための document ではなく、**最後に見た目へ落とすときの判断基準** として使う。

## Design Principle

- 情報密度より、視線誘導と感情の流れを優先する
- 装飾で盛るのではなく、余白・角丸・太い文字・限定色で強く見せる
- 1 slide の中で主役は 1 つにする
- slide deck 全体で同じ型を繰り返し、聞き手が迷わないようにする
- 緊張感を出すときも、画面は散らかさず、色を 1 箇所だけ変える

## Canvas

- 基本サイズは `1280 x 720`
- 16:9 固定で設計する
- 外側に背景色を全面で敷く
- 内側に大きな白い rounded frame を置く
- 白 frame の中に main message / cards / agenda を置く

標準構造:

- outer background: slide 全面
- inner frame: `x=40〜45`, `y=40〜85`, `w=1190〜1200`, `h=590〜640`
- content safe area: inner frame からさらに `40〜80px` 内側

## Color Tokens

### Core

- `bg-blue`: `#B3E7FF`
  - 標準の外側背景
  - deck 全体の印象を作る色
- `primary-blue`: `#00B0F0`
  - 強調、選択状態、アクション、問い slide の背景
  - 使いすぎると軽くなるため、1 slide で 1〜2 箇所まで
- `white`: `#FFFFFF`
  - inner frame / card / pill の面
- `text-gray`: `#595959`
  - main text の基本色
- `text-dark-gray`: `#434343`
  - 少し強い本文、引用、補助 box
- `muted-gray`: `#666666`
  - 補助本文

### Accent

- `warn-red`: `#FC7878`
  - 問題、失敗、危機感、否定側
  - 文字か枠線のどちらかに絞る
- `warn-bg`: `#FFEFEF`
  - 問題 slide の背景に使う淡い赤
- `highlight-yellow`: `#FFFF00`
  - 見出し下線
  - 面積は小さく、太い marker として使う
- `highlight-yellow-soft`: `#FFFF89`
  - 黄色下線の stroke 補助
- `border-blue-light`: `#E2EFF9`
  - 非選択 pill / card の淡い枠線

## Typography

PowerPoint 由来の資料では text がアウトライン化されることがあるため、SVG 生成時は近い見た目を優先する。

推奨:

- Japanese font: `Hiragino Sans`, `Yu Gothic`, `Noto Sans JP`
- weight: `700〜800`
- line-height: `1.18〜1.3`
- letter-spacing: `-0.01em〜0`
- alignment: center を基本にする

サイズ目安:

- title / cover: `44〜56px`
- main statement: `44〜52px`
- 2 line statement: `38〜46px`
- card text: `30〜40px`
- small label: `18〜22px`
- annotation: `18〜24px`

文字色:

- 通常の主張は `text-gray`
- 青い面の上は `white`
- 強調語だけ `primary-blue` または `warn-red`
- 黒 `#000000` は shape path や影由来以外では積極的に使わない

## Shape Tokens

### Radius

この design system では角丸が重要です。四角く見えると一気に違う。

- inner frame: `rx=30〜45`
- large card: `rx=25〜35`
- pill / agenda row: `rx=28〜45`
- small label: `rx=8〜14`
- tiny badge: `rx=6〜10`

`rx=12` 程度の card は硬く見えやすい。大きい box ほど丸める。

### Stroke

- card border: `3px`
- agenda inactive border: `2〜3px`, `border-blue-light`
- selected / action border: `3px`, `primary-blue`
- problem border: `3px`, `warn-red`
- yellow underline stroke: `1〜2px`

### Shadow

基本は弱く使う。強い shadow はこのテイストと合いにくい。

- card shadow: `0 3px 8px rgba(0,0,0,0.14)` まで
- white frame には shadow を付けない、または極薄にする

## Layout Archetypes

### 1. Cover / Closing

用途:

- 始まり、終わり、問いの前後

構造:

- `primary-blue` 全面背景
- 中央に white rounded frame
- frame 内中央に main text

見た目:

- 文字は大きく、1 phrase
- 余白を広く取り、他要素を置かない

### 2. Title Kickoff

用途:

- deck title

構造:

- 淡い装飾背景でもよい
- 中央に white pill / rounded box
- title は `primary-blue`

注意:

- 背景装飾は薄くする
- title box が主役になるようにする

### 3. Agenda

用途:

- 章立て、現在位置

構造:

- `bg-blue` 背景
- 大きい white frame
- 上部中央に heading
- heading 下に yellow underline
- 縦に large pill を 3〜4 本並べる

状態:

- selected: `primary-blue` fill + white text
- inactive: white fill + `border-blue-light` stroke + `text-gray`

目安:

- pill width: `800〜920`
- pill height: `70〜90`
- pill radius: `35〜45`
- gap: `25〜40`

### 4. Big Statement

用途:

- 1 枚 1 メッセージ
- 状況認識、問い、結論の手前

構造:

- `bg-blue` 背景
- white frame
- 中央に 1〜3 行の text

表現:

- 基本文字は `text-gray`
- 重要語だけ `primary-blue` / `warn-red`
- 2 色以上の強調は避ける

### 5. Question Slide

用途:

- section 転換、聞き手の目線を切り替える

構造:

- `primary-blue` 全面背景
- 中央上に `?` circle
- 中央に問いを 1 行

表現:

- text は white
- 余白を大きく取り、補足を置かない

### 6. Two-by-Two Cards

用途:

- 期待状態、観点、論点の並列提示

構造:

- `bg-blue` 背景
- white frame
- 2 x 2 の large card
- card は white fill + `primary-blue` stroke

目安:

- card width: `480〜540`
- card height: `170〜210`
- card radius: `25〜35`
- stroke: `3px`
- text: centered, `text-gray`, bold

### 7. Action Rows

用途:

- 今後の取り組み、打ち手、運用項目

構造:

- white frame
- 横長 rounded row を 2〜3 本
- 左に small blue label
- row body に action phrase

表現:

- label は `primary-blue` fill + white text
- row は white fill + `primary-blue` stroke
- action phrase の key word は `primary-blue`

### 8. Current State / Contrast

用途:

- 現状と理想、問題と打ち手の対比

構造:

- heading + yellow underline
- 上下または左右に 2 row
- positive / target は blue
- negative / blocker は red

注意:

- blue と red を同じ強さで全面に使わない
- 対比の意味が一目で分かる配置にする

### 9. Voice / Quote

用途:

- 外部フィードバック、誰かの声、象徴的なコメント

構造:

- 淡い赤または白背景
- avatar / name badge
- speech bubble / white card
- key phrase は blue

注意:

- quote は長くしすぎない
- 「誰の声か」が見えると pathos が作りやすい

### 10. Growth List

用途:

- メンバーの成長、Before / After、期待値の列挙

構造:

- white frame
- 左に avatar
- 右に横長 row card
- 3〜4 人 / 3〜4 item 程度

表現:

- 文字量は増えやすいので、1 row 1 message にする
- row border は細く、主張は太字で作る

## Composition Rules

- まず outer background と inner frame を置く
- heading がある slide は yellow underline を付ける
- main message は frame 中央に置く
- cards は frame 内の余白を十分に残す
- slide の主役以外の要素は小さく、薄く、少なくする
- 1 slide の強調色は原則 1 色。対比 slide だけ blue / red を許す
- 文字は「説明」ではなく「状態」「問い」「期待」を言い切る

## Do / Don't

Do:

- 角丸を大きくする
- 余白を広く取る
- 太い grey text を中心に置く
- blue / red / yellow の役割を固定する
- 同じ layout を繰り返す

Don't:

- card の角を `rx=10〜15` 程度にする
- 細い文字で paragraph を置く
- 背景に gradient や blob を多用する
- shadow を強くする
- 1 slide に複数の message を置く
- 色数を増やす

## SVG / PowerPoint 実装メモ

SVG で先に作る場合:

- `viewBox="0 0 1280 720"` を固定する
- `rect` の `rx` を大きめに取る
- text は live text で作り、最後に必要なら path 化する
- highlight は text 全体ではなく key word だけに当てる
- contact sheet を作って deck 全体の反復感を見る

PowerPoint に戻す場合:

- SVG を slide ごとに背景画像として貼るだけでなく、必要に応じて editable shape に近い構成も残す
- ただし最終見た目を優先する場合は、SVG を高解像度で貼る方が崩れにくい
- 既存資料に混ぜるなら、まず `bg-blue`, `inner frame`, `font weight`, `radius` を合わせる
