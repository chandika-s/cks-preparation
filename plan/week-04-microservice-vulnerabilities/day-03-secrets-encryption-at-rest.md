# Week 4 · Day 3 (Oct 14) — Managing Kubernetes Secrets: encryption at rest
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Configure API server encryption at rest for Secrets with `aescbc`.
- Modify the kube-apiserver static pod safely (flag, volume, volumeMount).
- Prove encryption by reading the raw value from etcd.

## Theory
By default Secrets are stored in etcd base64-encoded, not encrypted; anyone with etcd access (or a backup) can read them. Encryption at rest is configured on the kube-apiserver with an `EncryptionConfiguration` file passed via `--encryption-provider-config`.

Structure:
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc: {keys: [{name: key1, secret: <base64 of 16/24/32 bytes>}]}
      - identity: {}
```
- Providers are ordered: the **first** provider encrypts on write; **all** listed providers are tried on read. `identity: {}` (no encryption) last lets the API server still read pre-existing plaintext data. Putting `identity` first means writes stay unencrypted.
- Providers: `identity`, `aescbc` (AES-CBC, PKCS#7; 16/24/32-byte keys; weaker against padding-oracle style attacks, widely used in exams), `aesgcm` (fast, requires key rotation due to nonce limits), `secretbox` (XSalsa20-Poly1305, 32-byte key), `kms` v1/v2 (envelope encryption with external KMS, recommended for production).
- Only writes after enabling are encrypted. Existing Secrets must be rewritten: `kubectl get secrets -A -o json | kubectl replace -f -`.
- Key rotation: add a new key first in the list, restart apiserver(s), rewrite all secrets, then remove the old key.
- The config file contains key material: root-owned, mode 0600, on control-plane nodes only.
- Because the API server is a static pod, the file must be mounted into it (hostPath volume + volumeMount), otherwise the API server crash-loops.
- Verify in etcd: value starts with `k8s:enc:aescbc:v1:<keyname>:` instead of readable JSON/protobuf. Key path: `/registry/secrets/<namespace>/<name>`.
- etcd client TLS files on kubeadm/kind control planes: `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key` (also `healthcheck-client.crt/key`); endpoint `https://127.0.0.1:2379`.
- Static pod manifest: `/etc/kubernetes/manifests/kube-apiserver.yaml`; kubelet restarts the pod when the file changes. Never leave backup copies inside the manifests directory (kubelet would run them).

kind specifics: the control-plane is a Docker container `cks-control-plane`; get a shell with `docker exec -it cks-control-plane bash`. The node image has no `etcdctl` binary and likely no `vim`; use `kubectl exec` into the `etcd-cks-control-plane` pod (its image ships `etcdctl`), and edit the manifest with `sed`, or `docker cp` it out and back.

## Prerequisites
Cluster `kind-cks` running. Secrets are currently unencrypted (no `--encryption-provider-config` flag). Check: `docker exec cks-control-plane grep encryption /etc/kubernetes/manifests/kube-apiserver.yaml` prints nothing.

## Task
1. Before changing anything, create Secret `before-enc` in namespace `default` with key `data=plainvalue` and read it directly from etcd. Record that the value is readable.
2. On the control-plane node, create directory `/etc/kubernetes/enc` and an `EncryptionConfiguration` at `/etc/kubernetes/enc/enc.yaml` that:
   - encrypts `secrets`,
   - uses `aescbc` as the first provider with key name `key1` and a freshly generated random 32-byte key (base64-encoded),
   - keeps `identity` as a fallback provider.
   File mode 0600, owned by root.
3. Back up `/etc/kubernetes/manifests/kube-apiserver.yaml` to `/root/kube-apiserver.yaml.bak` (outside the manifests directory).
4. Edit the kube-apiserver static pod manifest: add `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`, and make the directory available inside the pod (read-only hostPath volume and matching volumeMount).
5. Wait for the API server to come back (`kubectl get nodes` works again, several tens of seconds of downtime is expected).
6. Create Secret `after-enc` in `default` with key `data=secretvalue`. Read `/registry/secrets/default/after-enc` from etcd and confirm ciphertext. State the exact prefix printed.
7. Confirm `before-enc` is still plaintext in etcd, then re-encrypt all Secrets in the cluster and confirm `before-enc` is now ciphertext.
8. Confirm `kubectl get secret after-enc -o jsonpath='{.data.data}' | base64 -d` still returns `secretvalue`.

## Check your work
- The kube-apiserver static pod is `Running` and `kubectl get pods -n kube-system` works.
- Raw etcd value of `after-enc` starts with `k8s:enc:aescbc:v1:key1:` and does not contain `secretvalue`.
- `before-enc` is plaintext (contains `plainvalue`) until step 7, and ciphertext afterwards.
- `kubectl get secret` through the API still returns decrypted data.

## Answer
[answers/week-04-microservice-vulnerabilities/day-03-secrets-encryption-at-rest.md](../../answers/week-04-microservice-vulnerabilities/day-03-secrets-encryption-at-rest.md) — Attempt the task first; only then open the answer.

## Cleanup
Encryption may be left enabled (harmless). Day 8 asks you to redo this from memory; the answer file's Cleanup section shows how to safely revert first.
