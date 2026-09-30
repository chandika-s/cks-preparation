# Week 5 · Day 8 (Oct 27) — Review & self-quiz
**Domain:** Supply Chain Security (20%) — all curriculum items | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Reproduce every Week 5 skill from memory, under time limits.
- Identify weak spots (flags, YAML structure, kind-specific plumbing) for follow-up.

## Theory
Fast recall map:
- **Minimize footprint:** multi-stage `FROM ... AS build` then `COPY --from=build`; static binary (`CGO_ENABLED=0`); final `gcr.io/distroless/static:nonroot` or `scratch`; `USER` non-root; `docker images`; `trivy image`.
- **Trivy:** `trivy image --severity HIGH,CRITICAL [--ignore-unfixed] [--exit-code 1] <img>`; `-f json | jq`; remediation = newer base, package upgrade, or dependency bump.
- **SBOM:** `syft <img> -o table`, `-o cyclonedx-json`, `trivy sbom`.
- **Kyverno:** `kubectl create -f install.yaml`; `ClusterPolicy` -> `rules[].match`, `validate.failureAction`, `pattern` with `image: "registry/*"`; include init/ephemeral containers; full image names.
- **cosign:** `generate-key-pair`, `sign --key`, `verify --key`; Kyverno `verifyImages` with `imageReferences`, `attestors.entries.keys.publicKeys`; signatures bind to digests.
- **Static analysis:** `kubesec scan f.yaml`, `kube-linter lint f.yaml`; fix securityContext, resources, probes, no hostNetwork/privileged/docker.sock.
- ImagePolicyWebhook: apiserver `--enable-admission-plugins=ImagePolicyWebhook` and `--admission-control-config-file`.

## Prerequisites
Kyverno installed (Day 5). Docker, trivy, syft, cosign, kubesec, kube-linter on the host. Docker registry `registry:2` is not needed unless you do item 4 (start it again). Start each item from a clean directory `workspace/week-05/day-08/` with no notes open; time-box each item.

## Exam-style question
Context: the `cks` cluster has Kyverno installed, and Docker, Trivy, Syft, cosign, Kubesec and KubeLinter are available on the host. Task: working from a clean `workspace/week-05/day-08/`, and within the time limit given for each item, rebuild `quiz-go:1` as a minimal non-root distroless image under 15 MB, and block images outside `docker.io/library/` and `registry.k8s.io/` in namespace `quiz-reg` with policy `quiz-allowed-registries`. Also enforce cosign `verifyImages` in namespace `quiz-signed`, and fix the insecure Deployment `quiz` into `quiz-fixed.yaml`. Requirements: no reference to earlier solutions, and each policy must be demonstrated with one rejected and one admitted pod.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Complete each item cold (no reference to previous solutions) within its time box:

1. (10 min) Given this single-stage Dockerfile and `main.go` from Day 1, write `Dockerfile` as a minimal multi-stage distroless build (non-root, static binary, stripped), build it as `quiz-go:1`, and show the image is smaller than 15 MB.
   ```
   FROM ubuntu:22.04
   RUN apt-get update && apt-get install -y golang-go
   COPY main.go /app/main.go
   WORKDIR /app
   RUN go build -o server main.go
   CMD ["/app/server"]
   ```
2. (10 min) Run Trivy on `nginx:1.18`. Write down one HIGH or CRITICAL CVE with a fix, the package and version fixed, and the exact remediation. Then produce a Trivy command that fails a pipeline (exit code 1) on CRITICAL only, ignoring unfixed.
3. (10 min) Create namespace `quiz-reg` and a Kyverno `ClusterPolicy` `quiz-allowed-registries` that blocks any Pod in it whose containers, init containers or ephemeral containers do not use `docker.io/library/` or `registry.k8s.io/`. Prove it with one rejected and one accepted pod.
4. (20 min) End to end: start a local registry, push an image, create a cosign key pair, sign the image by digest, verify it, and enforce a Kyverno `verifyImages` policy in namespace `quiz-signed` so an unsigned image is rejected and the signed one is admitted.
5. (10 min) Run Kubesec and KubeLinter on this manifest and fix every finding. Save as `quiz-fixed.yaml`:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: quiz
     namespace: default
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: quiz
     template:
       metadata:
         labels:
           app: quiz
       spec:
         hostPID: true
         containers:
         - name: app
           image: busybox:latest
           command: ["sleep", "3600"]
           securityContext:
             privileged: true
             capabilities:
               add: ["SYS_ADMIN"]
   ```
6. (5 min, spoken/written) Explain: (a) why digest pinning beats tag pinning; (b) why a signature on `app:v1` does not protect `app:v2`; (c) what an SBOM lets you do that a scan does not.

## Check your work
- Item 1: `docker images quiz-go:1` under 15 MB, `docker history` has no toolchain layers, `docker inspect` shows a non-root user.
- Item 2: CVE, package, fixed version documented; command exits non-zero on `nginx:1.18`.
- Item 3: rejected pod shows Kyverno policy message; accepted pod is Running; `registry.k8s.io/pause:3.9` is also admitted.
- Item 4: `cosign verify` succeeds on signed image and fails on unsigned; the unsigned pod is rejected by Kyverno and the signed pod admitted.
- Item 5: KubeLinter exit code 0 (or only justified exclusions) and Kubesec critical list empty with positive score.
- Item 6: answers mention mutable tags vs content-addressed digests, per-digest signatures, and inventory / fast affected-component lookup.
- Any item you could not finish in its time box goes into a "redo tomorrow" list.

## Answer
[answers/week-05-supply-chain-security/day-08-review-self-quiz.md](../../answers/week-05-supply-chain-security/day-08-review-self-quiz.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete clusterpolicy quiz-allowed-registries quiz-require-signed --ignore-not-found
kubectl delete ns quiz-reg quiz-signed --ignore-not-found
kubectl delete deploy quiz --ignore-not-found
docker rm -f registry 2>/dev/null
```
