---
name: setup-repo-go
description: >
  Scaffold a minimal Go HTTP server repo for use as repo-go in Tendril test runs.
  Use when preparing the cross-agent parity target repo (Section 5D) or the minimum required exit-criteria repo.
allowed-tools: Bash Read Write Edit
effort: high
---

# setup-repo-go

Scaffold a minimal Go HTTP server repo for use as **repo-go** in Tendril test runs.

This repo is the primary cross-agent parity target (Section 5D). Keep changes agent-safe: adding a README or a helper function must not break `go build ./...`.

The repo must satisfy all Tendril verification gates:
- `go build ./...` — exits 0
- `go test ./...` — at least one passing test
- `golangci-lint run` — exits 0

---

## Steps

### 1 — Create the repo

```bash
mkdir repo-go && cd repo-go
git init
git checkout -b main
go mod init github.com/<org>/repo-go
```

### 2 — Write `main.go`

```go
package main

import (
	"log"
	"net/http"

	"github.com/<org>/repo-go/internal/handler"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handler.Health)
	mux.HandleFunc("/items", handler.Items)

	log.Println("Listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatal(err)
	}
}
```

### 3 — Write `internal/handler/handler.go`

```go
package handler

import (
	"encoding/json"
	"net/http"
)

func Health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func Items(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"items": []any{}})
}
```

### 4 — Write `internal/handler/handler_test.go`

```go
package handler_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/<org>/repo-go/internal/handler"
)

func TestHealth(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	handler.Health(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var body map[string]string
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body["status"] != "ok" {
		t.Fatalf("expected status=ok, got %q", body["status"])
	}
}

func TestItems(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/items", nil)
	w := httptest.NewRecorder()
	handler.Items(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
}
```

### 5 — Write `.golangci.yml`

```yaml
version: "2"  # required by golangci-lint v2+

linters:
  enable:
    - errcheck
    - govet
    - ineffassign
    - staticcheck  # absorbs gosimple and unused in v2

issues:
  max-issues-per-linter: 0
  max-same-issues: 0
```

### 6 — Write `.gitignore`

```
repo-go
dist/
```

### 7 — Build and verify

```bash
go mod tidy
go build ./...         # must exit 0
go test ./...          # must show PASS
golangci-lint run      # must exit 0  (install: brew install golangci-lint)
```

### 8 — Initial commit

```bash
git add -A
git commit -m "chore: initial repo-go scaffold"
```

### 9 — Push to GitHub

```bash
gh repo create repo-go --private --source=. --remote=origin --push
```

---

## Notes for cross-agent parity (Section 5D)

When testing agents against this repo, use a safe, low-risk change such as:
- Adding a `README.md` with project description
- Adding a pure helper function in `internal/util/util.go`
- Adding a new endpoint that follows the existing pattern

Avoid changes that require new dependencies or modify `go.mod`, as these may fail for agents with restricted network access.

---

## Validation checklist

- [ ] `go build ./...` exits 0
- [ ] `go test ./...` shows PASS for all tests
- [ ] `golangci-lint run` exits 0
- [ ] `git log --oneline` shows initial commit on `main`
- [ ] Repo accessible to Tendril's GitHub account
