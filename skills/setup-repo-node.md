# setup-repo-node

Scaffold a minimal Express/Node.js REST API repo for use as **repo-node** in Tendril test runs.

The repo must satisfy all Tendril verification gates:
- `npm run build` — TypeScript compile, exits 0
- `npm test` — at least one passing test (Vitest)
- `npm run lint` — ESLint, exits 0

---

## Steps

### 1 — Create the repo

```bash
mkdir repo-node && cd repo-node
git init
git checkout -b main
```

### 2 — Write `package.json`

```json
{
  "name": "repo-node",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "tsc --noEmit",
    "start": "node dist/index.js",
    "test": "vitest run",
    "lint": "eslint \"src/**/*.ts\""
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.11.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.56.0",
    "typescript": "^5.3.3",
    "vitest": "^1.2.0"
  }
}
```

### 3 — Write `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

### 4 — Write `.eslintrc.json`

```json
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "env": { "node": true }
}
```

### 5 — Write `src/app.ts`

```ts
import express, { Request, Response } from "express";

export const app = express();
app.use(express.json());

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok" });
});

app.get("/items", (_req: Request, res: Response) => {
  res.json({ items: [] });
});
```

### 6 — Write `src/index.ts`

```ts
import { app } from "./app";

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 7 — Write `src/app.test.ts`

```ts
import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "./app";

describe("GET /health", () => {
  it("returns status ok", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
  });
});

describe("GET /items", () => {
  it("returns empty array", async () => {
    const res = await request(app).get("/items");
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.items)).toBe(true);
  });
});
```

Add `supertest` to devDependencies: `"supertest": "^6.3.4"`, `"@types/supertest": "^6.0.2"`.

### 8 — Write `.gitignore`

```
node_modules/
dist/
```

### 9 — Install and verify

```bash
npm install
npm run build    # must exit 0
npm test         # must show all tests passing
npm run lint     # must exit 0
```

### 10 — Initial commit

```bash
git add -A
git commit -m "chore: initial repo-node scaffold"
```

### 11 — Push to GitHub (if needed for Tendril)

```bash
gh repo create repo-node --private --source=. --remote=origin --push
```

---

## Validation checklist

- [ ] `npm run build` exits 0
- [ ] `npm test` shows ≥ 2 passing tests, 0 failing
- [ ] `npm run lint` exits 0
- [ ] `git log --oneline` shows initial commit on `main`
- [ ] Repo is accessible to the GitHub account Tendril uses
