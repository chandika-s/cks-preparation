# Week 5 · Day 1 (Oct 20) — Minimize base image footprint — Answers
Task: [day-01-minimize-base-image.md](../../plan/week-05-supply-chain-security/day-01-minimize-base-image.md)

## Solution
1-2. Create `main.go` and `Dockerfile.fat` as given, then:
```
cd workspace/week-05/day-01
docker build -f Dockerfile.fat -t hello-go:fat .
```
3. `Dockerfile.slim`:
```
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server main.go

FROM gcr.io/distroless/static:nonroot
COPY --from=build /server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
```
```
docker build -f Dockerfile.slim -t hello-go:slim .
```
4. `Dockerfile.scratch`: identical build stage; final stage:
```
FROM scratch
COPY --from=build /server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
```
```
docker build -f Dockerfile.scratch -t hello-go:scratch .
```
5. Sizes:
```
docker images hello-go
docker images hello-go > results.txt
```
6. Trivy:
```
trivy image hello-go:fat
trivy image hello-go:slim
trivy image --severity HIGH,CRITICAL -q hello-go:fat | tail -5
trivy image --severity HIGH,CRITICAL -q hello-go:slim | tail -5
trivy image -q -f json hello-go:slim | jq '[.Results[]?.Vulnerabilities[]?] | length'
```
Append counts to `results.txt`.

7. Kind:
```
kind load docker-image hello-go:slim --name cks
kubectl run hello --image=hello-go:slim --image-pull-policy=IfNotPresent
kubectl wait --for=condition=Ready pod/hello --timeout=60s
kubectl port-forward pod/hello 8080:8080 &
curl -s localhost:8080
kill %1
```
8. No shell:
```
docker run --rm --entrypoint sh hello-go:slim
kubectl exec hello -- sh
```

## Expected output
```
REPOSITORY   TAG       IMAGE ID       SIZE
hello-go     fat       ...            ~700-900MB
hello-go     slim      ...            ~8-10MB
hello-go     scratch   ...            ~4-6MB
```
`curl` prints `hello`. The `sh` attempts fail with `executable file not found in $PATH` / `exec: "sh": ...not found`. Trivy for `slim` lists the distroless OS layer (few or zero OS findings) plus any Go stdlib findings against the binary; `fat` lists many Ubuntu package findings.

## Why it works
Only the last stage ends up in the image; the Go toolchain, apt caches and source stay in the discarded `build` stage. `CGO_ENABLED=0` yields a static binary that needs no libc, so `static`/`scratch` suffice. Fewer packages means fewer scannable components, hence fewer CVEs, and no shell removes post-exploitation tooling.

## Common mistakes / exam gotchas
- Forgetting `CGO_ENABLED=0`: binary links glibc dynamically and the container dies with `exec /server: no such file or directory` on distroless/scratch.
- Using `distroless/base`/`cc` when `static` is enough.
- Final stage left as root: add `USER` or use the `:nonroot` tag. In a pod, also set `runAsNonRoot: true`; numeric UID is required for the kubelet to verify it.
- `COPY --from=build` must reference the stage name (`AS build`) or index, and the path from inside that stage.
- kind nodes do not see the host docker images: `kind load docker-image ... --name cks`, and use `imagePullPolicy: IfNotPresent` (a `:latest` tag defaults to `Always` and fails).
- `scratch` has no CA bundle: HTTPS calls fail unless you copy `/etc/ssl/certs/ca-certificates.crt`.
- Debugging distroless: use `gcr.io/distroless/static:debug` or `kubectl debug` with an ephemeral container.

## Cleanup
```
kubectl delete pod hello
```
Keep the images for Days 2, 3, 6.
