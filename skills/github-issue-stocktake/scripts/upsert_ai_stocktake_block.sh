#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  upsert_ai_stocktake_block.sh --body-file <path> --block-file <path> --out-file <path>
USAGE
}

BODY_FILE=""
BLOCK_FILE=""
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --body-file)
      BODY_FILE="$2"
      shift 2
      ;;
    --block-file)
      BLOCK_FILE="$2"
      shift 2
      ;;
    --out-file)
      OUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BODY_FILE" || -z "$BLOCK_FILE" || -z "$OUT_FILE" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi
if [[ ! -f "$BLOCK_FILE" ]]; then
  echo "Block file not found: $BLOCK_FILE" >&2
  exit 1
fi

START='<!-- AI_STOCKTAKE_START -->'
END='<!-- AI_STOCKTAKE_END -->'

has_start=0
has_end=0
if rg -q --fixed-strings "$START" "$BODY_FILE"; then
  has_start=1
fi
if rg -q --fixed-strings "$END" "$BODY_FILE"; then
  has_end=1
fi

if [[ $has_start -ne $has_end ]]; then
  echo "Body has only one marker. Manual fix required." >&2
  exit 1
fi

start_count=$(rg -c --fixed-strings "$START" "$BODY_FILE" || true)
end_count=$(rg -c --fixed-strings "$END" "$BODY_FILE" || true)
if [[ "${start_count:-0}" -gt 1 || "${end_count:-0}" -gt 1 ]]; then
  echo "Body has multiple AI_STOCKTAKE marker pairs. Manual fix required." >&2
  exit 1
fi

block_content="$(cat "$BLOCK_FILE")"
if ! printf '%s' "$block_content" | rg -q --fixed-strings "$START"; then
  block_content="$START
$block_content"
fi
if ! printf '%s' "$block_content" | rg -q --fixed-strings "$END"; then
  block_content="$block_content
$END"
fi

export BODY_FILE BLOCK_FILE OUT_FILE START END

if [[ $has_start -eq 1 ]]; then
  perl -0777 -e '
    use strict;
    use warnings;

    my $body_file = $ENV{"BODY_FILE"};
    my $block_file = $ENV{"BLOCK_FILE"};
    my $out_file = $ENV{"OUT_FILE"};

    open my $bfh, q{<}, $body_file or die "open body: $!";
    local $/;
    my $body = <$bfh>;
    close $bfh;

    open my $sfh, q{<}, $block_file or die "open block: $!";
    my $block = <$sfh>;
    close $sfh;

    if ($block !~ /<!-- AI_STOCKTAKE_START -->/) {
      $block = "<!-- AI_STOCKTAKE_START -->\n" . $block;
    }
    if ($block !~ /<!-- AI_STOCKTAKE_END -->/) {
      $block = $block . "\n<!-- AI_STOCKTAKE_END -->";
    }

    my $re = qr/<!-- AI_STOCKTAKE_START -->.*?<!-- AI_STOCKTAKE_END -->/s;
    $body =~ s/$re/$block/s or die "markers not replaceable";

    open my $ofh, q{>}, $out_file or die "open out: $!";
    print {$ofh} $body;
    close $ofh;
  '
else
  cp "$BODY_FILE" "$OUT_FILE"
  if [[ -s "$OUT_FILE" ]]; then
    printf '\n\n---\n\n' >> "$OUT_FILE"
  fi
  printf '%s\n' "$block_content" >> "$OUT_FILE"
fi

echo "updated: $OUT_FILE"
