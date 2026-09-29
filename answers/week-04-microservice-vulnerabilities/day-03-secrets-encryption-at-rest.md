# Week 4 · Day 3 (Oct 14) — Managing Kubernetes Secrets: encryption at rest — Answers
Task: [day-03-secrets-encryption-at-rest](../../plan/week-04-microservice-vulnerabilities/day-03-secrets-encryption-at-rest.md)

## Solution
Define a reusable etcd helper (runs on your Mac, uses the etcd pod's `etcdctl`):
```
etcdget() {
  kubectl -n kube-system exec etcd-cks-control-plane -- etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get "$1" | hexdump -C | head -20
}
```
(On a real exam node with `etcdctl` installed, run the same command directly with `ETCDCTL_API=3`; use `... get /registry/secrets/default/after-enc | hexdump -C`.)

1. Baseline:
```
kubectl create secret generic before-enc --from-literal=data=plainvalue
etcdget /registry/secrets/default/before-enc
```
`plainvalue` is visible in the ASCII column.

2. Config on the node:
```
docker exec -it cks-control-plane bash
mkdir -p /etc/kubernetes/enc
KEY=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${KEY}
      - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/enc.yaml
```
3. Backup outside the manifests dir:
```
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
```
4. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` (no vim in the kind node: either `docker cp cks-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml .`, edit locally, and `docker cp` it back; or use an installed editor). Add:
```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
    volumeMounts:
    - mountPath: /etc/kubernetes/enc
      name: enc
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
    name: enc
```
(Append to the existing `command`, `volumeMounts`, `volumes` lists; do not duplicate the keys.)

5. Wait:
```
exit
until kubectl get nodes >/dev/null 2>&1; do sleep 3; done
```
If it does not return, on the node: `crictl ps -a | grep kube-apiserver` and `crictl logs <id>`, or `journalctl -u kubelet | tail`; usual causes are a YAML typo, wrong path, or missing volumeMount.

6. New Secret:
```
kubectl create secret generic after-enc --from-literal=data=secretvalue
etcdget /registry/secrets/default/after-enc
```
7. Re-encrypt existing:
```
etcdget /registry/secrets/default/before-enc
kubectl get secrets -A -o json | kubectl replace -f -
etcdget /registry/secrets/default/before-enc
```
8. `kubectl get secret after-enc -o jsonpath='{.data.data}' | base64 -d`

## Expected output
Encrypted value (abbreviated):
```
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
...
00000020  6b 38 73 3a 65 6e 63 3a  61 65 73 63 62 63 3a 76  |k8s:enc:aescbc:v|
00000030  31 3a 6b 65 79 31 3a ...                           |1:key1:.........|
```
No `secretvalue` in the ASCII column. Step 8 prints `secretvalue`.

## Why it works
The API server encrypts with the first provider on write and stores the provider prefix (`k8s:enc:aescbc:v1:key1:`) with the ciphertext so it knows which key to use on read. `identity` last lets it read old plaintext objects. `kubectl replace` of every Secret forces a write, hence re-encryption under `key1`. The hostPath mount is required since the API server runs in a container; the file on the node is otherwise invisible to it.

## Common mistakes / exam gotchas
- Forgetting the volume/volumeMount: apiserver crash-loops, `kubectl` unreachable.
- `identity` listed first: everything continues to be stored in plaintext.
- Key not exactly 16/24/32 bytes before base64 encoding (`head -c 32 /dev/urandom | base64`); typing a 32-char password and base64-ing it also works, but a wrong length fails startup.
- Backup file left in `/etc/kubernetes/manifests/` creates a second, conflicting static pod.
- Assuming existing Secrets get encrypted automatically.
- Removing the old key before rewriting all Secrets makes them unreadable.
- Only `secrets` resource is encrypted by this config; add `configmaps` etc. explicitly if required.
- Encryption at rest does not protect against anyone who can `kubectl get secret` (RBAC still matters) nor against reading the key file on the control-plane node.

## Cleanup
Leaving it enabled is fine. To revert cleanly (needed before redoing on Day 8):
1. In `enc.yaml` swap provider order: `identity: {}` first, `aescbc` second. Restart apiserver (touch the manifest: `docker exec cks-control-plane touch /etc/kubernetes/manifests/kube-apiserver.yaml` does not always trigger; edit and save, or `crictl stop` the apiserver container so kubelet recreates it).
2. `kubectl get secrets -A -o json | kubectl replace -f -` (rewrites as plaintext).
3. Remove the `--encryption-provider-config` flag, the volumeMount and the volume from the manifest; wait for restart.
4. `docker exec cks-control-plane rm -rf /etc/kubernetes/enc /root/kube-apiserver.yaml.bak`
5. `kubectl delete secret before-enc after-enc`
