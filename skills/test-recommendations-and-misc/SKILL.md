---
name: test-recommendations-and-misc
description: >
  Run Sections 9 (Recommendations), 11 (Config Editor), and 12 (Agent Playground) of the Tendril development branch test plan.
  Use when testing AI-generated recommendations, raw config editing, and the AgentApp live session.
allowed-tools: Bash Read
license: MIT
metadata:
  effort: medium
---

# test-recommendations-and-misc

Run Sections 9 (Recommendations), 11 (Config Editor), and 12 (Agent Playground) of the Tendril development branch test plan.

**Prerequisites:**
- Multiple completed plans in Tendril (run Sections 5–6 first to generate history)
- Tendril running on `development` branch

---

## Section 9 — Recommendations

### 9.1 — Recommendation appears

1. Navigate to `RecommendationsApp`.
2. (Recommendations are AI-generated from plan history; several completed plans must exist.)
3. **Expected:** At least one AI-generated suggestion is visible, with:
   - A description of the recommendation.
   - Impact metadata (e.g., High / Medium / Low).
   - Risk metadata.
4. ✅ Pass if at least one recommendation with impact+risk metadata is shown.
5. ℹ️ If no recommendations appear, complete more end-to-end plan runs and return.

### 9.2 — Approve recommendation

1. Click **Approve** on a recommendation.
2. **Expected:** The recommendation converts to a `Draft` plan in `DraftsApp`.
3. Verify the new plan's title/description matches the recommendation content.
4. ✅ Pass if plan appears in DraftsApp.

### 9.3 — Decline with notes

1. Click **Decline** on a recommendation.
2. Add a reason: *"Not a priority this sprint."*
3. **Expected:**
   - Recommendation is removed from the list.
   - Decline notes are preserved (visible in a declined/archived state if one exists).
4. ✅ Pass if recommendation disappears from the active list.

---

## Section 11 — Config Editor & Raw Config

### 11.1 — Open raw config

1. Navigate to Config Editor (typically via nav → **Config**).
2. **Expected:** The contents of `config.yaml` are displayed in an editable text field or code editor.
3. ✅ Pass if file contents are rendered.

### 11.2 — Edit and save valid YAML

1. Make a minor, non-destructive change (e.g., update a comment or a label string value).
2. Click **Save**.
3. **Expected:**
   - Config is saved without errors.
   - The change is reflected in the Settings UI (e.g., the label updates).
4. ✅ Pass if change persists and round-trips to Settings UI.

### 11.3 — Save invalid YAML

1. Introduce a deliberate YAML syntax error (e.g., `key: [unclosed`).
2. Click **Save**.
3. **Expected:**
   - `ConfigErrorApp` (or an inline error state) loads with a legible parse error message.
   - The previous valid config is **not** overwritten.
4. Verify: open the raw file and confirm original content is intact.
5. ✅ Pass if error is shown and original file is unchanged.

---

## Section 12 — Agent Playground (AgentApp)

### 12.1 — Start live session

1. Navigate to `AgentApp`.
2. Select an agent (Claude Code / balanced) and a project (repo-node).
3. Click **Start**.
4. **Expected:** The agent spawns; output begins streaming in real time in the output panel.
5. ✅ Pass if output appears within a few seconds of starting.

### 12.2 — Send message mid-session

1. With a live session running (12.1):
2. Type a prompt in the message input: *"List all files in the src directory."*
3. Submit the message.
4. **Expected:**
   - Agent receives the prompt and responds.
   - Cost counter updates after the response.
5. ✅ Pass if response appears and cost is non-zero.

### 12.3 — Stop session

1. Click **Stop** on the active session.
2. **Expected:**
   - Agent process terminates cleanly (no zombie process).
   - Session log is preserved and viewable after stopping.
3. Verify: `ps aux | grep claude` (or the agent binary name) shows no orphaned process.
4. ✅ Pass if process is gone and log is readable.

---

## Validation checklist

- [ ] 9.1: Recommendation visible with impact + risk metadata
- [ ] 9.2: Approved recommendation becomes a Draft plan
- [ ] 9.3: Declined recommendation removed from list
- [ ] 11.1: Raw config displayed in Config Editor
- [ ] 11.2: Valid YAML edit saved and reflected in Settings UI
- [ ] 11.3: Invalid YAML shows error; original config not overwritten
- [ ] 12.1: Agent spawns and output streams in AgentApp
- [ ] 12.2: Mid-session prompt triggers response and cost update
- [ ] 12.3: Stop terminates process cleanly; session log preserved
