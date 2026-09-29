# Week 3 · Day 5 (Oct 11) — AppArmor + review — Answers
Task: [plan/week-03-system-hardening/day-05-apparmor-and-review.md](../../plan/week-03-system-hardening/day-05-apparmor-and-review.md)

## Solution
Part A. On kind/macOS, AppArmor is normally unavailable in the Docker VM: `aa-status` fails or reports the module not loaded, and `apparmor_parser` is missing. Treat this as a walkthrough; the commands below are correct for a host with AppArmor (killer.sh, exam).

1. Profile
```
docker exec -it cks-worker bash
cat > /etc/apparmor.d/k8s-deny-tmp-write <<'EOF'
#include <tunables/global>
profile k8s-deny-tmp-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  capability,
  network,
  deny /tmp/** w,
}
EOF
```
2. Load
```
apparmor_parser -q /etc/apparmor.d/k8s-deny-tmp-write
aa-status | grep k8s-deny-tmp-write
```
3. Pods
```
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aa-test
  annotations:
    container.apparmor.security.beta.kubernetes.io/main: localhost/k8s-deny-tmp-write
spec:
  nodeName: cks-worker
  containers:
  - name: main
    image: busybox
    command: ["sleep","3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: aa-test-ga
spec:
  nodeName: cks-worker
  containers:
  - name: main
    image: busybox
    command: ["sleep","3600"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-tmp-write
EOF
```
4. Verify
```
kubectl exec aa-test -- touch /tmp/x
kubectl exec aa-test -- touch /root/x
kubectl exec aa-test -- cat /proc/1/attr/current
```
5. Missing profile
```
kubectl run aa-missing --image=busybox --overrides='{"spec":{"nodeName":"cks-worker","containers":[{"name":"aa-missing","image":"busybox","command":["sleep","3600"],"securityContext":{"appArmorProfile":{"type":"Localhost","localhostProfile":"does-not-exist"}}}]}}'
kubectl describe pod aa-missing | tail
```
The pod does not run (blocked/`CreateContainerError`; message says the profile is not loaded). The same happens for every pod on a node without AppArmor.

Part B model answers
1. Examples (any three): (a) disable/remove unneeded services and packages (fewer daemons and vulnerable binaries); (b) blacklist unused kernel modules (fewer kernel code paths and privilege-escalation bugs); (c) close/limit listening ports and use a host firewall (less network exposure); (d) restrict `sudo`/root use and file permissions (limits post-compromise blast radius); (e) apply seccomp/AppArmor (limits what a compromised container can do to the kernel/host).
2. Fragments:
```
securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: profiles/audit.json
```
```
securityContext:
  seccompProfile:
    type: RuntimeDefault
```
Profile file lives at `/var/lib/kubelet/seccomp/profiles/audit.json` on the node running the pod.
3. Annotation: `container.apparmor.security.beta.kubernetes.io/<container-name>: localhost/<profile-name>` (alternatives `runtime/default`, `unconfined`). `<container-name>` must match the container name; `<profile-name>` is the name in the profile header, loaded by `apparmor_parser` on the node where the pod runs (check `aa-status`). GA form: `securityContext.appArmorProfile.type: Localhost` + `localhostProfile: <profile-name>`. Profile must be loaded in the kernel of every node the pod may schedule on.

## Expected output
```
touch: /tmp/x: Permission denied
command terminated with exit code 1
(touch /root/x prints nothing, exit 0)
k8s-deny-tmp-write (enforce)
```

## Why it works
The kernel LSM checks each file operation of the confined process against the loaded profile; `deny /tmp/** w` overrides the broad `file,` allow. The runtime asks runc to transition the container to the named profile at exec, which fails if the profile is not loaded.

## Common mistakes / exam gotchas
- Using the filename rather than the profile name from the header.
- Container name in the annotation key not matching the container.
- Forgetting `localhost/` prefix in the annotation value.
- Profile loaded on one node but pod scheduled on another.
- Loading a profile that is not persistent: it is lost at reboot unless stored in `/etc/apparmor.d/` and loaded at boot.
- Mixing `deny` with owner-specific or missing trailing comma on rules (syntax error at load).
- The annotation is deprecated in current versions; the exam may still use it. Know both.

## Cleanup
```
kubectl delete pod aa-test aa-test-ga aa-missing --ignore-not-found
apparmor_parser -R /etc/apparmor.d/k8s-deny-tmp-write; rm /etc/apparmor.d/k8s-deny-tmp-write
```
