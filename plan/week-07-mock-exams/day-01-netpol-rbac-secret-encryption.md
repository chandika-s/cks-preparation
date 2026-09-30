# Week 7 · Day 1 (Nov 5) — Mixed set: NetworkPolicy + RBAC + Secret encryption
**Domain:** Cluster Setup (15%) + Cluster Hardening (15%) + Minimize Microservice Vulnerabilities (20%) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Rebuild a default-deny + scoped-allow NetworkPolicy set, a least-privilege Role/RoleBinding, and etcd Secret encryption end-to-end under time pressure.
- Practise switching domains without losing time: context check, scaffold with `--dry-run=client -o yaml`, verify, move on.
- Produce a miss log entry for every task not finished or not clean (feeds Week 8).

## Theory
**Exam mechanics.** The real exam is 2 hours, multi-task, weighted by points. Docs allowed: kubernetes.io and tool docs only. Budget ~15 min/task; skip and return if stuck for more than 5 min. Always run `kubectl config use-context` first and confirm namespace.

**NetworkPolicy.** Additive allow-lists: a pod selected by any policy for a direction is denied for that direction except what some policy allows. `podSelector: {}` selects all pods in the namespace. `policyTypes` must list `Egress` for egress rules to matter. A `from`/`to` list item with both `namespaceSelector` and `podSelector` in the same item is AND; separate items are OR. Namespaces are matched by label; use the automatic `kubernetes.io/metadata.name`. Default-deny egress breaks DNS: allow UDP+TCP 53 to kube-system. Both sides matter: client egress and server ingress. Calico enforces policies on this cluster.

**RBAC.** Role/RoleBinding are namespaced; `roleRef` is immutable. `resourceNames` restricts to named objects but is ineffective for `list`/`watch`/`create`. Verify with `kubectl auth can-i <verb> <resource>[/name] --as=<user|system:serviceaccount:ns:sa> -n ns`. Subjects: `User`, `Group`, `ServiceAccount`.

**Encryption at rest.** kube-apiserver flag `--encryption-provider-config` pointing at an `EncryptionConfiguration` (`apiserver.config.k8s.io/v1`). Provider order: first provider encrypts writes, all are tried for reads; keep `identity: {}` last so existing plaintext data still reads. Existing objects remain plaintext until rewritten (`kubectl get secrets -A -o json | kubectl replace -f -`). Verification is by reading the raw key from etcd with `etcdctl` using certs in `/etc/kubernetes/pki/etcd/`; encrypted values start with `k8s:enc:aescbc:v1:<keyname>`. On kind the API server is a static pod at `/etc/kubernetes/manifests/kube-apiserver.yaml` inside the node container; a hostPath volume/mount is needed for the config file.

**Token hygiene.** `automountServiceAccountToken: false` on ServiceAccount or Pod; projected `serviceAccountToken` volumes give audience-bound, expiring tokens.

## Prerequisites
- Cluster `kind-cks` up, Calico running, `kubectl` context `kind-cks`.
- Week 4 Day 3 encryption config must not still be active in the API server manifest (no `--encryption-provider-config`); if it is, remove the flag/mount and restart the API server first, or treat Task 3 as a key rotation and say so in your notes.
- `jq`, `docker` on the host.

## Exam-style question
_Real exam gives only this; the steps under Task are guided practice._

### Q1 (20%) NetworkPolicy
Context: `kubectl config use-context kind-cks`. In namespace `shop`, pods `web`, `api` and `db` currently talk to anyone. Lock the namespace down so that all traffic is denied by default, DNS to `kube-system` is the only general exception, and only the chain `edge` namespace -> `web` (TCP 80) -> `api` (TCP 8080) -> `db` (TCP 5432) is permitted, in both directions as required. Name the policies `default-deny`, `allow-dns`, `web-policy`, `api-policy` and `db-policy`. `db` must have no other egress.

### Q2 (15%) RBAC
Context: `kubectl config use-context kind-cks`. In namespace `shop`, give ServiceAccount `auditor-sa` and user `jane` read-only visibility of pods and read access to the single ConfigMap `app-config`, using Role `auditor` and RoleBindings `auditor-binding` and `auditor-jane`. They must have no access to Secrets, no write verbs, no other ConfigMaps and nothing outside `shop`.

### Q3 (35%) Secrets encryption at rest
Context: `kubectl config use-context kind-cks`. The cluster stores Secrets and ConfigMaps unencrypted in etcd. Configure the kube-apiserver on `cks-control-plane` to encrypt `secrets` and `configmaps` with `aescbc` (key name `key1`, fresh 32-byte key, `identity` as fallback) using `/etc/kubernetes/enc/enc.yaml`. All existing Secrets and ConfigMaps, including `shop/db-pass` and `shop/app-config`, must end up stored encrypted, while remaining readable through the API. The control plane must be healthy afterwards.

### Q4 (15%) cluster-admin audit
Context: `kubectl config use-context kind-cks`. Some subjects hold `cluster-admin` through ClusterRoleBindings. Record every such binding in `/tmp/cluster-admins.txt` as `<bindingName> <Kind>/<subjectName>[,<Kind>/<subjectName>...]`, then remove every binding whose subjects are not system-managed (names starting with `system:` or `kubeadm:`). User `bob` and ServiceAccount `ci:runner` must end with no cluster-wide permissions.

### Q5 (15%) ServiceAccount token hygiene
Context: `kubectl config use-context kind-cks`. In namespace `shop`, ServiceAccount `auditor-sa` must not automount API tokens. Pod `probe` (`busybox:1.36`, `sleep 3600`) must run as `auditor-sa` with no token mounted. Pod `probe-tok` (same image and command, same ServiceAccount) must receive only a projected token for audience `vault`, valid 600 seconds, at `/var/run/secrets/tokens/vault-token`, mounted read-only.

## Task
Set a timer per task. Suggested budget and points are in each heading. Total 90 min / 100 points.

**Setup (not timed):**
```
kubectl create ns shop; kubectl create ns edge
kubectl -n shop run web --image=busybox:1.36 --labels app=web -- httpd -f -p 80
kubectl -n shop run api --image=busybox:1.36 --labels app=api -- httpd -f -p 8080
kubectl -n shop run db  --image=busybox:1.36 --labels app=db  -- httpd -f -p 5432
kubectl -n shop expose pod web --port 80
kubectl -n shop expose pod api --port 8080
kubectl -n shop expose pod db  --port 5432
kubectl -n edge run client --image=busybox:1.36 -- sleep 3600
kubectl -n shop create cm app-config --from-literal=mode=prod
kubectl -n shop create cm other-config --from-literal=x=y
kubectl -n shop create secret generic db-pass --from-literal=password=S3cr3t!
```

### Task 1 — NetworkPolicy (20 min, 20 pts)
In namespace `shop`:
1. Deny all ingress and egress for every pod in the namespace (policy named `default-deny`).
2. Allow all pods in `shop` to send DNS (UDP and TCP 53) to namespace `kube-system` only (policy `allow-dns`).
3. `web` accepts ingress only from pods in namespace `edge`, TCP 80; `web` may send egress only to `api` on TCP 8080.
4. `api` accepts ingress only from `web`, TCP 8080; `api` may send egress only to `db` on TCP 5432.
5. `db` accepts ingress only from `api`, TCP 5432 and has no other egress.
6. Use policies named `web-policy`, `api-policy`, `db-policy`.

### Task 2 — RBAC (15 min, 15 pts)
In namespace `shop`:
1. Create ServiceAccount `auditor-sa`.
2. Create Role `auditor` allowing: `get`, `list`, `watch` on `pods`; `get` on the single ConfigMap `app-config` only.
3. Bind the Role to `auditor-sa` (RoleBinding `auditor-binding`) and additionally to user `jane` (RoleBinding `auditor-jane`).
4. No access to Secrets, no write verbs, no access to other ConfigMaps, no access in other namespaces.

### Task 3 — Secrets encryption at rest (30 min, 35 pts)
1. On node `cks-control-plane`, create `/etc/kubernetes/enc/enc.yaml` encrypting `secrets` and `configmaps` with `aescbc`, key name `key1`, a fresh random 32-byte key, with `identity` as fallback provider.
2. Configure the kube-apiserver to use it (file must be mounted read-only into the pod).
3. Wait for the API server to come back and confirm all control plane pods are Running.
4. Ensure the already-existing Secret `shop/db-pass` and all existing Secrets and ConfigMaps in the cluster are re-written so they are stored encrypted.
5. Prove with `etcdctl` (run through the etcd static pod) that `/registry/secrets/shop/db-pass` and `/registry/configmaps/shop/app-config` are stored encrypted with key `key1`.
6. Prove `kubectl -n shop get secret db-pass -o jsonpath='{.data.password}' | base64 -d` still prints the plaintext.

### Task 4 — cluster-admin audit (10 min, 15 pts)
Setup: `kubectl create clusterrolebinding temp-admin --clusterrole=cluster-admin --user=bob` and `kubectl create ns ci; kubectl -n ci create sa runner; kubectl create clusterrolebinding ci-admin --clusterrole=cluster-admin --serviceaccount=ci:runner`.
1. Write to `/tmp/cluster-admins.txt` one line per ClusterRoleBinding referencing ClusterRole `cluster-admin`, format `<bindingName> <Kind>/<subjectName>[,<Kind>/<subjectName>...]`.
2. Delete every such binding whose subjects are not system-managed (subject name not starting with `system:` or `kubeadm:`).
3. Confirm `bob` and `ci:runner` can no longer do anything cluster-wide.

### Task 5 — ServiceAccount token hygiene (10 min, 15 pts)
In `shop`:
1. Set `automountServiceAccountToken: false` on ServiceAccount `auditor-sa`.
2. Run Pod `probe` (image `busybox:1.36`, `sleep 3600`) using `auditor-sa`; it must have no default token mount.
3. Run Pod `probe-tok` using `auditor-sa` (image `busybox:1.36`, `sleep 3600`) with a projected ServiceAccount token: audience `vault`, expiry 600 s, path `vault-token`, mounted read-only at `/var/run/secrets/tokens`. The default token mount must still be absent.

## Check your work
- Task 1: from `edge/client`, `wget -qO- -T2 web.shop` succeeds; from `edge/client` to `api.shop:8080` times out; from `web` to `api:8080` succeeds; from `web` to `db:5432` times out; from `api` to `db:5432` succeeds; from `db` to `api:8080` times out; name resolution works from `web`.
- Task 2: `can-i list pods` = yes, `get configmap/app-config` = yes, `get configmap/other-config` = no, `get secrets` = no, `delete pods` = no, `list pods -n default` = no; the same for `jane` and for the SA.
- Task 3: etcd values begin `k8s:enc:aescbc:v1:key1`; `kubectl get pods -A` healthy; plaintext readable via API.
- Task 4: file exists with the correct lines; `kubectl auth can-i '*' '*' --as=bob` = no.
- Task 5: `kubectl exec probe -- ls /var/run/secrets/kubernetes.io` fails; `probe-tok` has `/var/run/secrets/tokens/vault-token` and no default mount; decoding the JWT payload shows `aud` = `vault`.

After the set: list every task not finished or not clean and the specific gap in your miss log (see Day 7 template).

## Answer
[answers/week-07-mock-exams/day-01-netpol-rbac-secret-encryption.md](../../answers/week-07-mock-exams/day-01-netpol-rbac-secret-encryption.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns shop edge ci
kubectl delete clusterrolebinding temp-admin ci-admin --ignore-not-found
```
Leaving encryption at rest enabled is harmless; if you want the baseline back, remove the flag, mount and volume from the API server manifest (keep `identity` first in the config during the transition).
