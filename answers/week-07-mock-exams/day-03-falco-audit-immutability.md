# Week 7 · Day 3 (Nov 7) — Mixed set: Falco + audit logs + immutability — Answers
Task: [plan/week-07-mock-exams/day-03-falco-audit-immutability.md](../../plan/week-07-mock-exams/day-03-falco-audit-immutability.md)

## Solution

### Task 1 — Custom Falco rule
Rule:
```yaml
- rule: Network Tool Run In Web Prod
  desc: wget or curl spawned in a container in namespace web-prod
  condition: spawned_process and container and proc.name in (wget, curl) and k8s.ns.name = "web-prod"
  output: "NET_TOOL_IN_POD ns=%k8s.ns.name pod=%k8s.pod.name user=%user.name cmd=%proc.cmdline image=%container.image.repository"
  priority: WARNING
  tags: [mock]
```
Load, Helm variant (`custom-rules.yaml` values file):
```yaml
customRules:
  mock-rules.yaml: |-
    - rule: Network Tool Run In Web Prod
      desc: wget or curl spawned in a container in namespace web-prod
      condition: spawned_process and container and proc.name in (wget, curl) and k8s.ns.name = "web-prod"
      output: "NET_TOOL_IN_POD ns=%k8s.ns.name pod=%k8s.pod.name user=%user.name cmd=%proc.cmdline image=%container.image.repository"
      priority: WARNING
      tags: [mock]
```
```
helm upgrade falco falcosecurity/falco -n falco --reuse-values -f custom-rules.yaml
kubectl -n falco rollout restart ds/falco
kubectl -n falco rollout status ds/falco
```
ConfigMap variant (if that is how you did Week 6): put the rule in the ConfigMap that is mounted under `/etc/falco/rules.d/` (or your `falco_rules.local.yaml`), then `kubectl -n falco rollout restart ds/falco`.

Validate syntax: `kubectl -n falco exec ds/falco -c falco -- falco -V /etc/falco/rules.d/mock-rules.yaml`.

Trigger and capture:
```
kubectl -n web-prod exec intruder -- wget -qO- -T2 http://kubernetes.default.svc
kubectl -n falco logs -l app.kubernetes.io/name=falco -c falco --tail=200 | grep NET_TOOL_IN_POD | tail -1 | tee /tmp/falco-hit.txt
```
If `k8s.ns.name` renders as `<NA>` (no Kubernetes metadata enrichment in your Falco deployment), the condition never matches; confirm with the output of the default shell rule, then either enable the k8s metadata source or temporarily use `container.image.repository = busybox` in the condition and say so.

### Task 2 — Audit log queries
```
docker cp cks-control-plane:/var/log/kubernetes/audit/audit.log /tmp/audit.log
jq -c 'select(.verb=="delete" and .objectRef.resource=="secrets" and .stage=="ResponseComplete") | {user:.user.username, ns:.objectRef.namespace, name:.objectRef.name, time:.requestReceivedTimestamp}' /tmp/audit.log > /tmp/audit-q1.txt
jq -c 'select(.responseStatus.code==403) | {user:.user.username, impersonated:(.impersonatedUser.username // null), verb, uri:.requestURI, code:.responseStatus.code}' /tmp/audit.log > /tmp/audit-q2.txt
jq -c 'select(.objectRef.subresource=="exec") | {user:.user.username, ns:.objectRef.namespace, pod:.objectRef.name}' /tmp/audit.log | sort -u > /tmp/audit-q3.txt
jq -s 'group_by(.verb) | map({verb:.[0].verb, n:length}) | sort_by(-.n)' /tmp/audit.log > /tmp/audit-q4.txt
echo 'audit-q2 shows it: with --as the authenticated caller (kubernetes-admin) is recorded in user and the identity being impersonated (mallory) in impersonatedUser, and mallory has no RBAC so the request was denied.' > /tmp/audit-q5.txt
```
Field cheatsheet: `.user.username`, `.user.groups`, `.verb`, `.objectRef.resource|namespace|name|subresource`, `.responseStatus.code`, `.requestURI`, `.sourceIPs`, `.impersonatedUser.username`, `.stage`, `.requestReceivedTimestamp`.

### Task 3 — Hardened pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-ui
  namespace: locked
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: ui
    image: nginxinc/nginx-unprivileged:1.27
    ports:
    - containerPort: 8080
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```
Verify:
```
kubectl -n locked get pod vault-ui
kubectl -n locked exec vault-ui -- touch /usr/share/nginx/html/x
kubectl -n locked exec vault-ui -- touch /tmp/x
kubectl -n locked exec vault-ui -- ls /var/run/secrets/kubernetes.io
```

### Task 4 — Mutable workload audit
```
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.namespace!="kube-system") | select(any(.spec.containers[]; .securityContext.readOnlyRootFilesystem != true)) | "\(.metadata.namespace)/\(.metadata.name)"' > /tmp/mutable-pods.txt
kubectl get pods -A -o json | jq -r '.items[] | select(any((.spec.containers + (.spec.initContainers // []))[]; .securityContext.privileged == true)) | "\(.metadata.namespace)/\(.metadata.name)"' > /tmp/privileged-pods.txt
```
`privileged-pods.txt` also lists CNI/system pods (calico-node etc.); that is expected.

Recreate:
```
kubectl -n locked delete pod legacy-app --force --grace-period=0
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
  namespace: locked
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: legacy-app
    image: nginxinc/nginx-unprivileged:1.27
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

### Task 5 — Incident response
```
kubectl -n web-prod label pod intruder quarantine=true app-
kubectl -n web-prod get endpoints web-svc
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine
  namespace: web-prod
spec:
  podSelector:
    matchLabels:
      quarantine: "true"
  policyTypes: [Ingress, Egress]
EOF
mkdir -p /tmp/evidence
kubectl -n web-prod get pod intruder -o yaml > /tmp/evidence/intruder.yaml
kubectl -n web-prod logs intruder > /tmp/evidence/intruder.log
kubectl -n falco logs -l app.kubernetes.io/name=falco -c falco --tail=-1 | grep intruder > /tmp/evidence/falco.txt
kubectl -n web-prod delete pod intruder
```
Removing `app` from labels drops the pod from Service endpoints (the selector is `app=web`).

## Expected output
- Task 1 line: `... Warning NET_TOOL_IN_POD ns=web-prod pod=intruder user=root cmd=wget -qO- -T2 http://kubernetes.default.svc image=busybox`.
- q1: `{"user":"kubernetes-admin","ns":"audit-lab","name":"s1","time":"..."}`.
- q2: `{"user":"kubernetes-admin","impersonated":"mallory","verb":"list","uri":"/api/v1/namespaces/audit-lab/pods","code":403}`.
- Task 3: `touch: /usr/share/nginx/html/x: Read-only file system`; `/tmp/x` succeeds; `ls` of SA path fails.

## Why it works
- Falco macros already express "process spawned" and "in a container"; the custom condition only adds process name and namespace.
- Audit events are line-delimited JSON, so `jq -c select(...)` filters directly; impersonation is recorded separately from the authenticated identity.
- `readOnlyRootFilesystem` blocks writes to image layers; `emptyDir` gives the app only the paths it needs.
- Quarantine label plus empty-rule policy isolates without destroying evidence.

## Common mistakes / exam gotchas
- Rule loaded but Falco not restarted; or rule file with a YAML indentation error stops Falco from starting (check `falco -V`).
- Using `evt.type=execve` alone without `evt.dir` or the `spawned_process` macro, causing duplicate or missing hits.
- Audit: querying only `RequestReceived` stage entries (no `responseStatus`); forgetting the policy must include the resource at all.
- Forgetting `docker cp`/reading the log from the node path when jq lives on the host.
- nginx with `readOnlyRootFilesystem` and the standard image fails (needs `/var/cache/nginx`, `/var/run`, root for port 80); use the unprivileged image plus `/tmp` emptyDir.
- `runAsNonRoot` without numeric UID when the image has a non-numeric user.
- Deleting the compromised pod before collecting evidence.

## Cleanup
```
kubectl delete ns web-prod locked audit-lab
rm -rf /tmp/evidence
```
