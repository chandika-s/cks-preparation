# Week 5 · Day 8 (Oct 27) — Review & self-quiz — Answers
Task: [day-08-review-self-quiz.md](../../plan/week-05-supply-chain-security/day-08-review-self-quiz.md)

## Solution
1. Multi-stage distroless:
```
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server main.go

FROM gcr.io/distroless/static:nonroot
COPY --from=build /server /server
USER 65532:65532
ENTRYPOINT ["/server"]
```
```
docker build -t quiz-go:1 .
docker images quiz-go:1
docker inspect quiz-go:1 --format '{{.Config.User}}'
```
2. Trivy:
```
trivy image --severity HIGH,CRITICAL nginx:1.18
trivy image -q --severity CRITICAL --ignore-unfixed --exit-code 1 nginx:1.18; echo $?
```
Remediation template: "CVE-X in `<pkg>` `<installed>` fixed in `<fixed>`: rebuild on a maintained base (e.g. `nginx:stable-alpine` / current tag), or `apt-get install --only-upgrade <pkg>`; re-scan to confirm."

3. Registry policy:
```
kubectl create ns quiz-reg
```
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: quiz-allowed-registries
spec:
  background: false
  rules:
  - name: allowed-registries
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["quiz-reg"]
    validate:
      failureAction: Enforce
      message: "Only docker.io/library/ and registry.k8s.io/ images are allowed"
      pattern:
        spec:
          =(ephemeralContainers):
          - image: "docker.io/library/* | registry.k8s.io/*"
          =(initContainers):
          - image: "docker.io/library/* | registry.k8s.io/*"
          containers:
          - image: "docker.io/library/* | registry.k8s.io/*"
```
```
kubectl apply -f quiz-registries.yaml
kubectl -n quiz-reg run bad --image=quay.io/nginx/nginx-unprivileged:latest
kubectl -n quiz-reg run ok --image=docker.io/library/nginx:1.27
kubectl -n quiz-reg run ok2 --image=registry.k8s.io/pause:3.9
```
4. End to end (details in Day 6 answer):
```
docker run -d --restart=always --name registry -p 127.0.0.1:5000:5000 registry:2
docker network connect kind registry
docker tag quiz-go:1 localhost:5000/app:v1 && docker push localhost:5000/app:v1
docker pull busybox:1.36 && docker tag busybox:1.36 localhost:5000/app:unsigned && docker push localhost:5000/app:unsigned
DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' localhost:5000/app:v1 | sed 's/.*@//')
COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --key cosign.key --tlog-upload=false --yes localhost:5000/app@$DIGEST
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5000/app@$DIGEST
kubectl -n kyverno patch deploy kyverno-admission-controller --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--allowInsecureRegistry=true"}]'
kubectl create ns quiz-signed
```
Apply the Day 6 `verifyImages` policy renamed `quiz-require-signed` with `namespaces: ["quiz-signed"]` and your `cosign.pub`, then:
```
kubectl -n quiz-signed run unsigned --image=registry:5000/app:unsigned
kubectl -n quiz-signed run signed --image=registry:5000/app:v1
```
(Skip the `--allowInsecureRegistry` patch if already applied; `args/-` would duplicate the flag, which is harmless but untidy.)

5. Fixed manifest `quiz-fixed.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: quiz-sa
  namespace: default
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quiz
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: quiz
  template:
    metadata:
      labels:
        app: quiz
    spec:
      serviceAccountName: quiz-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: quiz
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "3600"]
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 50m
            memory: 32Mi
        livenessProbe:
          exec:
            command: ["true"]
        readinessProbe:
          exec:
            command: ["true"]
```
```
kube-linter lint quiz-fixed.yaml; echo $?
kubesec scan quiz-fixed.yaml | jq '.[] | {object, score, critical: .scoring.critical}'
```
6. Explanations:
- (a) A tag is a mutable pointer that can be re-pointed to different content; a digest is the hash of the manifest, so pinning it guarantees the exact bytes and lets signatures and scan results remain valid for what runs.
- (b) A cosign signature is over a specific digest; `v2` has a different digest, so it needs its own signature (a compromised or unsigned rebuild cannot inherit trust from `v1`).
- (c) An SBOM is a persistent component inventory: answer "which images contain package X at version Y" immediately for a new CVE, audit licences, and re-scan later without the image; a scan is a point-in-time judgement against today's DB.

## Expected output
- Item 1: `quiz-go:1` about 8-10 MB, user `65532:65532`.
- Item 2: exit code `1`.
- Item 3: `bad` denied with the message; `ok` and `ok2` admitted (`ok2` may not go Running if the pause image's command exits; admission is what matters).
- Item 4: as Day 6; unsigned denied, signed admitted with a digest-mutated image.
- Item 5: `No lint errors found!` and empty Kubesec critical list.

## Why it works
Same mechanisms as Days 1-7: minimal images shrink the CVE surface, Trivy/Syft inspect image contents, admission policy restricts and verifies what may run, and static analysis catches insecure manifests before apply.

## Common mistakes / exam gotchas
- Wrong stage name in `COPY --from`; dynamic binary in distroless.
- Missing `--exit-code 1`; using `--severity` inclusively wrong.
- Kyverno pattern without initContainers; short image names not matching; forgetting `kubectl create` for the install.
- cosign: signing a tag then verifying another digest; using `localhost:5000` inside the cluster; missing tlog flags in an offline lab.
- Kubesec/KubeLinter: `runAsNonRoot` without numeric UID; read-only root filesystem without writable volumes; required anti-affinity on a two-node kind cluster.
- Second-pass list: note every item you missed and redo it in a fresh directory next day.

## Cleanup
```
kubectl delete clusterpolicy quiz-allowed-registries quiz-require-signed --ignore-not-found
kubectl delete ns quiz-reg quiz-signed --ignore-not-found
kubectl delete deploy quiz --ignore-not-found
kubectl delete sa quiz-sa --ignore-not-found
docker rm -f registry 2>/dev/null
```
