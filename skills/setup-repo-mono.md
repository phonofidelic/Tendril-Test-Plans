# setup-repo-mono

Scaffold a minimal monorepo (two packages) for use as **repo-mono** in Tendril test runs.

This repo tests Tendril's multi-repo plan support (test 3B.2, 6B.5). It uses npm workspaces with two packages:
- `packages/api` — a minimal Express REST API (Node.js)
- `packages/shared` — a shared utilities library consumed by `api`

The repo must satisfy all Tendril verification gates:
- `npm run build` — builds both packages, exits 0
- `npm test` — runs tests in both packages, all passing
- `npm run lint` — lints both packages, exits 0

---

## Steps

### 1 — Create the repo

```bash
mkdir repo-mono && cd repo-mono
git init
git checkout -b main
```

### 2 — Write root `package.json`

```json
{
  "name": "repo-mono",
  "version": "1.0.0",
  "private": true,
  "workspaces": ["packages/*"],
  "scripts": {
    "build": "npm run build -w @repo-mono/shared && npm run build -w @repo-mono/api",
    "test":  "npm run test  --workspaces",
    "lint":  "npm run lint  --workspaces"
  },
  "devDependencies": {
    "typescript": "^5.3.3"
  }
}
```

### 3 — Scaffold `packages/shared`

**`packages/shared/package.json`**
```json
{
  "name": "@repo-mono/shared",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test":  "vitest run",
    "lint":  "eslint \"src/**/*.ts\""
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.56.0",
    "vitest": "^1.2.0"
  }
}
```

**`packages/shared/tsconfig.json`**
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "declaration": true,
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "skipLibCheck": true
  }
}
```

**`packages/shared/.eslintrc.json`**
```json
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "env": { "node": true }
}
```

**`packages/shared/src/index.ts`**
```ts
export function formatStatus(status: string): string {
  return status.trim().toLowerCase();
}

export function isValidStatus(status: string): boolean {
  return ["pass", "fail", "skipped"].includes(formatStatus(status));
}
```

**`packages/shared/src/index.test.ts`**
```ts
import { describe, it, expect } from "vitest";
import { formatStatus, isValidStatus } from "./index";

describe("formatStatus", () => {
  it("lowercases and trims", () => {
    expect(formatStatus("  PASS  ")).toBe("pass");
  });
});

describe("isValidStatus", () => {
  it("accepts valid statuses", () => {
    expect(isValidStatus("pass")).toBe(true);
    expect(isValidStatus("fail")).toBe(true);
    expect(isValidStatus("skipped")).toBe(true);
  });

  it("rejects unknown statuses", () => {
    expect(isValidStatus("unknown")).toBe(false);
  });
});
```

### 4 — Scaffold `packages/api`

**`packages/api/package.json`**
```json
{
  "name": "@repo-mono/api",
  "version": "1.0.0",
  "scripts": {
    "build": "tsc --noEmit",
    "test":  "vitest run",
    "lint":  "eslint \"src/**/*.ts\""
  },
  "dependencies": {
    "@repo-mono/shared": "*",
    "express": "^4.18.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.11.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.56.0",
    "vitest": "^1.2.0"
  }
}
```

**`packages/api/.eslintrc.json`**
```json
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "env": { "node": true }
}
```

**`packages/api/tsconfig.json`**
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

**`packages/api/src/app.ts`**
```ts
import express from "express";
import { isValidStatus } from "@repo-mono/shared";

export const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/validate-status", (req, res) => {
  const { status } = req.body as { status: string };
  res.json({ valid: isValidStatus(status) });
});
```

**`packages/api/src/app.test.ts`**
```ts
import { describe, it, expect } from "vitest";
import { isValidStatus } from "@repo-mono/shared";

describe("isValidStatus (via shared)", () => {
  it("returns true for pass", () => {
    expect(isValidStatus("pass")).toBe(true);
  });
  it("returns false for garbage", () => {
    expect(isValidStatus("garbage")).toBe(false);
  });
});
```

### 5 — Add root `.gitignore`

```
node_modules/
dist/
```

### 6 — Install and verify

```bash
npm install
npm run build    # must exit 0
npm test         # must show all tests passing across both packages
npm run lint     # must exit 0
```

### 7 — Initial commit

```bash
git add -A
git commit -m "chore: initial repo-mono scaffold"
```

### 8 — Push to GitHub

```bash
gh repo create repo-mono --private --source=. --remote=origin --push
```

---

## Notes for multi-repo plan testing (3B.2, 6B.5)

When describing a plan that spans repos, reference this repo alongside **repo-react** (or **repo-node**). For example:
> "Add a `formatStatus` export to the shared package and use it in a new React component in repo-react."

Tendril should resolve both repos into the plan's `repos` field and create worktrees for each.

---

## Validation checklist

- [ ] `npm run build` exits 0 for both packages
- [ ] `npm test` shows ≥ 4 passing tests across both packages, 0 failing
- [ ] `npm run lint` exits 0 for both packages
- [ ] `git log --oneline` shows initial commit on `main`
- [ ] Repo accessible to Tendril's GitHub account
