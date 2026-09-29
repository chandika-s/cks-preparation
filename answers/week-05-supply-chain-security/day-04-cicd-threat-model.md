# Week 5 · Day 4 (Oct 23) — CI/CD and artifact repository security (conceptual) — Answers
Task: [day-04-cicd-threat-model.md](../../plan/week-05-supply-chain-security/day-04-cicd-threat-model.md)

## Solution
1. Model `threat-model.md`:

| Stage | Attack | Mitigation |
|---|---|---|
| Source | Attacker with a stolen developer token pushes a malicious commit directly to `main` (or a typosquatted dependency is added) | Branch protection with required reviews, signed commits, MFA; lockfiles plus dependency scanning |
| Build | Compromised shared runner injects a backdoor and pushes a tampered image as `myapp:1.4.2` | Ephemeral, isolated per-job runners with least-privilege short-lived credentials; base images pinned by digest; scan + SBOM + provenance emitted in the pipeline |
| Artifact storage | Mutable tag overwritten in the registry, or stolen registry credentials used to push | Private registry with RBAC, immutable tags, sign images with cosign at push, scan on push |
| Deploy | Cluster pulls an image that never went through CI (e.g. from a public registry or a re-pointed tag) | Admission policy: allow-listed registries plus signature verification (Kyverno `verifyImages`); deploy by digest |

2. (a) An unprotected cluster pulls `myapp:1.4.2` by tag (or `imagePullPolicy: Always`) and runs the tampered image with no check. (b) Independent controls: (1) signature verification at admission (Kyverno `verifyImages` / cosign) — the attacker lacks the signing key so the tampered image has no valid signature; (2) registry allow-list admission policy, plus (optionally) referencing by digest so a re-pointed tag cannot change what runs.

3. Classification:
- Branch protection, signed commits, MFA, ephemeral runners, immutable tags, scan-on-push: outside cluster (SCM/CI/registry settings).
- Allow-listed registries: inside cluster, Kyverno/Gatekeeper/`ImagePolicyWebhook`.
- Signature verification, digest pinning enforcement: inside cluster, Kyverno `verifyImages` (or a policy requiring `@sha256:`).

4. Digest exercise:
```
kubectl run dg --image=docker.io/library/nginx:1.27
kubectl wait --for=condition=Ready pod/dg --timeout=90s
kubectl get pod dg -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
```
`imageID` looks like `docker.io/library/nginx@sha256:<64 hex>`. Then `dg-pinned.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dg-pinned
spec:
  containers:
  - name: nginx
    image: docker.io/library/nginx@sha256:<digest-from-above>
```
```
kubectl apply -f dg-pinned.yaml
```

## Expected output
```
docker.io/library/nginx@sha256:3f0c...   (64 hex chars)
```
`kubectl get pod dg-pinned -o jsonpath='{.spec.containers[0].image}'` prints the `@sha256:` reference.

## Why it works
A tag is a mutable pointer; a digest is a hash of the manifest so it cannot change without changing the reference. Verification and allow-listing at admission means the cluster does not trust what CI or the registry claims, only what it can cryptographically or policy-wise validate.

## Common mistakes / exam gotchas
- Assuming a private registry alone is secure: it does not prove an image is the one CI built.
- Pinning by digest without also automating updates leaves stale, vulnerable images.
- Writing generic mitigations; the answer should name a concrete tool or setting.
- `imageID` may be the multi-arch index or platform manifest digest depending on the runtime; either pins the pull, but it may differ from `docker images --digests` output.
- The CKS exam is hands-on: expect these ideas to show up as ImagePolicyWebhook, allow-list, or signature-verification configs.

## Cleanup
```
kubectl delete pod dg dg-pinned --ignore-not-found
```
