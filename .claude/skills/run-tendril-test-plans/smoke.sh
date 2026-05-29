#!/usr/bin/env bash
# Validates that all expected skills exist and have required frontmatter.
# Run from the repo root: bash .claude/skills/run-tendril-test-plans/smoke.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

EXPECTED=(
  setup-repo-node
  setup-repo-python
  setup-repo-go
  setup-repo-react
  setup-repo-mono
  setup-repo-dotnet
  test-onboarding-and-settings
  test-plan-creation
  test-plan-execution
  test-review-and-pr
  test-recommendations-and-misc
)

PASS=0
FAIL=0

check() {
  local label="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label — $result"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Tendril Test Plan — Skill Smoke Check ==="
echo ""

# 1. Test plan document exists
echo "── Core documents"
if [ -f "$REPO_ROOT/development-branch-test-plan.md" ]; then
  check "development-branch-test-plan.md" "ok"
else
  check "development-branch-test-plan.md" "missing"
fi
if [ -f "$SKILLS_DIR/README.md" ]; then
  check "skills/README.md" "ok"
else
  check "skills/README.md" "missing"
fi

echo ""
echo "── Skill directories"
for skill in "${EXPECTED[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [ ! -d "$SKILLS_DIR/$skill" ]; then
    check "$skill/" "directory missing"
    continue
  fi
  if [ ! -f "$skill_file" ]; then
    check "$skill/SKILL.md" "SKILL.md missing"
    continue
  fi
  # Check for required frontmatter fields
  if ! grep -q '^name:' "$skill_file"; then
    check "$skill/SKILL.md" "missing 'name:' in frontmatter"
    continue
  fi
  if ! grep -q '^description:' "$skill_file"; then
    check "$skill/SKILL.md" "missing 'description:' in frontmatter"
    continue
  fi
  check "$skill/SKILL.md" "ok"
done

echo ""
echo "── Execution-order check (README)"
ORDERED=(
  "setup-repo"
  "test-onboarding-and-settings"
  "test-plan-creation"
  "test-plan-execution"
  "test-review-and-pr"
  "test-recommendations-and-misc"
)
for entry in "${ORDERED[@]}"; do
  if grep -q "$entry" "$SKILLS_DIR/README.md"; then
    check "README references $entry" "ok"
  else
    check "README references $entry" "missing"
  fi
done

echo ""
echo "══════════════════════════════════════════"
echo "  Passed: $PASS   Failed: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "  Status: ALL CHECKS PASSED"
  exit 0
else
  echo "  Status: FAILURES FOUND"
  exit 1
fi
