# Week 6 · Day 8 (Nov 4) — Review & self-quiz — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-08-review-self-quiz.md](../../plan/week-06-monitoring-logging-runtime-security/day-08-review-self-quiz.md)

## Solution
### 1. Custom Falco rule
`workspace/week-06/quiz1-rule.yaml`:
```yaml
- rule: Network tool run in quiz1
  desc: curl or wget executed inside a container in namespace quiz1
  condition: >
    spawned_process and container and k8s.ns.name = quiz1
    and proc.name in (curl, wget)
  output: >
    Network tool executed (pod=%k8s.pod.name user=%user.name cmd=%proc.cmdline ns=%k8s.ns.name)
  priority: CRITICAL
  tags: [custom]
```
Deliver, keeping earlier files:
```
helm upgrade falco falcosecurity/falco -n falco --reuse-values \
  --set-file 'customRules.shadow-rule\.yaml=workspace/week-06/shadow-rule.yaml' \
  --set-file 'customRules.outbound-rule\.yaml=workspace/week-06/outbound-rule.yaml' \
  --set-file 'customRules.quiz1-rule\.yaml=workspace/week-06/quiz1-rule.yaml'
kubectl rollout restart ds/falco -n falco
kubectl exec -n quiz1 app -- sh -c 'which curl wget; wget -T2 -qO- http://localhost'
```
Note: the `nginx` image has `curl` on Debian-based tags; if neither tool is present, use `kubectl exec ... -- sh -c 'cp /bin/ls /tmp/wget && /tmp/wget'` to run a binary named `wget`. Alert: `Critical Network tool executed (pod=app ...)`.

### 2. Compromised pod
```
POD=$(kubectl get pod -n quiz2 -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-api
  namespace: quiz2
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress, Egress]
EOF
kubectl logs -n quiz2 $POD > quiz2-evidence.txt
kubectl describe pod -n quiz2 $POD >> quiz2-evidence.txt
kubectl get rolebindings,clusterrolebindings -A -o wide | grep api-sa
kubectl delete rolebinding <binding-name> -n quiz2
kubectl patch sa api-sa -n quiz2 -p '{"automountServiceAccountToken": false}'
kubectl delete pod -n quiz2 $POD
kubectl auth can-i create pods -n quiz2 --as=system:serviceaccount:quiz2:api-sa
```

### 3. Immutability
```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile: {type: RuntimeDefault}
      containers:
      - name: svc
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports: [{containerPort: 8080}]
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities: {drop: ["ALL"]}
        volumeMounts:
        - {name: tmp, mountPath: /tmp}
      volumes:
      - {name: tmp, emptyDir: {}}
```
Prove: `kubectl exec -n quiz3 <pod> -- touch /newfile` fails; `touch /tmp/x` works; `grep CapEff /proc/1/status` is zeros.

### 4. New audit policy
On the node, `/etc/kubernetes/audit/policy2.yaml`:
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["get", "list", "watch"]
  - level: Request
    resources:
      - group: ""
        resources: ["configmaps"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods/exec"]
  - level: Metadata
```
Two options: change the manifest flag and the hostPath volume to `policy2.yaml`, or simply overwrite `policy.yaml` (the apiserver reads the policy only at start, so either way restart is needed: touch/re-save the manifest, or move it out and back after ~20 s). Changing both the `--audit-policy-file` flag and the `audit-policy` hostPath path/mountPath is the expected wiring change. Verify:
```
kubectl create configmap cm-test --from-literal=a=b
docker exec cks-control-plane cat /var/log/kubernetes/audit/audit.log | jq -c 'select(.objectRef.resource=="configmaps" and .verb=="create") | {level, hasReq:(.requestObject!=null)}' | tail -1
```

### 5. jq filters (`L=workspace/week-06/audit.log`)
```
jq -c 'select(.objectRef.subresource=="exec")' $L
jq -c 'select(.user.groups[]? == "system:unauthenticated")' $L
jq -c 'select(.objectRef.resource=="clusterrolebindings" and (.verb=="create" or .verb=="update" or .verb=="patch"))' $L
jq -r '.verb' $L | sort | uniq -c | sort -rn
```

## Expected output
- Item 1: `Critical Network tool executed (pod=app user=root cmd=wget -T2 -qO- http://localhost ns=quiz1)`.
- Item 4: `{"level":"Request","hasReq":true}`.
- Item 5d: lines like `  842 get`, `  310 watch`, `  120 list`.

## Why it works
See Days 1–7: Falco rule macros (`spawned_process`, `container`), deny-all NetworkPolicy plus RBAC removal for containment, container-level securityContext plus scoped emptyDir for immutability, first-match policy ordering for audit, and jq on the `impersonatedUser`/`responseStatus` fields.

## Common mistakes / exam gotchas
- Rule ordering in the audit policy: the `None` rule for kube-proxy must precede the catch-all.
- Changing a policy file without restarting the apiserver.
- `pods/exec`: the resource string is `pods/exec` in the audit policy rule; in the log it appears as `objectRef.resource=pods`, `subresource=exec`.
- Losing earlier `customRules` files in `helm upgrade`.
- Not saving evidence before deleting the pod.
- Precision with `jq`: `select(.user.groups[]? == "...")` needs the `?` if groups may be absent.

## Cleanup
```
kubectl delete ns quiz1 quiz2 quiz3
kubectl delete cm cm-test
```
Restore the Day 6 backup (`cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml` on the node) to disable audit logging.
