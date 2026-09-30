# Week 3 · Day 2 (Oct 8) — Least-privilege identity and access management
**Domain:** System Hardening (10%) — Least-privilege IAM | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Lock down kubeconfig file permissions and verify them.
- Grant a non-root OS user exactly one privileged command through `sudoers`.
- Enforce non-root execution of containers with `securityContext` and diagnose the failure modes.

## Theory
Least privilege applies at the OS layer as well as through RBAC.

- **Host access:** do not run admin tools or daemons as root when avoidable; give people individual accounts and grant specific commands via `sudo`, not blanket `ALL`. Disable direct root SSH login and password auth where relevant.
- **sudoers:** edit only with `visudo` (syntax check prevents lockout); use `visudo -f /etc/sudoers.d/<name>` for drop-ins (file mode `0440`, owned by root). Entry form: `user HOST=(runas) [NOPASSWD:] /full/path/cmd args`. Always use absolute command paths; a wildcard or a path in a user-writable directory defeats the restriction. Inspect with `sudo -l -U <user>`.
- **Credential files:** `~/.kube/config` holds cluster credentials and should be `600` and owned by the user. On control-plane nodes `/etc/kubernetes/admin.conf`, `/etc/kubernetes/pki/*.key` and manifests are root-owned (`600`/`644`).
- **Tokens and cloud IAM:** prefer short-lived, audience-bound projected service-account tokens (`serviceAccountToken` projected volume with `expirationSeconds`), `automountServiceAccountToken: false` where the API is not needed, and scoped cloud IAM roles (IRSA / Workload Identity) instead of node-wide roles.
- **Pod securityContext:** `runAsNonRoot: true` makes the kubelet refuse to start a container whose effective UID is 0 (error `CreateContainerConfigError: container has runAsNonRoot and image will run as root`). It checks the numeric UID; if the image declares a non-numeric `USER`, set `runAsUser` explicitly. `runAsUser`, `runAsGroup`, `fsGroup` set identities. Pair with `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`.
- Useful: `stat -c '%a %U %n' <file>`, `id`, `kubectl describe pod`, `kubectl get events`.

## Prerequisites
none

## Exam-style question
Context: cluster `kind-cks`, node `cks-control-plane`, and namespace `iam-lab`. Task: apply least privilege to the workstation, node and workloads. The kubeconfig must be readable only by its owner; a new node user `k8sops` must be able to restart kubelet as root and do nothing else with elevated rights; pod `nonroot-fixed` in `iam-lab` must run as UID 1000 with no privilege escalation and no capabilities, while a plain `nginx` pod `root-only` must be refused when non-root is enforced. Requirements: `kubectl --context kind-cks get nodes` must still work, the node must return to `Ready`, and pod `no-token` using ServiceAccount `no-api` must have no API token mounted.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. On your workstation, set `~/.kube/config` to permission `600` and confirm the mode and that `kubectl --context kind-cks get nodes` still works.
2. On node `cks-control-plane` (`docker exec -it cks-control-plane bash`): create Linux user `k8sops` (home directory, bash shell). Using `visudo`, create `/etc/sudoers.d/k8sops` so that `k8sops` may run exactly `/usr/bin/systemctl restart kubelet` as root without a password and nothing else. If `sudo` is not installed on the node, install it first. Verify as `k8sops` that restarting kubelet works and that `sudo systemctl stop kubelet` and `sudo cat /etc/shadow` are denied.
3. Namespace `iam-lab`. Create pod `root-only` using image `nginx` with container-level `securityContext.runAsNonRoot: true` (no `runAsUser`). Observe and record why it does not start. Then create pod `nonroot-fixed` that runs successfully as UID 1000 with `runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, using an image that supports non-root operation (e.g. `nginxinc/nginx-unprivileged` or `busybox` running `sleep 3600`).
4. Bonus (service-account hygiene): in `iam-lab` create ServiceAccount `no-api` with `automountServiceAccountToken: false` and pod `no-token` (image `busybox`, `sleep 3600`) using it; show no token is mounted.

## Check your work
- `stat -c '%a' ~/.kube/config` prints `600`.
- `sudo -l -U k8sops` on the node lists only the single kubelet-restart command.
- `sudo systemctl stop kubelet` as `k8sops` prompts/denies; `sudo systemctl restart kubelet` succeeds and node returns `Ready`.
- `kubectl -n iam-lab describe pod root-only` shows the `runAsNonRoot` error; `nonroot-fixed` is `Running` and `kubectl exec ... -- id` prints `uid=1000`.
- `/var/run/secrets/kubernetes.io/serviceaccount` does not exist in `no-token`.

## Answer
[answers/week-03-system-hardening/day-02-least-privilege-iam.md](../../answers/week-03-system-hardening/day-02-least-privilege-iam.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns iam-lab
```
On the node: `userdel -r k8sops; rm /etc/sudoers.d/k8sops`.
