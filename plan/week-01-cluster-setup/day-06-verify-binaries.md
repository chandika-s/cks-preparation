# Week 1 · Day 6 (Sep 28) — Verify platform binaries before deploying
**Domain:** Cluster Setup (15%) — verify platform binaries | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Download an official Kubernetes binary and verify it against the published SHA-256.
- Detect a tampered binary via checksum mismatch.
- Understand digest-pinned images and signature verification with cosign.

## Theory
- Before installing kubelet, kubectl, kubeadm (or any tool), verify integrity against the publisher's hash or signature. Kubernetes publishes `<binary>.sha256` next to each binary at `https://dl.k8s.io/release/<version>/bin/<os>/<arch>/`. The `.sha256` file contains only the hash, no file name.
- Verifying: `echo "<hash>  <file>" | sha256sum --check` (Linux) or `shasum -a 256 -c` (macOS). Output `OK` / `FAILED` and non-zero exit on mismatch. Note two spaces between hash and file name.
- Any single-byte change alters the SHA-256 completely. A checksum fetched from the same untrusted channel proves little; the hash must come from a trusted source (or be signed).
- Container images: tags are mutable, digests (`repo@sha256:...`) are content addresses. Deploy by digest to guarantee the exact bytes. Get a digest with `docker inspect --format '{{index .RepoDigests 0}}' <img>` or `docker buildx imagetools inspect <img>`.
- Signatures: Kubernetes release artifacts and images are signed with Sigstore cosign (keyless). `cosign verify <image> --certificate-identity ... --certificate-oidc-issuer ...` checks the signature and identity.
- Related commands: `sha256sum`, `sha512sum`, `shasum -a 256`, `md5sum` (weak, avoid), `cmp`, `printf`/`dd` for byte manipulation.
- Exam pattern: given a binary or a set of binaries and published hashes, identify which does not match and remove/replace it.

## Prerequisites
`curl` and a checksum tool (`sha256sum` on Linux, `shasum` on macOS). Optional for the bonus: `docker`, `cosign`. Work in `~/verify-lab/`.

## Exam-style question
Context: working directory `~/verify-lab/` contains a `kubectl` binary for `v1.35.0` downloaded from `dl.k8s.io` and a modified copy named `kubectl.tampered`. Task: using the published SHA-256 for that release, determine which files are genuine and which have been altered. Requirements: show a per-file `OK` or `TAMPERED` result for every file named `kubectl*`, and do not leave the tampered binary on your PATH.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create `~/verify-lab/`. Download the `kubectl` binary for `v1.35.0` for your OS/architecture from `https://dl.k8s.io/release/v1.35.0/bin/<os>/<arch>/kubectl` and its `kubectl.sha256` file.
2. Verify the binary against the published hash using a `--check`-style comparison. It must print `OK`.
3. Copy the binary to `kubectl.tampered`. Overwrite exactly one byte in the copy (at offset 100) without changing the file length. Verify the copy against the same hash; it must fail. Show the two differing SHA-256 values.
4. Write a short shell loop that verifies every file in `~/verify-lab/` named `kubectl*` against the published hash and prints `OK` or `TAMPERED` per file.
5. Bonus: pull `registry.k8s.io/pause:3.10`, find its digest, and run a container from the digest form of the reference. If `cosign` is installed, verify the signature of a Kubernetes-signed image (for example `registry.k8s.io/kube-apiserver:v1.35.0`) using the Kubernetes release identity.

## Check your work
- `kubectl: OK` for the original download; `kubectl.tampered: FAILED` plus `WARNING: 1 computed checksum did NOT match` for the copy.
- `cmp kubectl kubectl.tampered` reports exactly one differing byte.
- The loop prints `OK` for `kubectl` and `TAMPERED` for `kubectl.tampered`.
- Bonus: `docker run` by digest works and `docker inspect` shows the same digest; cosign prints verification checks passed (or you can state why it wasn't run).

## Answer
[answers/week-01-cluster-setup/day-06-verify-binaries.md](../../answers/week-01-cluster-setup/day-06-verify-binaries.md) — Attempt the task first; only then open the answer.

## Cleanup
Remove `~/verify-lab/` when done (the tampered binary should not be left on your PATH).
