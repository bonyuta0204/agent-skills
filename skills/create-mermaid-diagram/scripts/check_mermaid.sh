#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check_mermaid.sh [--strict] <path-to-mermaid-or-markdown>

Validates Mermaid by rendering it with mermaid-cli and emits heuristic warnings
for common syntax/style pitfalls. Markdown inputs are supported when they contain
```mermaid fenced blocks.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn_count=0
warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN: %s\n' "$*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

strict=0
if [[ "${1:-}" == "--strict" ]]; then
  strict=1
  shift
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

input_path=$1
[[ -f "$input_path" ]] || fail "File not found: $input_path"

require_command node
require_command npx

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

lower_input=$(printf '%s' "$input_path" | tr '[:upper:]' '[:lower:]')
is_markdown=0
case "$lower_input" in
  *.md|*.markdown)
    is_markdown=1
    ;;
esac

extract_markdown_blocks() {
  local status

  if awk -v outdir="$tmpdir" '
    BEGIN { in_block = 0; count = 0 }

    /^```mermaid[[:space:]]*$/ {
      if (in_block) {
        print "Nested mermaid block detected." > "/dev/stderr"
        exit 2
      }
      in_block = 1
      count++
      file = sprintf("%s/block-%02d.mmd", outdir, count)
      next
    }

    in_block && /^```[[:space:]]*$/ {
      in_block = 0
      close(file)
      next
    }

    in_block {
      print >> file
      next
    }

    END {
      if (in_block) {
        print "Unclosed mermaid block detected." > "/dev/stderr"
        exit 2
      }
      if (count == 0) {
        exit 3
      }
    }
  ' "$input_path"; then
    return 0
  fi

  status=$?
  if [[ $status -eq 3 ]]; then
    fail "No fenced mermaid blocks found in $input_path"
  fi

  exit "$status"
}

if (( is_markdown )); then
  extract_markdown_blocks
  render_output="$tmpdir/rendered.md"
else
  cp "$input_path" "$tmpdir/block-01.mmd"
  render_output="$tmpdir/rendered.svg"
fi

mapfile -t lint_targets < <(find "$tmpdir" -maxdepth 1 -name 'block-*.mmd' | sort)
[[ ${#lint_targets[@]} -gt 0 ]] || fail "No Mermaid content found for linting"

lint_file() {
  local file_path=$1
  local label=$2
  local line_no=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))

    if [[ "$line" == *$'\t'* ]]; then
      warn "$label:$line_no uses tabs; Mermaid indentation is less brittle with spaces."
    fi

    if [[ "$line" =~ ^[[:space:]]*graph[[:space:]] ]]; then
      warn "$label:$line_no uses 'graph'; prefer explicit 'flowchart' for new flow diagrams."
    fi

    if [[ "$line" =~ ^[[:space:]]*style[[:space:]]+ ]]; then
      warn "$label:$line_no uses inline style; prefer classDef/class for reusable styling."
    fi

    if [[ "$line" =~ \[[^\"\]]*[:(),#][^\"\]]*\] ]]; then
      warn "$label:$line_no has a flowchart label with punctuation and no quotes."
    fi

    if [[ "$line" =~ \|[^\"\|]*[:(),#][^\"\|]*\| ]]; then
      warn "$label:$line_no has an edge label with punctuation and no quotes."
    fi

    if [[ "$line" =~ ^[[:space:]]*%%.*\{.*\} ]]; then
      warn "$label:$line_no has '{}' inside a %% comment; Mermaid docs call this out as fragile."
    fi

    if [[ "$line" =~ classDef[[:space:]].*stroke-dasharray:[^\\]*,[^\\] ]]; then
      warn "$label:$line_no has an unescaped comma in stroke-dasharray; use '\\,'."
    fi
  done < "$file_path"
}

render_log="$tmpdir/mmdc.log"
if ! npx -y -p @mermaid-js/mermaid-cli mmdc -i "$input_path" -o "$render_output" >"$render_log" 2>&1; then
  cat "$render_log" >&2
  fail "Mermaid render validation failed for $input_path"
fi

block_index=0
for lint_target in "${lint_targets[@]}"; do
  block_index=$((block_index + 1))
  lint_file "$lint_target" "block-$block_index"
done

printf 'OK: Mermaid render validation passed for %s (%d block(s))\n' "$input_path" "${#lint_targets[@]}"

if (( warn_count > 0 )); then
  printf 'WARN: %d heuristic warning(s) found.\n' "$warn_count" >&2
  if (( strict )); then
    exit 2
  fi
else
  printf 'OK: No heuristic warnings found.\n'
fi
