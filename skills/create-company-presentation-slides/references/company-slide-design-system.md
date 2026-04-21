# Company Slide Design System

## 目的

この document は、社内 slide を SVG / HTML / PowerPoint に仕上げるときの dax 社内スライド design system です。

story や slide copy を考えるための document ではなく、**最後に見た目へ落とすときの判断基準** として使う。

元にした design system asset は `assets/dax-slide-design-system/` に同梱している。

## Source Assets

使える asset:

- `assets/dax-slide-design-system/colors_and_type.css`
  - brand color、neutral、semantic color、font scale、spacing、radius、shadow
- `assets/dax-slide-design-system/ui_kits/presentation/presentation.css`
  - slide shell、agenda、footer、hero text、callout、before/after、stat、speaker などの component
- `assets/dax-slide-design-system/slides/templates.html`
  - 代表的な 12 slide template
- `assets/dax-slide-design-system/slides/deck-stage.js`
  - HTML deck preview 用 wrapper
- `assets/dax-slide-design-system/assets/backgrounds/`
  - abstract shape background、b-dash pattern、solid blue background
- `assets/dax-slide-design-system/assets/logos/`
  - b-dash、kpiee、Loglass、DIGGLE logo
- `assets/dax-slide-design-system/assets/icons/`
  - question、lightbulb など最小限の icon
- `assets/dax-slide-design-system/preview/`
  - color、type、spacing、radius、component の preview card

`uploads/` の元 PPTX / PDF は skill には含めない。実際の出力に使う token / asset / template だけを同梱している。

## Design Principle

dax 社内 slide の visual language は、**白地に巨大ゴシック、ブルーアクセント、たまに全面色**。

- 1 slide 1 message を徹底する
- 情報量より、視線誘導と感情のピークを優先する
- 説明文ではなく、短い断言・問い・否定・行動喚起で進める
- 装飾は最小限にし、巨大文字・余白・限定色で強く見せる
- section や感情ピークだけ、抽象シェイプ背景や全面色を使う
- icon より text で語る

## Content Tone

文体は「社内向けの檄文」に近い。

- 1 slide は一文、場合によっては一語で成立させる
- `問い -> 答え` の連続で構成する
- 主語は `私たち` / `我々` を基本にする
- 最後は行動に接続する
- `"最高"`、`"kpiee"` のように quote で強調する
- `本気で考える`、`誰よりも`、`絶対に`、`めちゃくちゃ` など強い語を必要なら使う
- `現状は？ -> 否。` のように、否定から理想へ持っていく構成を許容する
- 絵文字は使わない
- 数字は `5倍`、`35項目` のように単位付きで大きく見せる

## Canvas

標準:

- `1920 x 1080`
- 16:9
- PowerPoint / HTML / SVG のどれでもこの比率を維持する

SVG や PPTX で `1280 x 720` に落とす場合:

- token は `1920 x 1080` 基準から `2/3` scale する
- font size、spacing、radius、stroke を同率で縮小する
- visual density は変えない

## Color Tokens

### Brand

- `--dax-blue`: `#00AFF4`
  - primary brand blue
  - 見出し、強調語、図表、active indicator
- `--dax-blue-strong`: `#00B0F0`
  - 原本で頻出する cyan blue
  - heading / emphasis / stroke
- `--dax-blue-solid`: `#5B94F5`
  - 全面塗り slide background
- `--kpiee-coral`: `#FC7878`
  - kpiee accent、否定、感情ピーク
- `--kpiee-coral-soft`: `#FFD5D1`
  - soft shape / background

### Support

- `--support-green`: `#5CCCA8`
  - positive / OK
- `--support-yellow`: `#FFFF89`
  - marker highlight
- `--alert-red`: `#FF0000`
  - strong negative / alert

### Pale Tint

- `--tint-blue-1`: `#EBF6FC`
- `--tint-blue-2`: `#DBEFF9`
- `--tint-blue-3`: `#E2EFF9`

### Neutral

- `--fg-0`: `#000000`
  - hero / absolute emphasis
- `--fg-1`: `#434343`
  - primary body text
- `--fg-2`: `#595959`
  - secondary body text
- `--fg-3`: `#666666`
  - labels / small headings
- `--fg-mute`: `#B7B7B7`
  - muted / inactive
- `--fg-disable`: `#CCCCCC`
  - disabled / rule
- `--bg-page`: `#FFFFFF`
- `--bg-soft`: `#F3F3F3`
- `--bg-softer`: `#F2F2F2`
- `--rule`: `#CCCCCC`
- `--rule-soft`: `#E5E5E5`

### Color Usage

- 通常 slide は white background + dark gray / black text
- blue は key word、active nav、bar、positive emphasis に限定する
- coral / red は negative、危機感、否定、kpiee accent に限定する
- yellow は marker として小面積に使う
- 新しい色を作らない。必要なら既存色から派生させる

## Typography

原本は Meiryo を主フォントとして使う。

推奨 font stack:

```css
"Meiryo", "メイリオ", "Hiragino Kaku Gothic ProN", "Hiragino Sans",
"Noto Sans JP", "Yu Gothic", "Yu Gothic UI", sans-serif
```

ルール:

- Japanese: Meiryo 優先
- English / number: Arial fallback を許容
- weight は `400` と `700` を基本にする
- 中間 weight に頼らない
- hero だけ `900` fallback を許容する
- line-height は tight にする
- 巨大文字では letter-spacing を少し詰める

Scale for `1920 x 1080`:

- hero: `112px`
- display-xl: `88px`
- display: `72px`
- h1: `56px`
- h2: `44px`
- h3: `32px`
- body-lg: `24px`
- body: `20px`
- caption: `16px`
- small: `14px`
- tag: `12px`

Hero component:

- `.dax-hero-text.xl`: `160px`
- `.dax-hero-text.lg`: `112px`
- `.dax-hero-text.md`: `88px`

## Spacing / Radius / Shadow

Spacing scale:

- `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 / 128px`

Radius:

- `4px`: base
- `8px`: card
- `16px`: large card / callout
- `24px`: large panel
- `999px`: pill / badge

Shadow:

- use lightly
- max: `0 4px 12px rgba(0,0,0,0.08)`
- huge drop shadow / neon is not allowed

## Background System

Use these background types intentionally.

### White

- 最多
- message slide、question slide、body slide の default
- 文字と余白だけで成立させる

### Shape Background

Asset:

- `bg-pink-shapes.png`
- `bg-blue-shapes.png`
- `bg-multi-shapes.png`
- `bg-yellow-green-shapes.png`

Use for:

- title
- section divider
- product / brand moment

Rule:

- message を邪魔しない
- shape は主役ではなく mood

### Solid Background

Class:

- `.bg-solid-blue`
- `.bg-solid-dax`
- `.bg-solid-coral`

Use for:

- 一語宣言
- 否定
- 感情ピーク
- section break

Rule:

- text は white
- 余計な element は置かない

### b-dash Pattern

Asset:

- `bg-bdash-pattern.jpg`
- `bg-bdash-pattern-2.jpg`

Use for:

- company / department section
- light brand moment

## Layout Archetypes

### Title

Use:

- deck opening

Structure:

- white or shape background
- center title stack
- kicker at top of stack
- large title
- date / speaker as small meta

### Agenda

Use:

- chapter overview

Structure:

- white background
- large slide title
- numbered agenda rows
- active nav in top-right if needed
- footer with b-dash logo and page number

### Section Divider

Use:

- chapter transition

Structure:

- shape background
- left-aligned or centered section label
- kicker + huge section title

### Hero Question

Use:

- 認識を切り替える

Structure:

- white background
- huge centered question
- `？` or key word in blue

### Hero Answer / Negation

Use:

- emotional peak
- denial

Structure:

- solid coral or solid blue background
- one word / one short phrase
- white text

### Big Message

Use:

- main assertion

Structure:

- white background
- centered 2〜3 line message
- key word in blue / coral

### Before / After

Use:

- current state vs target state

Structure:

- two columns
- center arrow
- after side can use blue border / pale blue background

### Stat

Use:

- single number impact

Structure:

- label
- huge number
- unit
- short caption

### Callout

Use:

- important policy / principle

Structure:

- white card
- thin border
- blue left bar
- title + body

### Speaker / Team

Use:

- speaker intro
- team member card

Structure:

- avatar
- role
- name
- team

### Product Lockup

Use:

- kpiee / b-dash brand moment

Structure:

- shape background
- logo
- single message

### Closing

Use:

- action-oriented final message

Structure:

- centered hero text
- blue key phrase
- footer optional

## Fixed Elements

### Top-right Agenda Nav

Class:

- `.dax-agenda`

Rule:

- active item is black + bold
- active underline is dax blue
- inactive item is muted
- use only when chapter position matters

### Footer

Class:

- `.dax-footer`

Rule:

- bottom left: b-dash logo + deck title
- bottom right: page number
- can omit on emotional peak slides

### Resub Tag

Class:

- `.dax-tag-resub`

Use:

- 再掲 slide

## Iconography

dax slide は icon をほぼ使わない。

Allowed:

- `assets/icons/icon-question.png`
- `assets/icons/icon-lightbulb.png`
- Unicode arrow / check / dot
- Lucide only when no bundled icon fits

Not allowed:

- emoji
- Material Symbols
- Iconify
- newly generated PNG icon
- excessive icon usage

## Implementation Rules

When generating HTML/SVG first:

- start from `assets/dax-slide-design-system/slides/templates.html`
- import `colors_and_type.css`
- import `ui_kits/presentation/presentation.css`
- use `<section class="dax-slide bg-*">` as slide shell
- reuse classes instead of inventing new styling
- create only small local overrides per deck
- produce a contact sheet to check repetition and visual rhythm

When generating PowerPoint:

- keep `1920 x 1080` design proportions
- use Meiryo if available
- if SVG rendering is used, export each slide from the HTML/SVG source and place it in PPTX
- if editable PPTX is required, recreate the same token values with PowerPoint shapes
- do not mix unrelated PowerPoint theme colors

## Do / Don't

Do:

- use white background as default
- use huge bold Japanese text
- use blue / coral / yellow for specific semantic roles
- keep each slide visually sparse
- repeat template archetypes
- use top-right agenda and footer only when they support context
- check the full deck as a contact sheet

Don't:

- use emoji
- make a paragraph-heavy slide
- add new colors
- use Inter / Roboto as primary font
- overuse icons
- use heavy shadow / neon / glassmorphism
- nest cards inside cards
- make every slide visually different
