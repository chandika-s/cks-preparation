# Week 1 · Day 6 (Sep 28) — Verify platform binaries before deploying — Answers
Task: [plan/week-01-cluster-setup/day-06-verify-binaries.md](../../plan/week-01-cluster-setup/day-06-verify-binaries.md)

## Solution
Set OS/arch (example for Apple Silicon; use `linux`/`amd64` on Linux x86):
```bash
OS=darwin ARCH=arm64 V=v1.35.0
mkdir -p ~/verify-lab && cd ~/verify-lab
curl -LO "https://dl.k8s.io/release/$V/bin/$OS/$ARCH/kubectl"
curl -LO "https://dl.k8s.io/release/$V/bin/$OS/$ARCH/kubectl.sha256"
```
2. Verify (macOS: `shasum -a 256 -c`; Linux: `sha256sum --check`):
```bash
echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 -c -
```
3. Tamper one byte:
```bash
cp kubectl kubectl.tampered
printf '\x00' | dd of=kubectl.tampered bs=1 seek=100 count=1 conv=notrunc
cmp -l kubectl kubectl.tampered
echo "$(cat kubectl.sha256)  kubectl.tampered" | shasum -a 256 -c -
shasum -a 256 kubectl kubectl.tampered
```
If the original byte at offset 100 was already `00`, `cmp` shows nothing; write `\xff` instead.

4. Loop:
```bash
for f in kubectl*; do
  case $f in *.sha256) continue;; esac
  echo "$(cat kubectl.sha256)  $f" | shasum -a 256 -c - >/dev/null 2>&1 && echo "$f OK" || echo "$f TAMPERED"
done
```
5. Bonus:
```bash
docker pull registry.k8s.io/pause:3.10
DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' registry.k8s.io/pause:3.10)
echo $DIGEST
docker run --rm --entrypoint /pause "$DIGEST" --help 2>&1 | head -2
cosign verify registry.k8s.io/kube-apiserver:v1.35.0 \
  --certificate-identity krel-trust@k8s-releng-prod.iam.gserviceaccount.com \
  --certificate-oidc-issuer https://accounts.google.com
```
The cosign identity/issuer are those documented by Kubernetes for release images; confirm against the Kubernetes "Verify signed container images" docs if verification is rejected. Running the pause image by digest merely proves the reference resolves; the pause binary may print usage or exit.

## Expected output
```
kubectl: OK
kubectl.tampered: FAILED
shasum: WARNING: 1 computed checksum did NOT match
  100   <orig octal> 0            # cmp -l
kubectl OK
kubectl.tampered TAMPERED
registry.k8s.io/pause@sha256:<64 hex>
```

## Why it works
SHA-256 is collision-resistant; changing one byte changes the digest unpredictably, so `--check` fails. Image digests are hashes of the manifest, so pulling by digest guarantees the content regardless of tag movement.

## Common mistakes / exam gotchas
- Single space instead of two between hash and file name: `sha256sum -c` complains about improperly formatted lines.
- Comparing against a hash downloaded over the same compromised channel; prefer a trusted source or signature.
- Downloading the wrong OS/arch and concluding "mismatch".
- `sha256sum` does not exist on stock macOS; use `shasum -a 256`.
- Hashes are case-insensitive hex, but truncated copy/paste breaks the comparison; use `--check`, not eyeballing.
- Pulling by tag (`nginx:latest`) offers no integrity guarantee; pin by digest in manifests (`image: repo@sha256:...`).
- Kubernetes also publishes `kubectl.sha512`? Only sha256 is guaranteed for `dl.k8s.io` binaries; use what the question gives.

## Cleanup
```bash
rm -rf ~/verify-lab
```
