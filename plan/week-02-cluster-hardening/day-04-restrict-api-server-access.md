# Week 2 · Day 4 (Oct 3) — Restrict access to the Kubernetes API
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Inspect and harden kube-apiserver flags in the static pod manifest.
- Understand anonymous auth, NodeRestriction and profiling, and their effect.
- Safely edit a static pod manifest and recover if the API server breaks.

## Theory
- Request path: authentication -> authorization -> admission. Harden each stage.
- `--anonymous-auth=false`: unauthenticated requests are rejected with 401 instead of being treated as `system:anonymous` / `system:unauthenticated` (which RBAC can still grant, e.g. `/healthz`, `/version` via `system:public-info-viewer`). CIS 1.2.1 recommends false. Caveat: kubeadm's apiserver probes (`/livez`, `/readyz`) are unauthenticated; with anonymous auth off they can return 401 and the kubelet may restart the apiserver. Newer versions allow restricting anonymous access to specific paths via `AuthenticationConfiguration` (`anonymous.enabled` with `conditions`), which cannot be combined with the `--anonymous-auth` flag.
- Insecure port (`--insecure-port`) was removed in v1.24; verify it is not present. Also verify no `--token-auth-file`, and that `--authorization-mode` is `Node,RBAC` (never `AlwaysAllow`).
- `NodeRestriction` admission plugin (`--enable-admission-plugins=NodeRestriction`, on by default with kubeadm): a kubelet (identity `system:node:<name>`, group `system:nodes`) can modify only its own Node object and Pods bound to it, and cannot set/modify labels with `node-restriction.kubernetes.io/` prefix. Requires `Node` authorization mode.
- `--profiling=false`: disables `/debug/pprof` endpoints (information disclosure, CIS 1.2.x).
- Related flags to know: `--kubelet-certificate-authority`, `--tls-min-version`, `--service-account-lookup=true`, `--audit-log-path`, `--encryption-provider-config`.
- Static pods: manifests in `/etc/kubernetes/manifests/`; the kubelet watches the directory and recreates the pod on change. Never leave backup copies inside that directory; every file there is loaded as a pod.
- While the apiserver restarts, `kubectl` fails; use `crictl ps`, `crictl logs` on the node to debug. Container runtime on kind nodes is containerd.
- Health: `kubectl get --raw='/readyz?verbose'`, `/livez`.

## Prerequisites
None. Have a second terminal ready. Take a backup outside the manifests directory before editing.

## Task
1. Open a shell in the control-plane node: `docker exec -it cks-control-plane bash`.
2. Copy `/etc/kubernetes/manifests/kube-apiserver.yaml` to `/root/kube-apiserver.yaml.bak` (not inside the manifests directory).
3. Inspect the current values of: `--anonymous-auth`, `--profiling`, `--enable-admission-plugins`, `--authorization-mode`, and check that no insecure port or token auth file flags exist. Note the results.
4. From inside the node, record the response of an unauthenticated `curl -k https://localhost:6443/version` and `https://localhost:6443/api/v1/namespaces` before any change.
5. Edit the manifest so that: `--profiling=false`, `--enable-admission-plugins` includes `NodeRestriction`, and `--anonymous-auth=false`. Do not remove any other existing flag.
6. Wait for the API server to restart; confirm it returns to healthy with `kubectl get --raw='/readyz'` and that `kubectl get nodes` works.
7. Repeat the unauthenticated `curl` calls from step 4 and record the difference.
8. If the API server does not stabilise (restart loops because probes fail), diagnose with `crictl`, then restore or adjust so the cluster is healthy again, and explain what happened. The final state must have the API server healthy with `--profiling=false` and `NodeRestriction` enabled.

## Check your work
- `crictl ps | grep kube-apiserver` (in the node) shows a running, recently restarted container.
- `kubectl get --raw='/readyz'` prints `ok`.
- `ps aux | grep kube-apiserver` (in the node) shows `--profiling=false` and `NodeRestriction` in the plugin list.
- If anonymous auth is disabled and stable, unauthenticated `/version` returns 401 rather than JSON.
- Backup file exists in `/root` and no extra files are in `/etc/kubernetes/manifests/`.

## Answer
[answers/week-02-cluster-hardening/day-04-restrict-api-server-access.md](../../answers/week-02-cluster-hardening/day-04-restrict-api-server-access.md) — Attempt the task first; only then open the answer.

## Cleanup
The state should be a working hardened API server. If you reverted `--anonymous-auth`, that is fine. Tasks on later days assume `kubectl` works.
