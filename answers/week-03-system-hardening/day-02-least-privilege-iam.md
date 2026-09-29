# Week 3 · Day 2 (Oct 8) — Least-privilege identity and access management — Answers
Task: [plan/week-03-system-hardening/day-02-least-privilege-iam.md](../../plan/week-03-system-hardening/day-02-least-privilege-iam.md)

## Solution
1. kubeconfig
```
chmod 600 ~/.kube/config
stat -f '%Lp' ~/.kube/config      # macOS; on Linux: stat -c '%a' ~/.kube/config
kubectl --context kind-cks get nodes
```
2. Restricted sudo on the node
```
docker exec -it cks-control-plane bash
which sudo || (apt-get update && apt-get install -y sudo)
useradd -m -s /bin/bash k8sops
visudo -f /etc/sudoers.d/k8sops
```
Content of the file:
```
k8sops ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet
```
Then:
```
chmod 440 /etc/sudoers.d/k8sops
visudo -c
sudo -l -U k8sops
su - k8sops -c 'sudo /usr/bin/systemctl restart kubelet'
su - k8sops -c 'sudo systemctl stop kubelet'
su - k8sops -c 'sudo cat /etc/shadow'
```
Confirm the systemctl path with `command -v systemctl` (on Debian-based images it is `/usr/bin/systemctl`, also reachable via `/bin`); the sudoers path must match what sudo resolves. If the node has no internet, `apt-get install` fails; then state the entry and validate it with `visudo -cf` on a file.

3. Non-root enforcement
```
kubectl create ns iam-lab
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: root-only
  namespace: iam-lab
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      runAsNonRoot: true
---
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-fixed
  namespace: iam-lab
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep","3600"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF
kubectl -n iam-lab get pods
kubectl -n iam-lab describe pod root-only | tail
kubectl -n iam-lab exec nonroot-fixed -- id
```
`root-only` stays in `CreateContainerConfigError`. (Adding `runAsUser: 1000` to stock `nginx` would start it but crash: it cannot write `/var/cache/nginx` or bind port 80. Use `nginxinc/nginx-unprivileged`, listening on 8080, for a real web server.)

4. Bonus
```
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-api
  namespace: iam-lab
automountServiceAccountToken: false
EOF
kubectl -n iam-lab run no-token --image=busybox --overrides='{"spec":{"serviceAccountName":"no-api"}}' -- sleep 3600
kubectl -n iam-lab exec no-token -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

## Expected output
```
600
NAME            READY   STATUS                       
root-only       0/1     CreateContainerConfigError
nonroot-fixed   1/1     Running
Error: container has runAsNonRoot and image will run as root (pod: "root-only_iam-lab(...)", container: nginx)
uid=1000 gid=0(root) groups=0(root)
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
```
`sudo -l -U k8sops` shows `(root) NOPASSWD: /usr/bin/systemctl restart kubelet`.

## Why it works
sudo matches the exact command line, so only `restart kubelet` is allowed. The kubelet validates the resolved UID before starting the container, so a root image is rejected pre-start. Disabling token automount removes the credential from the pod filesystem.

## Common mistakes / exam gotchas
- Editing `/etc/sudoers` directly without `visudo`: a syntax error locks out sudo for everyone.
- Wildcards (`systemctl *`) or `ALL` grant far more; `systemctl restart kubelet *` allows extra arguments.
- Sudoers drop-ins with wrong mode (not `0440`) or a filename with `.` or `~` are ignored.
- `runAsNonRoot: true` with an image using a non-numeric `USER` fails verification; set `runAsUser`.
- `runAsNonRoot` at pod level applies to all containers; container-level overrides pod-level.
- On kind, `docker exec` lands as root; use `su - k8sops` to test.

## Cleanup
```
kubectl delete ns iam-lab
userdel -r k8sops; rm /etc/sudoers.d/k8sops
```
