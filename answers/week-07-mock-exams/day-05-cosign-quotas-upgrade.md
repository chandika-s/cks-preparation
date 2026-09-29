# Week 7 · Day 5 (Nov 9) — Mixed set: cosign + quotas + upgrade reasoning — Answers
Task: [plan/week-07-mock-exams/day-05-cosign-quotas-upgrade.md](../../plan/week-07-mock-exams/day-05-cosign-quotas-upgrade.md)

## Solution

### Task 1 — cosign
```
docker run -d --name mock-registry -p 5001:5000 registry:2
docker pull busybox:1.36
docker tag busybox:1.36 localhost:5001/mock/app:v1
docker push localhost:5001/mock/app:v1
DIGEST=$(docker inspect --format '{{json .RepoDigests}}' localhost:5001/mock/app:v1 | jq -r '.[] | select(startswith("localhost:5001"))')
echo $DIGEST
mkdir -p /tmp/cosign-lab && cd /tmp/cosign-lab
COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --key cosign.key --tlog-upload=false --yes $DIGEST
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5001/mock/app:v1 > verify-ok.json
cosign verify --key cosign.pub --insecure-ignore-tlog=true $DIGEST >> verify-ok.json
cosign tree localhost:5001/mock/app:v1
```
If `DIGEST` is empty (containerd image store in Docker Desktop changes what `RepoDigests` reports), get it from the registry: `curl -sI -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json' http://localhost:5001/v2/mock/app/manifests/v1 | grep -i docker-content-digest` and build `localhost:5001/mock/app@sha256:...`. `crane digest localhost:5001/mock/app:v1` also works.

Tamper:
```
docker pull alpine:3.20
docker tag alpine:3.20 localhost:5001/mock/app:v1
docker push localhost:5001/mock/app:v1
{
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5001/mock/app:v1
cosign verify --key cosign.pub --insecure-ignore-tlog=true $DIGEST > /dev/null && echo "original digest still verifies"
} 2>&1 | tee verify-tamper.txt
```
Wrong key:
```
mkdir other && cd other && COSIGN_PASSWORD="" cosign generate-key-pair && cd ..
cosign verify --key other/cosign.pub --insecure-ignore-tlog=true $DIGEST
```

### Task 2 — Quota and LimitRange
```
kubectl create ns team-b
```
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-b-quota
  namespace: team-b
spec:
  hard:
    pods: "4"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    persistentvolumeclaims: "1"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: team-b-limits
  namespace: team-b
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 500m
      memory: 512Mi
    min:
      cpu: 50m
      memory: 64Mi
```
```
kubectl -n team-b run p-default --image=nginx:1.27
kubectl -n team-b get pod p-default -o jsonpath='{.spec.containers[0].resources}'; echo
```
Rejected pods (write as YAML, since `kubectl run --requests/--limits` no longer exist):
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: p-big
  namespace: team-b
spec:
  containers:
  - name: c
    image: nginx:1.27
    resources:
      limits:
        cpu: "1"
---
apiVersion: v1
kind: Pod
metadata:
  name: p-tiny
  namespace: team-b
spec:
  containers:
  - name: c
    image: nginx:1.27
    resources:
      requests:
        cpu: 10m
```
```
kubectl apply -f rejected.yaml 2>&1 | tee /tmp/limitrange-errors.txt
kubectl -n team-b create deploy filler --image=nginx:1.27 --replicas=5
sleep 10
kubectl -n team-b get pods
kubectl -n team-b describe quota team-b-quota | tee /tmp/quota-used.txt
kubectl -n team-b describe rs -l app=filler | grep -i quota
```
Result: 3 filler pods run; the quota allows 4 pods total and `p-default` already uses one. The ReplicaSet event says `exceeded quota: team-b-quota, requested: pods=1, used: pods=4, limited: pods=4`.

### Task 3 — Upgrade runbook and drain
`/tmp/upgrade-runbook.md`:
```
Skew: upgrade one minor at a time (1.34.x -> 1.35.X). kubeadm may not be newer than target; kubelet must not be newer than kube-apiserver; kubectl within one minor.

Control plane (cks-control-plane)
1. etcd backup: ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key snapshot save /root/etcd-backup.db
2. apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.35.X-*' && apt-mark hold kubeadm
3. kubeadm version -o short
4. kubeadm upgrade plan
5. kubeadm upgrade apply v1.35.X
6. kubectl drain cks-control-plane --ignore-daemonsets
7. apt-mark unhold kubelet kubectl && apt-get install -y kubelet='1.35.X-*' kubectl='1.35.X-*' && apt-mark hold kubelet kubectl
8. systemctl daemon-reload && systemctl restart kubelet
9. kubectl uncordon cks-control-plane

Worker (cks-worker)
10. On worker: apt-mark unhold kubeadm && apt-get install -y kubeadm='1.35.X-*' && apt-mark hold kubeadm
11. On worker: kubeadm upgrade node
12. From control plane: kubectl drain cks-worker --ignore-daemonsets --delete-emptydir-data
13. On worker: upgrade kubelet (and kubectl) packages as in step 7, systemctl daemon-reload && systemctl restart kubelet
14. From control plane: kubectl uncordon cks-worker

Verify: kubectl get nodes (all Ready, VERSION v1.35.X); kubectl -n kube-system get pods; kubeadm certs check-expiration.
```
Snapshot:
```
kubectl -n kube-system exec etcd-cks-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/mock-snapshot.db
kubectl -n kube-system exec etcd-cks-control-plane -- etcdctl snapshot status /var/lib/etcd/mock-snapshot.db -w table
```
`snapshot status` is flagged deprecated in favour of `etcdutl`; it still works. If the etcd image lacks `etcdutl`/status, `ls -l` on the node (`docker exec cks-control-plane ls -l /var/lib/etcd/mock-snapshot.db`) is an acceptable check.

Drain mechanics:
```
kubectl create ns upg
kubectl -n upg create deploy web --image=nginx:1.27 --replicas=3
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: upg
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web
EOF
kubectl cordon cks-worker
kubectl get nodes
kubectl drain cks-worker --ignore-daemonsets --delete-emptydir-data --dry-run=server 2>&1 | tee /tmp/drain-dryrun.txt
kubectl uncordon cks-worker
cat >> /tmp/drain-dryrun.txt <<'EOF'
A real drain here would stall: the control plane node is tainted NoSchedule, so evicted pods cannot be rescheduled anywhere; the PDB (minAvailable 2 of 3) allows evicting one pod, its replacement stays Pending, and the next eviction is refused ("Cannot evict pod as it would violate the pod's disruption budget"), so drain retries indefinitely.
EOF
```
kind note: the in-place `apt` upgrade is not how kind clusters are upgraded; recreate the cluster from a newer `kindest/node`. The runbook is the deliverable; on the exam do the same steps on the provided nodes over SSH.

### Task 4 — Metadata egress block
```
kubectl create ns cloud; kubectl create ns sim
kubectl -n sim run metadata-sim --image=nginx:1.27
kubectl -n sim wait --for=condition=Ready pod/metadata-sim
SIMIP=$(kubectl -n sim get pod metadata-sim -o jsonpath='{.status.podIP}')
kubectl -n cloud run probe --image=curlimages/curl:8.10.1 -- sleep 3600
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: cloud
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
        - ${SIMIP}/32
EOF
kubectl -n cloud wait --for=condition=Ready pod/probe
kubectl -n cloud exec probe -- curl -m 3 -s http://${SIMIP}
OTHER=$(kubectl -n upg get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
kubectl -n cloud exec probe -- curl -m 3 -s -o /dev/null -w '%{http_code}\n' http://${OTHER}
```

### Task 5 — Binary checksum
```
mkdir -p /tmp/verify && cd /tmp/verify
V=$(kubectl version -o json | jq -r .serverVersion.gitVersion)
ARCH=$(uname -m); [ "$ARCH" = x86_64 ] && ARCH=amd64; [ "$ARCH" = aarch64 ] && ARCH=arm64
curl -fsSLO https://dl.k8s.io/release/$V/bin/linux/$ARCH/kubectl
curl -fsSLO https://dl.k8s.io/release/$V/bin/linux/$ARCH/kubectl.sha256
{
echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 -c -
echo x >> kubectl
echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 -c -
} 2>&1 | tee result.txt
```
On Linux use `sha256sum --check` instead of `shasum -a 256 -c`. The `.sha256` file contains only the hash, hence the two-space `hash  filename` format built by echo.

## Expected output
- Task 1: after overwrite, `Error: no matching signatures: ...` for the tag; the digest verify prints the payload JSON.
- Task 2: errors `maximum cpu usage per Container is 500m, but limit is 1` and `minimum cpu usage per Container is 50m, but request is 10m`; quota table `pods 4/4`, `requests.cpu 400m/1`, `limits.cpu 800m/2`, `requests.memory 512Mi/1Gi`, `limits.memory 1Gi/2Gi`.
- Task 3: dry-run lists `node/cks-worker already cordoned (server dry run)` and `evicting pod upg/web-... (server dry run)`.
- Task 4: first curl prints nothing and exits 28 (timeout); second prints `200`.
- Task 5: `kubectl: OK`, then `kubectl: FAILED` and `shasum: WARNING: 1 computed checksum did NOT match`.

## Why it works
- cosign signatures are OCI artifacts keyed by image digest; a moved tag points at a digest with no signature, so tag verification fails while the original digest still verifies. Hence always deploy by digest.
- LimitRange runs first (injects defaults, enforces bounds); ResourceQuota then counts the resulting requests/limits and object counts.
- `ipBlock.except` carves address holes out of a broad allow; on Calico pod IPs are matched as CIDRs.

## Common mistakes / exam gotchas
- Signing a tag (mutable) rather than a digest; verifying with the wrong key/path; forgetting `COSIGN_PASSWORD` prompts blocking scripts.
- Port 5000 in use on macOS; tag/push to wrong registry name.
- ResourceQuota on cpu/memory without LimitRange defaults: pods without resources are rejected with "must specify limits.cpu...".
- LimitRange `default` = limits, `defaultRequest` = requests; mixing them up. A request larger than the default limit is rejected.
- Upgrade: skipping the etcd backup; upgrading kubelet before `kubeadm upgrade apply`/`node`; forgetting `systemctl daemon-reload && systemctl restart kubelet`; forgetting uncordon; upgrading the worker's kubeadm but not running `kubeadm upgrade node`; skipping a minor version.
- `kubectl drain` without `--ignore-daemonsets` fails; without `--delete-emptydir-data` it refuses pods with emptyDir.
- ipBlock egress does not block traffic if another policy allows it (additive).

## Cleanup
```
docker rm -f mock-registry
kubectl delete ns team-b upg cloud sim
docker exec cks-control-plane rm -f /var/lib/etcd/mock-snapshot.db
rm -rf /tmp/cosign-lab /tmp/verify
```
