---
name: setup-repo-react
description: >
  Scaffold a minimal Vite + React (TypeScript) frontend repo for use as repo-react in Tendril test runs.
  Use when preparing the frontend repo for multi-repo plan testing (Section 3B.2, 6B.5).
allowed-tools: Bash Read Write Edit
effort: high
---

# setup-repo-react

Scaffold a minimal Vite + React (TypeScript) frontend repo for use as **repo-react** in Tendril test runs.

The repo must satisfy all Tendril verification gates:
- `npm run build` — Vite production build, exits 0
- `npm test` — Vitest component tests, at least one passing
- `npm run lint` — ESLint, exits 0

---

## Steps

### 1 — Scaffold with Vite

```bash
npm create vite@latest repo-react -- --template react-ts
cd repo-react
git init
git checkout -b main
npm install
```

### 2 — Install additional dev dependencies

```bash
npm install -D vitest @vitest/ui @testing-library/react @testing-library/jest-dom jsdom
```

### 3 — Update `vite.config.ts`

Use `vitest/config` as the import source (not `vite`) — this carries the
`test` property type without needing a triple-slash reference:

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: "./src/test-setup.ts",
  },
});
```

### 4 — Update `tsconfig.node.json` types

The Vite template puts `vite.config.ts` under `tsconfig.node.json`.
Add `"vitest/node"` so TypeScript resolves the test config types:

```json
"types": ["node", "vitest/node"],
```

Also add `"vitest/globals"` to `tsconfig.app.json` types:

```json
"types": ["vite/client", "vitest/globals"],
```

### 5 — Write `src/test-setup.ts`

```ts
import "@testing-library/jest-dom";
```

### 6 — Update `package.json` scripts

The Vite template generates `build: "tsc -b && vite build"` and
`lint: "eslint ."` (ESLint v9+ flat config — no `--ext` flag needed).
Only the `test` script needs adding:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "test": "vitest run",
    "preview": "vite preview"
  }
}
```

### 8 — Write `src/components/StatusBadge.tsx`

Create the `src/components/` directory first. A simple component to give the agent something meaningful to modify:

```tsx
interface Props {
  status: "pass" | "fail" | "skipped";
}

export function StatusBadge({ status }: Props) {
  const colors: Record<Props["status"], string> = {
    pass: "green",
    fail: "red",
    skipped: "gray",
  };
  return (
    <span style={{ color: colors[status], fontWeight: "bold" }}>
      {status.toUpperCase()}
    </span>
  );
}
```

### 9 — Write `src/components/StatusBadge.test.tsx`

```tsx
import { render, screen } from "@testing-library/react";
import { StatusBadge } from "./StatusBadge";

describe("StatusBadge", () => {
  it("renders PASS for pass status", () => {
    render(<StatusBadge status="pass" />);
    expect(screen.getByText("PASS")).toBeInTheDocument();
  });

  it("renders FAIL for fail status", () => {
    render(<StatusBadge status="fail" />);
    expect(screen.getByText("FAIL")).toBeInTheDocument();
  });

  it("renders SKIPPED for skipped status", () => {
    render(<StatusBadge status="skipped" />);
    expect(screen.getByText("SKIPPED")).toBeInTheDocument();
  });
});
```

### 10 — Verify

```bash
npm run build    # must exit 0
npm test         # must show 3 passing, 0 failing
npm run lint     # must exit 0
```

### 11 — Initial commit

```bash
git add -A
git commit -m "chore: initial repo-react scaffold"
```

### 12 — Push to GitHub

```bash
gh repo create repo-react --private --source=. --remote=origin --push
```

---

## Validation checklist

- [ ] `npm run build` exits 0 (produces `dist/`)
- [ ] `npm test` shows ≥ 3 passing tests, 0 failing
- [ ] `npm run lint` exits 0
- [ ] `git log --oneline` shows initial commit on `main`
- [ ] Repo accessible to Tendril's GitHub account
