# Week 7 · Day 1 (Nov 5) — Mixed set: NetworkPolicy + RBAC + Secret encryption — Answers
Task: [plan/week-07-mock-exams/day-01-netpol-rbac-secret-encryption.md](../../plan/week-07-mock-exams/day-01-netpol-rbac-secret-encryption.md)

## Solution

### Task 1 — NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: shop
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: shop
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-policy
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: edge
    ports:
    - {protocol: TCP, port: 80}
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - {protocol: TCP, port: 8080}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - {protocol: TCP, port: 8080}
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - {protocol: TCP, port: 5432}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - {protocol: TCP, port: 5432}
```
Apply: `kubectl apply -f netpol.yaml`. `db-policy` lists `Egress` without rules, so db has no egress except DNS from `allow-dns`.

Test:
```
kubectl -n edge exec client -- wget -qO- -T2 web.shop
kubectl -n edge exec client -- wget -qO- -T2 api.shop:8080
kubectl -n shop exec web -- wget -qO- -T2 api:8080
kubectl -n shop exec web -- wget -qO- -T2 db:5432
kubectl -n shop exec api -- wget -qO- -T2 db:5432
kubectl -n shop exec db  -- wget -qO- -T2 api:8080
```
Note: a busybox `httpd` with no index returns 404; `wget` then exits non-zero with "server returned error: 404". That still proves connectivity; a timeout is the blocked case. To get a clean 200, `kubectl exec` in and `echo ok > /home/index.html` (httpd default root is the working dir `/`; add `-h /tmp` if you want).

### Task 2 — RBAC
```
kubectl -n shop create sa auditor-sa
```
`kubectl create role` cannot express two different rules in one Role; write the Role as YAML:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: auditor
  namespace: shop
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config"]
  verbs: ["get"]
```
Apply it, then:
```
kubectl -n shop create rolebinding auditor-binding --role=auditor --serviceaccount=shop:auditor-sa
kubectl -n shop create rolebinding auditor-jane --role=auditor --user=jane
for who in jane system:serviceaccount:shop:auditor-sa; do
  kubectl auth can-i list pods -n shop --as=$who
  kubectl auth can-i get configmap/app-config -n shop --as=$who
  kubectl auth can-i get configmap/other-config -n shop --as=$who
  kubectl auth can-i get secrets -n shop --as=$who
  kubectl auth can-i delete pods -n shop --as=$who
  kubectl auth can-i list pods -n default --as=$who
done
```

### Task 3 — Encryption at rest
1. Create the config on the node:
```
KEY=$(head -c 32 /dev/urandom | base64)
cat > enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${KEY}
      - identity: {}
EOF
docker exec -i cks-control-plane bash -c 'mkdir -p /etc/kubernetes/enc && cat > /etc/kubernetes/enc/enc.yaml && chmod 600 /etc/kubernetes/enc/enc.yaml' < enc.yaml
```
2. Edit the manifest: `docker exec -it cks-control-plane vi /etc/kubernetes/manifests/kube-apiserver.yaml`. Back it up outside `/etc/kubernetes/manifests` first (`cp` to `/root/`), because any extra file in that directory is treated as a manifest.
   - Under `command:` add `- --encryption-provider-config=/etc/kubernetes/enc/enc.yaml`
   - Under `volumeMounts:` add
```yaml
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
```
   - Under `volumes:` add
```yaml
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```
3. Wait: `until kubectl get nodes >/dev/null 2>&1; do sleep 3; done; kubectl -n kube-system get pods`. If it never returns, check `docker exec cks-control-plane crictl ps -a | grep apiserver` and `crictl logs <id>` (typical causes: YAML indentation, wrong key length, path typo).
4. Re-write all objects:
```
kubectl get secrets -A -o json | kubectl replace -f -
kubectl get configmaps -A -o json | kubectl replace -f -
```
5. Verify:
```
kubectl -n kube-system exec etcd-cks-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/shop/db-pass | hexdump -C | head
```
Repeat with `/registry/configmaps/shop/app-config`.
6. `kubectl -n shop get secret db-pass -o jsonpath='{.data.password}' | base64 -d`

### Task 4 — cluster-admin audit
```
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " " + ((.subjects // []) | map(.kind + "/" + .name) | join(","))' > /tmp/cluster-admins.txt
cat /tmp/cluster-admins.txt
kubectl delete clusterrolebinding temp-admin ci-admin
kubectl auth can-i '*' '*' --as=bob
kubectl auth can-i '*' '*' --as=system:serviceaccount:ci:runner
```
The remaining entries should be `cluster-admin Group/system:masters` and `kubeadm:cluster-admins Group/kubeadm:cluster-admins`; leave them.

### Task 5 — SA token hygiene
```
kubectl -n shop patch sa auditor-sa -p '{"automountServiceAccountToken": false}'
kubectl -n shop run probe --image=busybox:1.36 --overrides='{"spec":{"serviceAccountName":"auditor-sa"}}' -- sleep 3600
```
Cleaner as YAML for both pods:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: shop
spec:
  serviceAccountName: auditor-sa
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: probe-tok
  namespace: shop
spec:
  serviceAccountName: auditor-sa
  automountServiceAccountToken: false
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: vault-token
    projected:
      sources:
      - serviceAccountToken:
          audience: vault
          expirationSeconds: 600
          path: vault-token
```
Verify:
```
kubectl -n shop exec probe -- ls /var/run/secrets/kubernetes.io
kubectl -n shop exec probe-tok -- ls /var/run/secrets/tokens /var/run/secrets/kubernetes.io
kubectl -n shop exec probe-tok -- cat /var/run/secrets/tokens/vault-token | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

## Expected output
- Task 1: blocked paths hang for the 2 s timeout then `wget: download timed out`; allowed paths return HTML/404 quickly.
- Task 2 loop: `yes yes no no no no` for both subjects.
- Task 3 hexdump shows text like `k8s:enc:aescbc:v1:key1:` followed by binary; the API returns plaintext.
- Task 4: `no` twice; file has 4 lines before deletion (two system, two custom).
- Task 5: `ls: /var/run/secrets/kubernetes.io: No such file or directory` for `probe`; JWT payload contains `"aud":["vault"]`.

## Why it works
- NetworkPolicies are allow-lists unioned per pod; default-deny plus per-app policies gives exactly the requested graph. Both the sender's egress and the receiver's ingress must permit a flow.
- `resourceNames` on `get` pins access to one ConfigMap; there is no `list` on ConfigMaps so nothing broader is visible.
- The API server encrypts with the first provider; `replace` forces a write that re-serialises with it. `identity` last keeps old data readable during the transition.
- Removing the default token mount and using an audience-bound projected token limits credential exposure.

## Common mistakes / exam gotchas
- Forgetting DNS egress after default-deny egress; or allowing DNS with only UDP.
- Putting `namespaceSelector` and `podSelector` as separate list items (OR) when AND was intended.
- Forgetting `Egress` in `policyTypes`.
- Backing up the API server manifest inside `/etc/kubernetes/manifests` (it becomes a second static pod).
- `identity` listed first: data is written unencrypted and etcdctl shows plaintext.
- Forgetting the `replace` step, so old secrets stay plaintext.
- Forgetting `readOnly` / volume for the encryption config; API server crash loops.
- `resourceNames` with `list`: does not restrict as expected.

## Cleanup
```
kubectl delete ns shop edge ci
kubectl delete clusterrolebinding temp-admin ci-admin --ignore-not-found
```
