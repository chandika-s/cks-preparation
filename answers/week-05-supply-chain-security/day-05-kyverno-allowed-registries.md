# Week 5 · Day 5 (Oct 24) — Secure your supply chain: permitted registries — Answers
Task: [day-05-kyverno-allowed-registries.md](../../plan/week-05-supply-chain-security/day-05-kyverno-allowed-registries.md)

## Solution
1. Install (pin a release from https://github.com/kyverno/kyverno/releases if you want reproducibility):
```
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
kubectl -n kyverno get deploy
kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=180s
```
Also wait for `kyverno-background-controller`, `kyverno-cleanup-controller`, `kyverno-reports-controller`.

2.
```
kubectl create ns registry-test
```
3. `workspace/week-05/day-05/allow-registries.yaml`:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  background: false
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["registry-test"]
    validate:
      failureAction: Enforce
      message: "Images must come from docker.io/library/"
      pattern:
        spec:
          =(ephemeralContainers):
          - image: "docker.io/library/*"
          =(initContainers):
          - image: "docker.io/library/*"
          containers:
          - image: "docker.io/library/*"
```
```
kubectl apply -f allow-registries.yaml
kubectl get clusterpolicy restrict-image-registries
```
4.
```
kubectl -n registry-test run bad --image=quay.io/nginx/nginx-unprivileged:latest
```
5.
```
kubectl -n registry-test run good --image=docker.io/library/nginx:1.27
kubectl -n registry-test get pod good
```
6. `bad-init.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-init
  namespace: registry-test
spec:
  initContainers:
  - name: init
    image: quay.io/prometheus/busybox:latest
    command: ["true"]
  containers:
  - name: app
    image: docker.io/library/nginx:1.27
```
```
kubectl apply -f bad-init.yaml
```
7. Audit round trip:
```
kubectl patch clusterpolicy restrict-image-registries --type=json -p '[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Audit"}]'
kubectl -n registry-test run bad --image=quay.io/nginx/nginx-unprivileged:latest
kubectl get policyreport -n registry-test
kubectl -n registry-test delete pod bad --now
kubectl patch clusterpolicy restrict-image-registries --type=json -p '[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
```

## Expected output
```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/registry-test/bad was blocked due to the following policies

restrict-image-registries:
  validate-registries: 'validation error: Images must come from docker.io/library/.
    rule validate-registries failed at path /spec/containers/0/image/'
```
`good` becomes `Running`. In Audit mode `polr` shows `FAIL` count of at least 1.

## Why it works
The API server calls Kyverno's validating webhook for Pod creates; the rule's `pattern` is overlaid on the incoming object and the glob `docker.io/library/*` must match every listed image, so any other prefix causes a deny. Init/ephemeral containers are separate arrays and need their own entries or they bypass the check.

## Common mistakes / exam gotchas
- Using `nginx:1.27` (short name): it does not match `docker.io/library/*`; write full names in the policy and manifests. Alternatively allow both spellings in the pattern with `|`.
- Only covering `containers`: initContainers/ephemeralContainers bypass the policy.
- Matching only `Pod`: pods created by Deployments are still Pods and are checked at pod creation, but the Deployment itself is accepted (its ReplicaSet fails to create pods; look at `kubectl describe rs` / events). Kyverno also auto-generates Deployment/StatefulSet/Job rules unless `pod-policies.kyverno.io/autogen-controllers: none` is set.
- `kubectl apply` of Kyverno install fails with `metadata.annotations: Too long`: use `kubectl create` (or `apply --server-side`).
- Blocking too broadly (no `namespaces:`) can deny system pods (`registry.k8s.io/*`, `docker.io/calico/*`) and break the cluster; exclude `kube-system`, `kyverno`, `calico-system`.
- With webhook failurePolicy `Fail`, a down Kyverno blocks all matching pod creates.
- Gatekeeper equivalent: `K8sAllowedRepos` ConstraintTemplate plus a Constraint with `repos: ["docker.io/library/"]`.
- ImagePolicyWebhook on a real cluster requires editing `/etc/kubernetes/manifests/kube-apiserver.yaml` (add plugin flag, `--admission-control-config-file`, and hostPath volume mounts for config/kubeconfig); on kind this means editing inside `docker exec -it cks-control-plane bash`. A wrong file path makes the apiserver crash-loop; back it up first.

## Cleanup
```
kubectl delete clusterpolicy restrict-image-registries
kubectl delete ns registry-test
```
