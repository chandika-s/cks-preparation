# Week 1 · Day 3 (Sep 25) — CIS benchmark with kube-bench — Answers
Task: [plan/week-01-cluster-setup/day-03-cis-kube-bench.md](../../plan/week-01-cluster-setup/day-03-cis-kube-bench.md)

## Solution
1. Run the job:
```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml
kubectl wait --for=condition=complete job/kube-bench-master --timeout=180s
kubectl logs job/kube-bench-master > ~/kube-bench-before.txt
```
`job-master.yaml` already has a control-plane nodeSelector and tolerations; verify with `kubectl get pod -o wide`. kube-bench auto-detects the benchmark from the server version; if it fails for v1.35, download the YAML, and add `--benchmark cis-1.10` (or the newest benchmark in the kube-bench `cfg/` directory) to the container `command`/`args`, then apply it. Exact benchmark ID availability depends on the kube-bench release; check the kube-bench README/cfg directory.

2. Review:
```bash
grep -E '^\[FAIL\]' ~/kube-bench-before.txt
```

3. Fixes. Likely FAILs on a default kind/kubeadm control plane: 1.1.1/1.1.3/1.1.5/1.1.7 (manifest files are 644, benchmark wants 600 or stricter), 1.2.x `--profiling=false` on apiserver, 1.3.2 `--profiling=false` on controller-manager, 1.4.1 `--profiling=false` on scheduler. Pick from what your log shows.

a. Permissions:
```bash
docker exec cks-control-plane bash -c 'chmod 600 /etc/kubernetes/manifests/*.yaml; stat -c "%a %U:%G %n" /etc/kubernetes/manifests/*'
```
b. kube-apiserver `--profiling=false`:
```bash
docker exec cks-control-plane bash -c "cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak && sed -i '/^    - kube-apiserver\$/a\    - --profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml && grep -n profiling /etc/kubernetes/manifests/kube-apiserver.yaml"
```
c. kube-scheduler:
```bash
docker exec cks-control-plane bash -c "cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.bak && sed -i '/^    - kube-scheduler\$/a\    - --profiling=false' /etc/kubernetes/manifests/kube-scheduler.yaml"
```
Equivalent for controller-manager: match `- kube-controller-manager`. Alternatively open the file in `vi` on the node and add `- --profiling=false` under `spec.containers[0].command`, same indentation as the other flags.

4. Wait:
```bash
kubectl get pods -n kube-system -w
kubectl get --raw /readyz
```
The API server is unreachable for up to about a minute while the static pod restarts.

5. Re-run:
```bash
kubectl delete job kube-bench-master
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml
kubectl wait --for=condition=complete job/kube-bench-master --timeout=180s
kubectl logs job/kube-bench-master > ~/kube-bench-after.txt
diff <(grep -E '^\[(PASS|FAIL)\]' ~/kube-bench-before.txt) <(grep -E '^\[(PASS|FAIL)\]' ~/kube-bench-after.txt)
```

6. `--anonymous-auth=false` on kube-apiserver: add the flag to the apiserver manifest. Risk: kubeadm static pod liveness/readiness/startup probes call `/livez`, `/readyz` unauthenticated; with anonymous auth off they get 401 and the kubelet may kill the apiserver in a restart loop. Newer Kubernetes (structured `AuthenticationConfiguration` with `anonymous.conditions` limiting anonymous access to health endpoints) is the safe path; otherwise the finding is often left as an accepted risk or paired with the probes' config. On the exam, follow the question's explicit instruction and verify the pod stays healthy.

## Expected output
```
== Summary master ==
N checks PASS
M checks FAIL
K checks WARN
0 checks INFO
```
After fixes, the diff shows lines flipping from `[FAIL] 1.1.1 ...` to `[PASS] 1.1.1 ...` and similarly for the profiling checks; M decreases by at least three.

## Why it works
kube-bench reads the same files and process arguments (from the host mounts) that the components use: file modes via `stat`, flags via the running process command line. The kubelet reconciles static pods from the manifest directory, so editing the manifest recreates the pod with the new flag.

## Common mistakes / exam gotchas
- YAML indentation errors in a static pod manifest: the pod disappears; check `crictl ps -a` and `journalctl -u kubelet` on the node.
- Leaving `.bak` copies in `/etc/kubernetes/manifests/`; keep backups elsewhere.
- Running `job.yaml`/`job-node.yaml` and expecting control-plane sections; use `job-master.yaml` for master and `job-node.yaml` for worker checks.
- Some checks (ownership `etcd:etcd` on `/var/lib/etcd`, PKI ownership) are not fixable as stated on kind because the `etcd` user does not exist on the node image; state that limitation.
- kind is a container: some kubelet or host-file checks reflect the node container, not a VM; treat unfixable items honestly.
- `[WARN]` are manual checks, not failures; read the remediation text.

## Cleanup
```bash
kubectl delete job kube-bench-master
```
