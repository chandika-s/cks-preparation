# Week 5 · Day 6 (Oct 25) — Image signing and verification with cosign
**Domain:** Supply Chain Security (20%) — Secure your supply chain (signing, verification) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Generate a cosign key pair, sign an image in a registry, and verify it.
- Enforce signature verification at admission with a Kyverno `verifyImages` policy.
- Show that an unsigned image is rejected while a signed one is admitted.

## Theory
Sign images at build/push time (`cosign sign`) and verify the signature at admission time so only attested images run.

- cosign (Sigstore) stores the signature as an OCI artifact in the same repository, tied to the image **digest** (tag `sha256-<digest>.sig` in legacy format; newer cosign 3.x may use the OCI referrers/bundle format). Sign digests, not tags: a tag can move, but a signature applies to a specific digest.
- Key-based flow: `cosign generate-key-pair` produces `cosign.key` (encrypted private key, password prompt; set `COSIGN_PASSWORD` to script it) and `cosign.pub`.
- `cosign sign --key cosign.key <image>`; `cosign verify --key cosign.pub <image>` prints the verified payload JSON. By default cosign also uses the Rekor transparency log; for an offline lab use `--tlog-upload=false` when signing and `--insecure-ignore-tlog=true` when verifying.
- Keyless signing (OIDC identity + Fulcio + Rekor) exists; the exam-level flow is key-based.
- Other cosign commands: `cosign attest` / `verify-attestation` (SBOM/provenance predicates), `cosign tree`, `cosign triangulate`.
- Kyverno `verifyImages` rule: `imageReferences` (globs), `attestors[].entries[].keys.publicKeys` (PEM), optional `rekor.ignoreTlog`, `ctlog.ignoreSCT`; `mutateDigest: true` (default) rewrites tags to digests; `verifyDigest: true` and `required: true` (default) enforce. `failureAction: Enforce` on the `verifyImages` entry blocks unsigned images.
- Kyverno pods must be able to reach the registry to fetch the signature. A registry served over plain HTTP needs the admission controller flag `--allowInsecureRegistry=true`.
- Lab registry design on kind: run `registry:2` on the host, publish `127.0.0.1:5000`, and also attach it to the `kind` docker network so in-cluster clients resolve it as `registry:5000`. Push/sign from the host as `localhost:5000/...`; refer to it from the cluster as `registry:5000/...`. Both names address the same repository and digest, so a signature made via one verifies via the other.
- Node pulls from an HTTP registry need containerd config on each node (`/etc/containerd/certs.d/registry:5000/hosts.toml`); admission tests do not need the pod to actually run.

## Prerequisites
- Day 5: Kyverno installed in namespace `kyverno`.
- Day 1: local images `hello-go:slim` (or any image you built).
- `docker`, `cosign` on the host.

## Task
1. Start a local registry: container `registry` (image `registry:2`), published on host `127.0.0.1:5000`, restart policy always, and connected to the `kind` docker network.
2. In `workspace/week-05/day-06/`, generate a cosign key pair (empty password is fine for the lab).
3. Tag `hello-go:slim` as `localhost:5000/app:v1` and push it. Also pull `busybox:1.36`, tag it `localhost:5000/app:unsigned`, and push it. Record the digest of each.
4. Sign `localhost:5000/app:v1` by digest with `cosign.key`. Do not sign `app:unsigned`.
5. Verify `app:v1` with `cosign.pub` (success expected) and attempt to verify `app:unsigned` (failure expected).
6. Configure Kyverno so it can read the plain-HTTP lab registry.
7. Create namespace `signed`. Write `workspace/week-05/day-06/verify-images.yaml`: `ClusterPolicy` named `require-signed-images`, scoped to Pods in namespace `signed`, with a `verifyImages` rule requiring that every image matching `registry:5000/*` has a valid cosign signature by your public key (ignore the transparency log for the lab). Enforce it. Apply it.
8. In namespace `signed`: run pod `unsigned` with image `registry:5000/app:unsigned` and confirm rejection. Run pod `signed-ok` with image `registry:5000/app:v1` and confirm admission.
9. Show that Kyverno mutated the admitted pod's image to a digest reference.
10. Optional: make the nodes able to pull from `registry:5000` (containerd `hosts.toml` on `cks-control-plane` and `cks-worker`) so `signed-ok` reaches Running.

## Check your work
- `cosign verify` for `app:v1` prints a JSON payload containing the image digest; for `app:unsigned` it errors with "no signatures found" / "no matching signatures".
- `curl -s http://localhost:5000/v2/app/tags/list` lists the `sha256-....sig` tag (legacy format) alongside your tags.
- Step 8 unsigned pod: rejected by `validate.kyverno.svc-fail` with a message about failing to verify the image / no signatures.
- `signed-ok` pod is created (even if it is `ErrImagePull` without step 10) and `kubectl -n signed get pod signed-ok -o jsonpath='{.spec.containers[0].image}'` shows `registry:5000/app@sha256:...`.
- Signing a different digest does not make `app:unsigned` valid (verify by digest).

## Answer
[answers/week-05-supply-chain-security/day-06-cosign-sign-verify.md](../../answers/week-05-supply-chain-security/day-06-cosign-sign-verify.md) — Attempt the task first; only then open the answer.

## Cleanup
Remove the policy and namespace; stop the registry:
```
kubectl delete clusterpolicy require-signed-images
kubectl delete ns signed
docker rm -f registry
```
