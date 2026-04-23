#!/usr/bin/env bash
# SVG を PNG に rasterize する薄いラッパ。
# default: rsvg-convert で 1920 幅の PNG を入力と同じディレクトリに出力する。
set -euo pipefail

WIDTH=1920
OUTPUT=""
INPUT=""

usage() {
  cat <<'USAGE'
Usage: render-svg.sh <input.svg> [-o <output.png>] [-w <width>]

Options:
  -o <output.png>   出力 PNG path（default: <input>.png）
  -w <width>        出力幅 px（default: 1920、高さは SVG viewBox 比率で自動決定）
  -h, --help        このヘルプを表示

rsvg-convert が必要です。未インストールなら `brew install librsvg` で入れてください。
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      OUTPUT="$2"
      shift 2
      ;;
    -w)
      WIDTH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$INPUT" ]]; then
        echo "Error: multiple inputs not supported: $1" >&2
        exit 1
      fi
      INPUT="$1"
      shift
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Error: input SVG path required" >&2
  usage
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: not found: $INPUT" >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Error: rsvg-convert not installed. Run: brew install librsvg" >&2
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${INPUT%.svg}.png"
fi

rsvg-convert -w "$WIDTH" -o "$OUTPUT" "$INPUT"

# agent が Read しやすいよう絶対パスで最終行に出す
if command -v realpath >/dev/null 2>&1; then
  realpath "$OUTPUT"
else
  (cd "$(dirname "$OUTPUT")" && printf '%s/%s\n' "$PWD" "$(basename "$OUTPUT")")
fi
