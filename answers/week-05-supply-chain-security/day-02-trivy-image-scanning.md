# Week 5 · Day 2 (Oct 21) — Image scanning with Trivy — Answers
Task: [day-02-trivy-image-scanning.md](../../plan/week-05-supply-chain-security/day-02-trivy-image-scanning.md)

## Solution
Actual CVE IDs and counts change daily with the DB; use the method, not fixed numbers.

1. Scan:
```
mkdir -p workspace/week-05/day-02 && cd workspace/week-05/day-02
trivy image --severity HIGH,CRITICAL nginx:1.18
```
The header line shows the detected OS (a Debian release, EOL) and the `Total: N (HIGH: x, CRITICAL: y)` line.

2. Pick a row with a non-empty "Fixed Version", or extract them:
```
trivy image -q --severity CRITICAL -f json nginx:1.18 \
 | jq -r '.Results[].Vulnerabilities[]? | select(.FixedVersion!=null) | [.VulnerabilityID,.PkgName,.InstalledVersion,.FixedVersion]|@tsv' | head
```
Example `findings.txt` entry (format):
```
CVE: CVE-XXXX-YYYY
Package: <pkg>  installed: <ver>  fixed: <ver>
Remediation: base image Debian <old> is EOL; move to a maintained tag (nginx:<current>-alpine) which ships <pkg> >= <fixed>. If pinned to the old base, apt-get install --only-upgrade <pkg> in the Dockerfile.
```
3. Re-scan:
```
trivy image --severity HIGH,CRITICAL nginx:stable-alpine
trivy image -q -f json nginx:stable-alpine | jq -r '.Results[].Vulnerabilities[]?.VulnerabilityID' | grep CVE-XXXX-YYYY || echo absent
```
4. Unfixed filter:
```
trivy image --severity HIGH,CRITICAL --ignore-unfixed nginx:1.18
```
5. Gate:
```
trivy image --severity CRITICAL --exit-code 1 -q nginx:1.18; echo $?
trivy image --severity CRITICAL --exit-code 1 -q nginx:stable-alpine; echo $?
```
6. Scan-lab:
```
kubectl create ns scan-lab
kubectl -n scan-lab run old --image=nginx:1.18
kubectl -n scan-lab run new --image=nginx:stable-alpine
kubectl -n scan-lab run bb --image=busybox:1.36 --command -- sleep 3600
for p in $(kubectl -n scan-lab get pods -o name); do
  img=$(kubectl -n scan-lab get $p -o jsonpath='{.spec.containers[0].image}')
  trivy image -q --severity CRITICAL --exit-code 1 "$img" >/dev/null && echo "$p ok" || { echo "$p CRITICAL"; kubectl -n scan-lab delete $p; }
done
```
Record deleted pod names in `deleted.txt`.

## Expected output
Table shape:
```
nginx:1.18 (debian 10.x)
Total: 1xx (HIGH: 1xx, CRITICAL: xx)
┌─────────┬────────────────┬──────────┬────────┬───────────────────┬───────────────┬───────┐
│ Library │ Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │ Title │
```
Gate prints `1` for the old image; the alpine image typically prints `0` (verify, as it depends on the day's DB).

## Why it works
Trivy fingerprints the OS release and package DB inside the image layers and matches versions to advisories; `--exit-code` turns findings into a process failure that pipelines can act on. A newer or minimal image carries patched or absent packages.

## Common mistakes / exam gotchas
- `--exit-code` defaults to 0: a scan step never fails the pipeline without it.
- `--severity` is not "at least": listing only `CRITICAL` hides HIGH.
- `--ignore-unfixed` reduces noise but hides risk that has no patch yet.
- Scan the exact tag/digest deployed; mutable tags drift.
- First run needs to download the DB (can be slow/offline-blocked); `--skip-db-update` only works with a warm cache.
- On the exam Trivy usually runs on a given node/workstation; read the image list from pods with `kubectl get pods -o jsonpath` or `-o custom-columns`.

## Cleanup
```
kubectl delete ns scan-lab
```
