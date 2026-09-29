# Week 4 · Day 1 (Oct 12) — Pod Security Standards: enforcing `restricted` — Answers
Task: [day-01-psa-restricted-enforce](../../plan/week-04-microservice-vulnerabilities/day-01-psa-restricted-enforce.md)

## Solution
1. Context and namespace:
```
kubectl config use-context kind-cks
kubectl create ns psa-lab
```
2. Enforce label:
```
kubectl label ns psa-lab pod-security.kubernetes.io/enforce=restricted
```
3. Non-compliant pod:
```
kubectl run root-pod -n psa-lab --image=busybox:1.36 -- sleep 3600
```
Rejected. Violations named: `allowPrivilegeEscalation != false`, unrestricted capabilities (must drop ALL), `runAsNonRoot != true`, missing `seccompProfile`.

4. Compliant manifest, `~/psa-lab/ok-pod.yaml`:
```
mkdir -p ~/psa-lab
cat > ~/psa-lab/ok-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ok-pod
  namespace: psa-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF
```
5. Apply and check:
```
kubectl apply -f ~/psa-lab/ok-pod.yaml
kubectl get pod ok-pod -n psa-lab
```
6. Warn/audit labels and privileged pod:
```
kubectl label ns psa-lab pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
kubectl run priv-pod -n psa-lab --image=busybox:1.36 --privileged -- sleep 3600
```

## Expected output
```
Error from server (Forbidden): pods "root-pod" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "root-pod" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "root-pod" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "root-pod" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "root-pod" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```
`ok-pod` shows `1/1 Running`. `priv-pod` is rejected with `violates PodSecurity "restricted:latest": privileged (container ... must not set securityContext.privileged=true)` plus the other violations. (`kubectl run --privileged` exists; if your kubectl rejects it, use a manifest with `securityContext.privileged: true`.)

## Why it works
The PodSecurity admission plugin reads namespace labels at request time and evaluates the pod spec against the named level's checks. `restricted` requires the four fields set explicitly; nothing is defaulted for you. `runAsUser: 1000` guarantees non-root even if the image would default to root; `runAsNonRoot: true` alone fails at container start if the image user is root/unspecified.

## Common mistakes / exam gotchas
- `capabilities.drop` and `allowPrivilegeEscalation` are container-level only; `runAsNonRoot` and `seccompProfile` may be pod or container level.
- Forgetting `initContainers` — they are checked too.
- Applying a Deployment "succeeds" but pods never appear: check `kubectl describe rs` / `kubectl get events -n <ns>`.
- Label key typo silently does nothing (`pod-security.kubernetes.io/enforce`, not `pod-security.kubernetes.io/enforced`). Verify with `--show-labels`.
- An image that needs root or binds port 80 (e.g. stock nginx) will not run under `restricted`; use an unprivileged image variant.
- Labelling does not evict existing pods.

## Cleanup
```
kubectl delete ns psa-lab
rm -rf ~/psa-lab
```
