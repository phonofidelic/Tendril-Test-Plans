#!/usr/bin/env bash
# Validates that every skill under skills/ exists and is spec-compliant per
# the agentskills.io specification (https://agentskills.io/specification).
# Run from anywhere: bash skills/run-tendril-test-plans/scripts/smoke.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

# Frontmatter keys recognized by the spec (plus the experimental allowed-tools).
ALLOWED_KEYS="name description license compatibility metadata allowed-tools"

# Test-plan skills whose execution order the README must document.
ORDERED=(
  "setup-repo"
  "test-onboarding-and-settings"
  "test-plan-creation"
  "test-plan-execution"
  "test-review-and-pr"
  "test-recommendations-and-misc"
)

PASS=0
FAIL=0
WARN=0

ok()   { echo "  ✓ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ✗ $1 — $2"; FAIL=$((FAIL + 1)); }
warn() { echo "  ! $1 — $2"; WARN=$((WARN + 1)); }

# Extract the YAML frontmatter block (between the first two --- delimiters).
frontmatter() {
  awk 'NR==1 && $0!="---"{exit} /^---[[:space:]]*$/{c++; if(c==2) exit; next} c==1{print}' "$1"
}

echo "=== Tendril Test Plan — Skill Smoke Check ==="
echo ""

echo "── Core documents"
if [ -f "$SKILLS_DIR/README.md" ]; then
  ok "skills/README.md"
else
  bad "skills/README.md" "missing"
fi
if [ -f "$REPO_ROOT/test-plans/tendril-test-plan.md" ]; then
  ok "test-plans/tendril-test-plan.md"
else
  bad "test-plans/tendril-test-plan.md" "missing"
fi
echo ""

echo "── Skill directories (spec compliance)"
shopt -s nullglob
skill_dirs=("$SKILLS_DIR"/*/)
shopt -u nullglob

if [ ${#skill_dirs[@]} -eq 0 ]; then
  bad "skills/*" "no skill directories found"
fi

for dir in "${skill_dirs[@]}"; do
  name="$(basename "$dir")"
  skill_file="$dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    bad "$name/SKILL.md" "SKILL.md missing"
    continue
  fi

  fm="$(frontmatter "$skill_file")"

  if [ -z "$fm" ]; then
    bad "$name/SKILL.md" "missing YAML frontmatter"
    continue
  fi

  # name present and equal to the parent directory name
  fm_name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'"' ')"
  if [ -z "$fm_name" ]; then
    bad "$name/SKILL.md" "missing 'name' in frontmatter"
    continue
  fi
  if [ "$fm_name" != "$name" ]; then
    bad "$name/SKILL.md" "name '$fm_name' does not match directory '$name'"
    continue
  fi

  # description present and non-empty (handles inline or block scalar)
  desc_inline="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  if ! printf '%s\n' "$fm" | grep -q '^description:'; then
    bad "$name/SKILL.md" "missing 'description' in frontmatter"
    continue
  fi
  # If block scalar (> or >-), require at least one indented content line.
  case "$desc_inline" in
    ">"*|"|"*)
      if ! printf '%s\n' "$fm" | grep -qE '^[[:space:]]+[^[:space:]]'; then
        bad "$name/SKILL.md" "empty block-scalar 'description'"
        continue
      fi
      ;;
    "")
      bad "$name/SKILL.md" "empty 'description'"
      continue
      ;;
  esac

  # No unknown top-level frontmatter keys.
  unknown=""
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    case " $ALLOWED_KEYS " in
      *" $key "*) ;;
      *) unknown="$unknown $key" ;;
    esac
  done < <(printf '%s\n' "$fm" | sed -n 's/^\([A-Za-z][A-Za-z0-9-]*\):.*/\1/p')

  if [ -n "$unknown" ]; then
    bad "$name/SKILL.md" "unknown frontmatter key(s):$unknown"
    continue
  fi

  ok "$name/SKILL.md"

  # Spec recommends keeping SKILL.md under 500 lines (warning only).
  lines="$(wc -l < "$skill_file" | tr -d ' ')"
  if [ "$lines" -gt 500 ]; then
    warn "$name/SKILL.md" "$lines lines exceeds recommended 500"
  fi
done

echo ""
echo "── Execution-order check (README)"
for entry in "${ORDERED[@]}"; do
  if grep -q "$entry" "$SKILLS_DIR/README.md"; then
    ok "README references $entry"
  else
    bad "README references $entry" "missing"
  fi
done

echo ""
echo "══════════════════════════════════════════"
echo "  Passed: $PASS   Failed: $FAIL   Warnings: $WARN"
if [ "$FAIL" -eq 0 ]; then
  echo "  Status: ALL CHECKS PASSED"
  echo ""
  echo "  For full spec validation, run: pnpx check-skills validate skills --recursive"
  exit 0
else
  echo "  Status: FAILURES FOUND"
  exit 1
fi
