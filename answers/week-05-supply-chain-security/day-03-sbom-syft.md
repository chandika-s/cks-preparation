# Week 5 · Day 3 (Oct 22) — Understand your supply chain: SBOM — Answers
Task: [day-03-sbom-syft.md](../../plan/week-05-supply-chain-security/day-03-sbom-syft.md)

## Solution
1. Table SBOMs:
```
mkdir -p workspace/week-05/day-03 && cd workspace/week-05/day-03
syft docker:hello-go:fat -o table > fat.txt
syft docker:hello-go:slim -o table > slim.txt
wc -l fat.txt slim.txt
```
(`syft hello-go:fat` also works when the local daemon has the image.)

2. CycloneDX:
```
syft docker:hello-go:fat -o cyclonedx-json > sbom.json
```
3. Inspect:
```
jq -r '.bomFormat, .specVersion' sbom.json
jq '.components | length' sbom.json
jq -r '.components[] | select(.type=="library") | "\(.name) \(.version)"' sbom.json | head
jq -r '.components[] | select(.name=="libc6") | .version' sbom.json
```
4. Cross-reference (example with `libc6`):
```
trivy image -q -f json hello-go:fat \
 | jq -r '.Results[].Vulnerabilities[]? | select(.PkgName=="libc6") | [.VulnerabilityID,.InstalledVersion,.FixedVersion]|@tsv'
```
Put the package, the SBOM version and the CVE IDs in `crossref.txt`; the `InstalledVersion` must equal the SBOM `version`.

5. Scan SBOM:
```
trivy sbom sbom.json
```
6. Model answer for `crossref.txt`:
```
Generate and store an SBOM per image at build time (syft/trivy), keyed by image digest, in an artifact store.
On a new CVE, query the stored SBOMs (jq / grep on purl "pkg:deb/.../X@<1.2.3") or feed them to trivy/grype sbom scanning to list images containing X at a vulnerable version.
Then rebuild/patch those images and redeploy; no need to pull and rescan every image.
```

## Expected output
```
NAME        VERSION            TYPE
base-files  12ubuntu4.x        deb
libc6       2.35-0ubuntu3.x    deb
...
```
`slim.txt` lists a handful of entries (distroless base packages and the Go binary/stdlib). `jq -r .bomFormat` prints `CycloneDX`.

## Why it works
Syft catalogs package databases and language manifests/binary metadata from image layers, and writes them in a standard schema. Trivy accepts CycloneDX/SPDX and matches each component's purl/version to its vulnerability DB, so the image is not needed again.

## Common mistakes / exam gotchas
- Forgetting the `docker:` scheme for a local-only image: Syft tries the registry and fails.
- `-o cyclonedx-json` prints to stdout; redirect or use `-o cyclonedx-json=file`.
- SBOM component versions can differ in epoch/revision formatting from advisories; match on package name plus the distro version string.
- An SBOM for a tag is stale once the tag moves; key SBOMs to digests.
- Static Go binaries only show module info if built with module data (not stripped of build info); `-ldflags="-s -w"` keeps buildinfo, but `scratch` images have no OS packages at all.

## Cleanup
None.
