# Week 5 · Day 2 (Oct 21) — Image scanning with Trivy
**Domain:** Supply Chain Security (20%) — Secure your supply chain / static analysis of images | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Scan images with Trivy and read the report (package, installed vs fixed version, severity).
- Filter by severity and fixability, and use exit codes as a CI/CD gate.
- Explain remediation of a specific CVE and confirm it with a re-scan.

## Theory
Scan images for known CVEs before deployment; fail CI/CD (or admission) if HIGH/CRITICAL vulnerabilities exceed policy.

- Trivy matches OS packages (dpkg/apk/rpm) and language dependencies (Go modules, npm, pip, jars, ...) against a vulnerability DB (downloaded on first run, cached under `~/.cache/trivy`).
- Report columns: Library, Vulnerability ID (CVE), Severity, Status, Installed Version, Fixed Version, Title.
- Key flags:
  - `--severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` (comma list)
  - `--ignore-unfixed`: hide CVEs with no fix available
  - `--exit-code 1`: non-zero exit if any finding matches (default 0) — the CI gate
  - `--scanners vuln,secret,misconfig`
  - `-f json|table|cyclonedx|sarif`, `-o file`
  - `-q` quiet
  - `--input image.tar` (scan a `docker save` tarball)
- Other modes: `trivy fs <dir>`, `trivy config <dir>` (IaC/manifest misconfig), `trivy k8s`, `trivy sbom <file>`.
- Remediation options: bump the base image tag (or switch to a slim/distroless variant), `apt-get upgrade`/`apk upgrade` specific packages in the Dockerfile, bump the app dependency, or accept/ignore with a documented `.trivyignore` entry when no fix exists.
- Old tags (e.g. `nginx:1.18`) sit on end-of-life OS bases, so many findings have no fix in that base and the fix is a newer image.

## Prerequisites
Trivy installed on the host and internet access for the DB. Optional: `hello-go:fat` / `hello-go:slim` from Day 1.

## Exam-style question
Context: namespace `scan-lab` does not exist yet and Trivy is installed on the host. Task: create pods `old` (`nginx:1.18`), `new` (`nginx:stable-alpine`) and `bb` (`busybox:1.36`) in `scan-lab`, each with a single container, then delete every pod whose image has at least one CRITICAL vulnerability. Requirements: leave the pods whose images have no CRITICAL findings running, and write the names of the deleted pods, one per line, to `workspace/week-05/day-02/deleted.txt`.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Run `trivy image --severity HIGH,CRITICAL nginx:1.18` and identify the OS/base reported at the top and the count of HIGH and CRITICAL findings.
2. Choose one CRITICAL or HIGH CVE from that report that has a fixed version. In `workspace/week-05/day-02/findings.txt` record: CVE ID, affected package, installed version, fixed version, and a written remediation (which image change or package upgrade resolves it and why).
3. Re-scan a newer or minimal variant of the same image (for example `nginx:stable-alpine` or a current `nginx` tag). Record the HIGH/CRITICAL count and confirm your chosen CVE is absent.
4. Re-run the step-1 scan with `--ignore-unfixed` and note the difference in count.
5. Gate check: run a scan of `nginx:1.18` that exits non-zero when any CRITICAL vulnerability exists, and show the exit code (`echo $?`). Show that the same gate against your remediated image behaves as expected.
6. Exam-style task: create namespace `scan-lab` with three pods, each a single container: `old` (`nginx:1.18`), `new` (`nginx:stable-alpine`), `bb` (`busybox:1.36`). Using Trivy, determine which of these images have at least one CRITICAL vulnerability and delete only those pods. Write the names of the deleted pods to `workspace/week-05/day-02/deleted.txt`.

## Check your work
- Step 1 output is a table grouped by target (OS packages) with Severity limited to HIGH/CRITICAL.
- `findings.txt` contains a CVE whose Fixed Version column was non-empty in the report.
- The re-scanned image has significantly fewer findings and does not list your CVE.
- `--ignore-unfixed` yields a count less than or equal to the full count.
- The gate command's `echo $?` prints `1` for a vulnerable image and `0` for a clean one.
- `kubectl get pods -n scan-lab` shows only pods whose images had no CRITICAL findings; `deleted.txt` lists the others.

## Answer
[answers/week-05-supply-chain-security/day-02-trivy-image-scanning.md](../../answers/week-05-supply-chain-security/day-02-trivy-image-scanning.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns scan-lab
```
