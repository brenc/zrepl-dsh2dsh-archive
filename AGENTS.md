# AGENTS.md

## Project

Fork of zrepl (ZFS backup & replication). Go 1.26, module path `github.com/dsh2dsh/zrepl`.

## Setup

`make build/install` must run once before `lint`, `generate`, or `format`. It downloads protoc, golangci-lint, and Go tools (enumer, stringer, goimports) into `build/install/`.

## Commands

| Task | Command |
|------|---------|
| Build | `make zrepl-bin` (binary at `artifacts/zrepl-<os>-<arch>`) |
| Test | `make test-go` |
| Lint | `make lint` (requires `build/install`) |
| Vet | `make vet` |
| Format | `make format` (requires `build/install`; skips `*_enumer.go`) |
| Generate | `make generate` (runs `enumer`, `stringer`, protobuf — requires `build/install`) |
| All checks | `make vet && make lint && make test-go` |
| Docs | `make docs` (requires `uv`; Sphinx docs in `docs/`) |

### Running a single test

```sh
CGO_ENABLED=0 go test -mod=readonly ./internal/config/...
CGO_ENABLED=0 go test -mod=readonly -run TestFunctionName ./internal/endpoint/...
```

## Architecture

- `main.go` → `internal/cli` (cobra-based CLI with subcommands)
- `internal/daemon` — job orchestration, HTTP server, control socket, Prometheus
- `internal/daemon/job` — job types: snap, push, pull, sink, source
- `internal/config` — YAML config parsing (uses `go.yaml.in/yaml/v4`)
- `internal/endpoint` — ZFS abstraction layer
- `internal/replication` — replication driver and logic
- `internal/zfs` — ZFS CLI wrappers
- `internal/pruning` — snapshot pruning policies

## Code Generation

`//go:generate` directives produce `*_enumer.go` files via the `enumer` tool and `*_string.go` via `stringer`. These generated files are committed. Protobuf generation in the Makefile is stale (`.proto` files removed; PDU types are hand-written Go structs in `internal/replication/logic/pdu/`).

## Build Quirks

- All builds use `CGO_ENABLED=0`
- Linter config: `.golangci.yaml` v2 format with gofumpt (extra rules), goimports (local prefix `github.com/dsh2dsh/zrepl`), and many linters enabled
- `//nolint` directives must include a specific linter name and explanation (`nolintlint` config)
- `slog` logging must use attributes only (`sloglint: attr-only`)
- `wrapcheck` ignores errors from `github.com/dsh2dsh/zrepl/*` packages

## Platform Tests

`make test-platform` requires root + ZFS kernel module. It creates a test pool, runs integration tests, and cleans up. Cannot run without ZFS. CI runs these via CircleCI on Ubuntu VMs with ZFS built from source.

## Release

- GitHub Actions: goreleaser on `v*` tags (FreeBSD/Linux, amd64/arm64)
- CircleCI: full multi-arch Makefile build + deb/rpm packaging via Docker
