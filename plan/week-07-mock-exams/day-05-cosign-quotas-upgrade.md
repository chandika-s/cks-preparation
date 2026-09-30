# Week 7 · Day 5 (Nov 9) — Mixed set: cosign + quotas + upgrade reasoning
**Domain:** Supply Chain Security (20%) + Minimize Microservice Vulnerabilities (20%) + Cluster Hardening (15%) + Cluster Setup (15%) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Sign and verify an image end-to-end with cosign against a local registry, including a tamper scenario.
- Configure ResourceQuota and LimitRange together and predict their combined effect.
- Recite and write out the kubeadm upgrade sequence and node drain mechanics; apply the parts that work on kind.
- Block metadata-endpoint egress with an `ipBlock` policy and verify a binary against a published checksum.

## Theory
**cosign (v2.x usage).** Key-based flow: `cosign generate-key-pair` (creates `cosign.key`, `cosign.pub`; password from `COSIGN_PASSWORD`), `cosign sign --key cosign.key <image@digest>`, `cosign verify --key cosign.pub <image>`. Signatures are stored as OCI artifacts in the same repository (tag `sha256-<digest>.sig`). Sign by digest, not mutable tag. With a private registry and no Rekor, use `--tlog-upload=false` on sign and `--insecure-ignore-tlog=true` on verify. `cosign tree` shows attached signatures. `localhost:<port>` registries are treated as insecure HTTP by the client library. Flag names differ in cosign 3.x; if a flag is rejected, consult `cosign sign --help`. Cluster enforcement is done by an admission policy (Kyverno `verifyImages`, Connaisseur, policy-controller).

**ResourceQuota.** Per-namespace caps: `pods`, `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory`, `count/<resource>`, `persistentvolumeclaims`, `requests.storage`. When a quota covers cpu/memory, every pod must set those values or be rejected (unless a LimitRange injects defaults). Exceeding quota fails at admission (for Deployments, the ReplicaSet event shows `exceeded quota`). `kubectl describe quota` shows used/hard.

**LimitRange.** Per-namespace, per-type (`Container`, `Pod`, `PersistentVolumeClaim`): `default` (limit), `defaultRequest`, `max`, `min`, `maxLimitRequestRatio`. Applied at admission: defaults are injected, out-of-range values rejected. Existing pods unaffected.

**kubeadm upgrade sequence.** One minor version at a time; kubeadm first. Control plane node: back up etcd; upgrade `kubeadm` package (`apt-mark unhold`/`hold` around installs); `kubeadm upgrade plan`; `kubeadm upgrade apply v1.X.Y`; drain the node; upgrade `kubelet` and `kubectl`; `systemctl daemon-reload && systemctl restart kubelet`; uncordon. Additional control plane nodes and workers: upgrade kubeadm, `kubeadm upgrade node`, drain, upgrade kubelet, restart, uncordon. Skew: kubelet must not be newer than kube-apiserver (up to three minors older is supported for kubelet in recent releases); kubectl within one minor of the API server; kube-proxy same as kubelet policy. `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` cordons and evicts, honouring PodDisruptionBudgets; `--dry-run=server` shows what it would do; `kubectl uncordon` reverses cordon.
kind caveat: nodes are containers created from a node image; the standard in-place `apt` upgrade is not how kind is upgraded (recreate the cluster with a newer `kindest/node`). Treat the upgrade portion as a written runbook plus the drain/cordon mechanics that do work.

**Metadata endpoint.** Cloud metadata (169.254.169.254) exposes node credentials; block it with an egress NetworkPolicy using `ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}`. There is no metadata service on kind; verify enforcement using a stand-in address.

**Binary verification.** Official checksums at `https://dl.k8s.io/release/<version>/bin/<os>/<arch>/<binary>.sha256`. `echo "<sha256>  <file>" | sha256sum --check` (macOS: `shasum -a 256 -c`).

## Prerequisites
- Docker on the host (for a local registry), `cosign` installed (2.x), `jq`, `curl`, `crane` optional.
- Port 5001 free on the host (macOS uses 5000 for AirPlay Receiver).
- Nodes `cks-control-plane`, `cks-worker` up.

## Exam-style question
_Real exam gives only this; the steps under Task are guided practice._

### Q1 (30%) cosign sign, verify, tamper
Context: `kubectl config use-context kind-cks`. Run a local registry `mock-registry` (`registry:2`, host port 5001) and push `busybox:1.36` as `localhost:5001/mock/app:v1`. With a cosign key pair in `/tmp/cosign-lab` (empty password), sign the image by digest without a transparency log and save the successful verification JSON to `/tmp/cosign-lab/verify-ok.json`. Then overwrite the tag with `alpine:3.20` and save to `/tmp/cosign-lab/verify-tamper.txt` proof that verifying the tag fails while the original digest still verifies. Also show that a second key pair in `/tmp/cosign-lab/other` cannot verify the original digest.

### Q2 (25%) ResourceQuota and LimitRange
Context: `kubectl config use-context kind-cks`. In namespace `team-b`, create ResourceQuota `team-b-quota` (4 pods, `requests.cpu` 1, `requests.memory` 1Gi, `limits.cpu` 2, `limits.memory` 2Gi, 1 PVC) and LimitRange `team-b-limits` (container default limit 200m/256Mi, default request 100m/128Mi, max 500m/512Mi, min 50m/64Mi). Pod `p-default` must receive the defaults; Pods `p-big` (limit cpu `1`) and `p-tiny` (request cpu `10m`) must be rejected, with both errors saved to `/tmp/limitrange-errors.txt`. Deployment `filler` (`nginx:1.27`, 5 replicas) must be created, and `/tmp/quota-used.txt` must show how many pods run, why, and the quota Used versus Hard.

### Q3 (20%) Upgrade runbook and drain mechanics
Context: `kubectl config use-context kind-cks`. Write `/tmp/upgrade-runbook.md` with ordered steps and exact commands to upgrade this cluster (`cks-control-plane`, `cks-worker`) from v1.34.x to v1.35.x with kubeadm on Debian/Ubuntu, covering etcd backup, version skew, package holds and verification, using `1.35.X` placeholders. Take a verified etcd snapshot at `/var/lib/etcd/mock-snapshot.db` on the control plane. In namespace `upg`, run Deployment `web` (`nginx:1.27`, 3 replicas) with PodDisruptionBudget `web-pdb` (`minAvailable: 2`). Save a server-side dry-run drain of `cks-worker` to `/tmp/drain-dryrun.txt`, explain there why a real drain would stall, and leave the node schedulable.

### Q4 (15%) Metadata egress block
Context: `kubectl config use-context kind-cks`. In namespace `cloud`, create NetworkPolicy `block-metadata` selecting all pods that allows all egress except to `169.254.169.254/32`. Prove enforcement using Pod `metadata-sim` (`nginx:1.27`) in namespace `sim` as a stand-in for the metadata endpoint, and Pod `probe` (`curlimages/curl:8.10.1`) in `cloud`: requests to the stand-in must time out and requests to any other pod IP must succeed.

### Q5 (10%) Verify a binary checksum
Context: `kubectl config use-context kind-cks`. Download the `kubectl` binary matching the cluster's server version for your `linux` architecture, with its `.sha256` from `dl.k8s.io`, into `/tmp/verify`. Show the checksum verification passing, then failing after the binary is altered, and save both outputs to `/tmp/verify/result.txt`.

## Task
Total 90 min / 100 points.

### Task 1 — cosign sign / verify / tamper (25 min, 30 pts)
1. Start a local registry container `mock-registry` publishing host port 5001 (image `registry:2`).
2. Tag `busybox:1.36` as `localhost:5001/mock/app:v1` and push it. Record the digest.
3. In `/tmp/cosign-lab`, generate a key pair (empty password).
4. Sign the image by digest (no transparency log upload).
5. Verify with the public key by tag and by digest and save the successful verification JSON to `/tmp/cosign-lab/verify-ok.json`.
6. Tamper: push `alpine:3.20` to the same tag `localhost:5001/mock/app:v1`. Show that verifying the tag now fails (`no signatures found` / `no matching signatures`), and that verifying the original digest still succeeds. Save output to `/tmp/cosign-lab/verify-tamper.txt`.
7. Generate a second key pair in `/tmp/cosign-lab/other` and show verification of the original digest with that public key fails.

### Task 2 — ResourceQuota + LimitRange (20 min, 25 pts)
Namespace `team-b`:
1. ResourceQuota `team-b-quota`: max 4 pods, `requests.cpu` 1, `requests.memory` 1Gi, `limits.cpu` 2, `limits.memory` 2Gi, 1 PersistentVolumeClaim.
2. LimitRange `team-b-limits` (type Container): default limit cpu 200m / memory 256Mi; default request cpu 100m / memory 128Mi; max cpu 500m / memory 512Mi; min cpu 50m / memory 64Mi.
3. Create Pod `p-default` (`nginx:1.27`, no resources) and confirm the injected values.
4. Show Pod `p-big` (`nginx:1.27`, limit cpu `1`) is rejected and Pod `p-tiny` (`nginx:1.27`, request cpu `10m`) is rejected. Save both error messages to `/tmp/limitrange-errors.txt`.
5. Create Deployment `filler` (`nginx:1.27`, 5 replicas). Determine how many pods run, why, and record the quota `Used` versus `Hard` table in `/tmp/quota-used.txt`.

### Task 3 — Upgrade runbook and drain mechanics (20 min, 20 pts)
1. Write `/tmp/upgrade-runbook.md`: numbered, ordered steps and exact commands for upgrading this cluster (one control plane node `cks-control-plane`, one worker `cks-worker`) from v1.34.x to v1.35.x with kubeadm on Debian/Ubuntu nodes, including etcd backup, version skew statement, package hold handling, and verification. Use placeholders `1.35.X`.
2. Take a real etcd snapshot through the etcd static pod to `/var/lib/etcd/mock-snapshot.db` on the control plane node and verify it with `etcdctl snapshot status`.
3. In namespace `upg` create Deployment `web` (`nginx:1.27`, 3 replicas) and a PodDisruptionBudget `web-pdb` with `minAvailable: 2`.
4. Cordon `cks-worker`, show `SchedulingDisabled`, run `kubectl drain cks-worker --ignore-daemonsets --delete-emptydir-data --dry-run=server` and save the output to `/tmp/drain-dryrun.txt`, then uncordon. Explain in the file why a real drain here would stall.

### Task 4 — Metadata egress block (10 min, 15 pts)
1. Namespace `cloud`, NetworkPolicy `block-metadata` selecting all pods: all egress allowed except to `169.254.169.254/32`.
2. Namespace `sim` with Pod `metadata-sim` (`nginx:1.27`). Add the pod's IP as a second `except` entry (`/32`) to prove enforcement.
3. From Pod `probe` (`curlimages/curl:8.10.1`, `sleep 3600`) in `cloud`: `curl -m 3` to `metadata-sim`'s pod IP must time out, and `curl -m 3` to another pod IP (e.g. `catalog` from Day 4 or any nginx pod) must succeed.

### Task 5 — Verify a binary against its checksum (10 min, 10 pts)
1. Determine the cluster's server version from `kubectl version`.
2. Download `kubectl` for `linux/<your arch>` at that version and its `.sha256` from `dl.k8s.io` into `/tmp/verify`.
3. Verify it and print OK; then append one byte to the binary and show that verification now fails. Save both outputs to `/tmp/verify/result.txt`.

## Check your work
- Task 1: `verify-ok.json` shows the critical identity with your digest; tag verification after overwrite fails; wrong key fails; `cosign tree` lists a `.sig` for the original digest only.
- Task 2: `p-default` shows requests 100m/128Mi and limits 200m/256Mi; errors mention `maximum cpu usage per Container is 500m` and `minimum cpu usage per Container is 50m`; filler runs exactly (4 minus existing pods) pods.
- Task 3: snapshot status prints hash/revision/total keys; runbook order: backup, kubeadm package, plan, apply, drain, kubelet, restart, uncordon, worker `upgrade node`; drain dry-run lists pods to evict; node returns Ready without SchedulingDisabled.
- Task 4: timeout to the stand-in IP, HTTP response from the other pod.
- Task 5: `kubectl: OK` then `kubectl: FAILED` with a warning that computed checksum did NOT match.

## Answer
[answers/week-07-mock-exams/day-05-cosign-quotas-upgrade.md](../../answers/week-07-mock-exams/day-05-cosign-quotas-upgrade.md) — Attempt the task first; only then open the answer.

## Cleanup
```
docker rm -f mock-registry
kubectl delete ns team-b upg cloud sim
docker exec cks-control-plane rm -f /var/lib/etcd/mock-snapshot.db
rm -rf /tmp/cosign-lab /tmp/verify
```
