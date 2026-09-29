# Week 6 · Day 6 (Nov 2) — Enable and configure Kubernetes audit logs — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-06-enable-audit-logs.md](../../plan/week-06-monitoring-logging-runtime-security/day-06-enable-audit-logs.md)

## Solution
1. Shell:
```
docker exec -it cks-control-plane bash
```
2. Secret (from the host):
```
kubectl create secret generic db-creds -n default --from-literal=password=s3cr3t
```
3. Policy (in the node shell):
```
mkdir -p /etc/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
  - level: Metadata
EOF
```
4. Backup outside the manifests dir:
```
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
```
5. Edit the manifest (`vi` may be missing on kind nodes; if so, `docker cp cks-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml .`, edit on the host, `docker cp` it back). Under `spec.containers[0].command` add:
```yaml
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxbackup=3
    - --audit-log-maxsize=100
```
Under `volumeMounts`:
```yaml
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit
      name: audit-log
```
Under `volumes`:
```yaml
  - hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-log
```
6. Wait:
```
kubectl get nodes
kubectl get --raw /healthz
```
If down for over ~2 min, on the node: `crictl ps -a | grep apiserver` and `crictl logs <id>`; usual cause is a typo or missing volume. Restore the backup with `cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml`.
7. `kubectl get secret db-creds -n default -o yaml`
8. Find the event (jq on the host; the node lacks jq):
```
docker exec cks-control-plane cat /var/log/kubernetes/audit/audit.log \
  | jq -c 'select(.verb=="get" and .objectRef.resource=="secrets" and .objectRef.name=="db-creds")' | tail -1
```
Without jq: `grep '"resource":"secrets"' audit.log | grep db-creds`.
9. `... | jq -c 'select(.objectRef.resource=="pods" and .verb=="get") | {level,stage,hasResp:(.responseObject!=null)}' | head -1`

## Expected output
```
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/secrets/db-creds","verb":"get","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"]},"sourceIPs":["172.18.0.1"],"objectRef":{"resource":"secrets","namespace":"default","name":"db-creds","apiVersion":"v1"},"responseStatus":{"code":200},"responseObject":{...}}
{"level":"Metadata","stage":"ResponseComplete","hasResp":false}
```
(The admin group is `kubeadm:cluster-admins` on recent kubeadm; `system:masters` on older clusters.)

## Why it works
The apiserver reads the policy at start and evaluates rules top to bottom; the first match sets the level. The container only sees host files that are mounted, so both the policy file and the log directory need hostPath volumes. The kubelet watches the static pod directory and recreates the apiserver with the new spec.

## Common mistakes / exam gotchas
- Missing volume/volumeMount: apiserver crash-loops; policy file not found.
- Catch-all rule first: later rules never match.
- Backup left inside `/etc/kubernetes/manifests/`: kubelet runs it as a second pod.
- YAML indentation of list items in `command`; `kubectl` fails for a minute while the apiserver restarts.
- Wrong `apiVersion` (`audit.k8s.io/v1`, not `v1beta1`).
- `RequestResponse` on secrets exposes secret data in the log; prefer `Metadata` in production.
- Mounting the policy `File` type with a missing file gives a mount error.
- kind specifics: the log lives inside the node container (`docker exec`); host-side access needs `extraMounts` at cluster creation.

## Cleanup
Keep enabled for Day 7. To disable later, on the node: `cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml`.
