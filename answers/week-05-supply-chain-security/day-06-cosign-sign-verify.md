# Week 5 · Day 6 (Oct 25) — Image signing and verification with cosign — Answers
Task: [day-06-cosign-sign-verify.md](../../plan/week-05-supply-chain-security/day-06-cosign-sign-verify.md)

## Solution
1. Registry:
```
docker run -d --restart=always --name registry -p 127.0.0.1:5000:5000 registry:2
docker network connect kind registry
```
2. Keys:
```
mkdir -p workspace/week-05/day-06 && cd workspace/week-05/day-06
COSIGN_PASSWORD="" cosign generate-key-pair
ls cosign.key cosign.pub
```
3. Push:
```
docker tag hello-go:slim localhost:5000/app:v1
docker push localhost:5000/app:v1
docker pull busybox:1.36
docker tag busybox:1.36 localhost:5000/app:unsigned
docker push localhost:5000/app:unsigned
docker inspect --format '{{index .RepoDigests 0}}' localhost:5000/app:v1
docker inspect --format '{{index .RepoDigests 0}}' localhost:5000/app:unsigned
```
Save the first digest as `SIGNED=localhost:5000/app@sha256:...`.

4. Sign by digest (offline lab, no Rekor):
```
COSIGN_PASSWORD="" cosign sign --key cosign.key --tlog-upload=false --yes $SIGNED
```
5. Verify:
```
cosign verify --key cosign.pub --insecure-ignore-tlog=true $SIGNED
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5000/app:unsigned
```
(with a real registry and default signing, drop the two tlog flags.)

6. Kyverno HTTP registry access:
```
kubectl -n kyverno patch deploy kyverno-admission-controller --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--allowInsecureRegistry=true"}]'
kubectl -n kyverno rollout status deploy/kyverno-admission-controller
```
Check the first container is `kyverno` with `kubectl -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.spec.template.spec.containers[*].name}'`. (If `args` does not exist yet, use a JSON `add` of the whole `/args` array.)

7. Policy `verify-images.yaml` (paste your `cosign.pub` contents):
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-cosign-signature
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["signed"]
    verifyImages:
    - imageReferences:
      - "registry:5000/*"
      failureAction: Enforce
      mutateDigest: true
      verifyDigest: true
      required: true
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              <contents of cosign.pub>
              -----END PUBLIC KEY-----
            rekor:
              ignoreTlog: true
            ctlog:
              ignoreSCT: true
```
```
kubectl create ns signed
kubectl apply -f verify-images.yaml
kubectl get clusterpolicy require-signed-images
```
8.
```
kubectl -n signed run unsigned --image=registry:5000/app:unsigned
kubectl -n signed run signed-ok --image=registry:5000/app:v1
```
9.
```
kubectl -n signed get pod signed-ok -o jsonpath='{.spec.containers[0].image}{"\n"}'
```
10. Optional node pull config (run for each node):
```
for n in cks-control-plane cks-worker; do
docker exec $n mkdir -p /etc/containerd/certs.d/registry:5000
docker exec $n sh -c 'cat > /etc/containerd/certs.d/registry:5000/hosts.toml <<EOF
server = "http://registry:5000"

[host."http://registry:5000"]
  capabilities = ["pull", "resolve"]
EOF'
done
kubectl -n signed delete pod signed-ok --now
kubectl -n signed run signed-ok --image=registry:5000/app:v1
kubectl -n signed get pod signed-ok
```
This works when kind's containerd has `config_path = "/etc/containerd/certs.d"` (default in recent kind). It needs no containerd restart. Verify with `docker exec cks-worker crictl pull registry:5000/app:v1`.

## Expected output
Verify success:
```
Verification for localhost:5000/app@sha256:... --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The signatures were verified against the specified public key
[{"critical":{"identity":{"docker-reference":"localhost:5000/app"},"image":{"docker-manifest-digest":"sha256:..."},...}]
```
Unsigned verify: `Error: no signatures found` (or `no matching signatures`).
Kyverno rejection:
```
Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
resource Pod/signed/unsigned was blocked due to the following policies
require-signed-images:
  verify-cosign-signature: 'failed to verify image registry:5000/app:unsigned: .attestors[0].entries[0].keys: no signatures found'
```
Mutated image: `registry:5000/app@sha256:<digest>`.

## Why it works
The signature is stored beside the image as an OCI artifact and bound to the digest. Kyverno's `verifyImages` runs during mutating admission: it resolves the tag to a digest, fetches the signature from the registry, verifies it against the embedded public key, and (with `mutateDigest`) rewrites the tag to the verified digest so what runs is exactly what was verified. The unsigned image has no signature (and a different digest), so it cannot pass.

## Common mistakes / exam gotchas
- Signing a tag instead of a digest: warns that tags are mutable; signature still attaches to the resolved digest.
- Different digest, no signature: retagging or rebuilding an image creates a new digest that needs re-signing.
- Kyverno cannot reach `localhost:5000` from inside a pod (localhost is the pod itself): use the `kind` network alias `registry:5000`.
- HTTP registry without `--allowInsecureRegistry` gives an x509/`http: server gave HTTP response to HTTPS client` error.
- `imageReferences` must match the image string in the pod; `registry:5000/*` will not match `localhost:5000/...`. Images not matching any `imageReferences` are not verified at all (add a registry allow-list policy from Day 5 to close that gap).
- Forgetting `ignoreTlog`/`--insecure-ignore-tlog` when signing with `--tlog-upload=false` gives "no matching signatures" / missing bundle errors. With default Rekor upload you need internet.
- Newer cosign (3.x) defaults to the new bundle/referrers format and signing config; if Kyverno reports no signatures for a signed image, check `cosign tree` and consider signing with the legacy options (`--new-bundle-format=false`, `--use-signing-config=false`) or the Kyverno version's supported formats. Verify the flags with `cosign sign --help` on your version.
- Private key password prompt: set `COSIGN_PASSWORD` or the interactive prompt hangs scripts.
- `kubectl create -f` the policy CRs require Kyverno to be Ready first.
- Docker Desktop on macOS: the `kind` network exists only for kind-created clusters (`docker network ls`). Reaching the container by name uses Docker's embedded DNS; if the pod cannot resolve `registry`, check `docker exec cks-worker getent hosts registry`.

## Cleanup
```
kubectl delete clusterpolicy require-signed-images
kubectl delete ns signed
docker rm -f registry
```
Kyverno and the `--allowInsecureRegistry` flag may stay for Day 8, or reinstall/rollback: `kubectl -n kyverno rollout undo deploy/kyverno-admission-controller`.
