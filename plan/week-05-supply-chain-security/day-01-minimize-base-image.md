# Week 5 · Day 1 (Oct 20) — Minimize base image footprint
**Domain:** Supply Chain Security (20%) — Minimize base image footprint | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Rewrite a single-stage, fat-base Dockerfile as a multi-stage build ending in a distroless (or `scratch`) runtime image.
- Quantify the size reduction with `docker images`.
- Quantify the CVE reduction with `trivy image`.

## Theory
Smaller base images (distroless, `scratch`, alpine) ship fewer packages, so fewer CVEs and a smaller attack surface: no shell, no package manager, no `curl`/`wget` for an attacker to reuse after compromise.

- **Multi-stage build:** several `FROM` stages in one Dockerfile. Early stages carry the full toolchain (compilers, SDKs); only the final artifact is copied into the last stage with `COPY --from=<stage>`. Only the last stage becomes the image.
- **`scratch`:** empty image. Works for fully static binaries (`CGO_ENABLED=0` for Go). No CA certs, no `/etc/passwd`, no tzdata unless copied in.
- **distroless** (`gcr.io/distroless/static`, `base`, `java`, `python3`, `nodejs`): only the app runtime plus minimal files (CA certs, tzdata, `/etc/passwd`). Tags `:nonroot` and `:debug` (has busybox shell) exist. `static` is for static binaries; `base` adds glibc.
- **alpine:** small (~5 MB) with musl and `apk`; still has a shell and package manager.
- Other footprint rules: pin tags/digests (no `:latest`), run as non-root (`USER`), do not `COPY` secrets, remove package caches in the same `RUN` layer, use `.dockerignore`, drop build tools from the final stage.
- Key commands: `docker build -t name:tag .`, `docker images`, `docker history <image>`, `trivy image <image>`, `kind load docker-image <image> --name cks`.
- Go static build: `CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server main.go`.

## Prerequisites
None. Needs `docker`, `trivy`, and `kind` on the host. Work in `workspace/week-05/day-01/` (create it).

## Task
1. Create `workspace/week-05/day-01/main.go`:
   ```go
   package main

   import (
   	"fmt"
   	"net/http"
   )

   func main() {
   	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
   		fmt.Fprintln(w, "hello")
   	})
   	http.ListenAndServe(":8080", nil)
   }
   ```
2. Create `Dockerfile.fat` in the same directory:
   ```
   FROM ubuntu:22.04
   RUN apt-get update && apt-get install -y golang-go
   COPY main.go /app/main.go
   WORKDIR /app
   RUN go build -o server main.go
   EXPOSE 8080
   CMD ["/app/server"]
   ```
   Build it as `hello-go:fat`.
3. Write `Dockerfile.slim` as a multi-stage build:
   - Build stage: `golang:1.24-alpine`, named `build`, producing a statically linked, stripped binary at `/server`.
   - Final stage: `gcr.io/distroless/static` (the `nonroot` variant), containing only the binary, running as a non-root user, exposing 8080.
   - Build it as `hello-go:slim`.
4. Optionally add `Dockerfile.scratch` (final stage `FROM scratch`), tag `hello-go:scratch`.
5. Run `docker images hello-go` and record the sizes of all variants in `workspace/week-05/day-01/results.txt`.
6. Run `trivy image` on `hello-go:fat` and `hello-go:slim`. Record total vulnerability counts and HIGH/CRITICAL counts for both in `results.txt`.
7. Load `hello-go:slim` into the `cks` kind cluster and run it as pod `hello` in namespace `default` with `imagePullPolicy: IfNotPresent`. Reach it via `kubectl port-forward` and `curl`.
8. Prove the runtime image has no shell.

## Check your work
- `docker images hello-go` shows `slim` at least two orders of magnitude smaller than `fat` (tens of MB vs hundreds of MB; `slim` roughly under 15 MB).
- `docker history hello-go:slim` shows few layers and no `apt`/`go` layers.
- Trivy reports strictly fewer findings for `slim` than `fat` (note: Go stdlib CVEs in the binary appear in both).
- `curl localhost:<port>` through the port-forward prints `hello`.
- `docker run --rm --entrypoint sh hello-go:slim` fails (no such file); `kubectl exec hello -- sh` fails.
- `docker inspect hello-go:slim --format '{{.Config.User}}'` is non-empty and non-root (e.g. `65532:65532`).

## Answer
[answers/week-05-supply-chain-security/day-01-minimize-base-image.md](../../answers/week-05-supply-chain-security/day-01-minimize-base-image.md) — Attempt the task first; only then open the answer.

## Cleanup
Keep `hello-go:fat` and `hello-go:slim` locally; Days 2, 3 and 6 reuse them. Delete the pod: `kubectl delete pod hello`.
