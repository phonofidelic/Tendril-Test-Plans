---
name: setup-repo-python
description: >
  Scaffold a minimal FastAPI app repo for use as repo-python in Tendril test runs.
  Use when preparing the Python test repo for project inference and per-project stats testing.
allowed-tools: Bash Read Write Edit
license: MIT
metadata:
  effort: high
---

# setup-repo-python

Scaffold a minimal FastAPI app repo for use as **repo-python** in Tendril test runs.

The repo must satisfy all Tendril verification gates:
- `python -m build` or `pip install -e .` — exits 0
- `pytest` — at least one passing test
- `ruff check .` — exits 0

---

## Steps

### 1 — Create the repo

```bash
mkdir repo-python && cd repo-python
git init
git checkout -b main
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
```

### 2 — Write `pyproject.toml`

```toml
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "repo-python"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110.0",
    "uvicorn[standard]>=0.27.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "httpx>=0.27.0",
    "ruff>=0.3.0",
]

[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### 3 — Write `src/app.py`

```python
from fastapi import FastAPI

app = FastAPI(title="repo-python")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/items")
def list_items() -> dict:
    return {"items": []}
```

### 4 — Write `tests/test_app.py`

```python
import pytest
from httpx import ASGITransport, AsyncClient

from src.app import app


@pytest.mark.anyio
async def test_health():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.anyio
async def test_list_items():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/items")
    assert response.status_code == 200
    assert response.json() == {"items": []}
```

Add `anyio[trio]>=4.3.0` to dev dependencies and `pytest-anyio>=0.0.0` (use `anyio` pytest plugin).

### 5 — Write `src/__init__.py` and `tests/__init__.py`

Both files can be empty.

### 6 — Write `.gitignore`

```
.venv/
__pycache__/
*.egg-info/
dist/
.pytest_cache/
.ruff_cache/
```

### 7 — Install and verify

```bash
pip install -e ".[dev]"
python -m pytest          # must show all tests passing
ruff check .              # must exit 0
```

### 8 — Initial commit

```bash
git add -A
git commit -m "chore: initial repo-python scaffold"
```

### 9 — Push to GitHub

```bash
gh repo create repo-python --private --source=. --remote=origin --push
```

---

## Validation checklist

- [ ] `pip install -e ".[dev]"` exits 0
- [ ] `pytest` shows ≥ 2 passing tests, 0 failing
- [ ] `ruff check .` exits 0
- [ ] `git log --oneline` shows initial commit on `main`
- [ ] Repo accessible to Tendril's GitHub account
