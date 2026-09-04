#!/bin/sh
# Sync shared content into Open WebUI (Prompt Manager + native Skills).
#
# Usage:
#   OPENWEBUI_API_KEY=... ./scripts/sync-openwebui.sh                # prompts only
#   OPENWEBUI_API_KEY=... ./scripts/sync-openwebui.sh --skills       # prompts + skills
#   OPENWEBUI_API_KEY=... ./scripts/sync-openwebui.sh --skills-only  # native skills only
#
# Env:
#   OPENWEBUI_URL     (default: http://localhost:8080)
#   OPENWEBUI_API_KEY (required; create one in Open WebUI user settings -> API keys,
#                      account needs manager/admin role)
#
# Skills are synced as Open WebUI *native skills* via the /skills API
# (idempotent: unchanged skills are skipped, changed ones updated, new ones
# created; existing skills are never deleted). Each shared/skills/<name>/
# directory with a SKILL.md becomes a skill: frontmatter `name`/`description`
# are used as metadata, the markdown body is the skill content, and the skill
# is readable by all users.
set -eu

OPENWEBUI_URL="${OPENWEBUI_URL:-http://localhost:8080}"
: "${OPENWEBUI_API_KEY:?Set OPENWEBUI_API_KEY}"

WITH_SKILLS=0
[ "${1:-}" = "--skills" ] && WITH_SKILLS=1
SKILLS_ONLY=0
[ "${1:-}" = "--skills-only" ] && SKILLS_ONLY=1

BASE="$(cd "$(dirname "$0")/.." && pwd)"
SHARED="$BASE/shared"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

AUTH="Authorization: Bearer $OPENWEBUI_API_KEY"

upload() {
  file="$1"
  name="$(basename "$file")"
  if curl -fsS -X POST "$OPENWEBUI_URL/v1/prompt/file/upload" \
       -H "$AUTH" \
       -F "file=@$file"; then
    echo "  + $name"
  else
    echo "  ! failed: $name" >&2
    return 1
  fi
}

# Escape a string for embedding inside a JSON double-quoted value.
json_str() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//' \
    | awk 'BEGIN{ORS=""} {if (NR>1) printf "\\n"; printf "%s", $0}'
}

# Read a single-line field from the YAML frontmatter of a SKILL.md.
fm_field() {
  # $1 = file, $2 = field name
  awk -v field="$2" '
    /^---[ \t]*$/ { c++; next }
    c == 1 && $0 ~ "^"field":" {
      sub("^"field":[ \t]*", "")
      gsub(/^["\047]|["\047]$/, "")
      print
      exit
    }
  ' "$1"
}

sync_skill() {
  dir="$1"
  skill_md="$dir/SKILL.md"
  id="$(basename "$dir" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_' '-' | sed 's/-*$//')"
  name="$(fm_field "$skill_md" name)"
  [ -n "$name" ] || name="$(basename "$dir")"
  description="$(fm_field "$skill_md" description)"
  content="$(awk 'BEGIN{fm=0} /^---[ \t]*$/{fm++; next} fm>=2{print}' "$skill_md")"
  [ -n "$content" ] || content="$(cat "$skill_md")"

  payload="{\"id\":\"$(json_str "$id")\",\"name\":\"$(json_str "$name")\",\"description\":\"$(json_str "$description")\",\"content\":\"$(json_str "$content")\",\"meta\":{},\"is_active\":true,\"access_grants\":[{\"principal_type\":\"anyone\",\"principal_id\":\"*\",\"permission\":\"read\"}]}"

  existing="$(curl -fsS -X GET "$OPENWEBUI_URL/skills/id/$id" -H "$AUTH" 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    case "$existing" in
      *"\"content\":\"$(json_str "$content")\""*)
        echo "  = $name (unchanged)"
        return 0
        ;;
    esac
    if curl -fsS -X POST "$OPENWEBUI_URL/skills/id/$id/update" \
         -H "$AUTH" -H "Content-Type: application/json" -d "$payload" >/dev/null; then
      echo "  ~ $name (updated)"
    else
      echo "  ! update failed: $name" >&2
      return 1
    fi
  else
    if curl -fsS -X POST "$OPENWEBUI_URL/skills/create" \
         -H "$AUTH" -H "Content-Type: application/json" -d "$payload" >/dev/null; then
      echo "  + $name (created)"
    else
      echo "  ! create failed: $name" >&2
      return 1
    fi
  fi
}

if [ "$SKILLS_ONLY" != "1" ]; then
  echo "Prompt templates -> $OPENWEBUI_URL"
  for f in "$SHARED"/prompts/*.txt "$SHARED"/prompts/*.json; do
    [ -e "$f" ] || continue
    upload "$f"
  done
fi

if [ "$WITH_SKILLS" = "1" ] || [ "$SKILLS_ONLY" = "1" ]; then
  echo "Native skills -> $OPENWEBUI_URL"
  for d in "$SHARED"/skills/*/; do
    [ -d "$d" ] || continue
    [ -f "$d/SKILL.md" ] || continue
    sync_skill "$d"
  done
fi

echo "Done."
