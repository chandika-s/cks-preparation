# Week 5 · Day 3 (Oct 22) — Understand your supply chain: SBOM
**Domain:** Supply Chain Security (20%) — Understand your supply chain (SBOM) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Generate an SBOM for an image in table and CycloneDX JSON formats with Syft.
- Navigate the SBOM structure and query it with `jq`.
- Cross-reference an SBOM component with Trivy vulnerability findings.

## Theory
A Software Bill of Materials (SBOM) lists every component and dependency in an image (OS packages, language libraries, versions, licences, hashes, purl identifiers). It lets you know what you are actually running and answer "are we affected by CVE-X" quickly, without re-scanning every image.

- Formats: **CycloneDX** (OWASP; JSON/XML) and **SPDX** (Linux Foundation; JSON/tag-value). Syft also has its own `syft-json`.
- Syft: `syft <source> -o <format>`; sources include a registry image, `docker:<image>` (local daemon), `dir:<path>`, `oci-archive:<tar>`. Formats: `table` (default), `cyclonedx-json`, `spdx-json`, `syft-json`. Write to file with `-o cyclonedx-json=sbom.json` or shell redirect.
- CycloneDX JSON key fields: `bomFormat`, `specVersion`, `metadata.component` (the image), `components[]` each with `name`, `version`, `type` (`library`, `application`, `operating-system`), `purl`, `licenses`, `properties`.
- Trivy can consume an SBOM: `trivy sbom sbom.json` and produce one: `trivy image --format cyclonedx -o sbom.json <image>`. Grype is a similar SBOM/image scanner.
- SBOM value: inventory, licence audit, fast blast-radius lookup for new CVEs, and input to attestations (`cosign attest`).
- An SBOM lists components; it does not itself say they are vulnerable.

## Prerequisites
`syft` and `trivy` installed. Images `hello-go:fat` and `hello-go:slim` from Day 1 (or any image you built this week).

## Exam-style question
Context: local images `hello-go:fat` and `hello-go:slim` exist on the host, which has Syft, Trivy and `jq` installed. Task: generate a CycloneDX JSON SBOM for `hello-go:fat` at `workspace/week-05/day-03/sbom.json`, and use it to determine the version of one installed library package and whether Trivy reports any CVE for it. Requirements: write the package, version and any CVE IDs to `workspace/week-05/day-03/crossref.txt`, and the Trivy result must come from scanning the SBOM file, not the image.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Generate a table SBOM for `hello-go:fat` and for `hello-go:slim` from the local docker daemon. Count the packages in each.
2. Generate a CycloneDX JSON SBOM for `hello-go:fat` into `workspace/week-05/day-03/sbom.json`.
3. Using `jq`, from `sbom.json` report: the spec version, the number of components, the components of type `library`, and the version of one package of your choice (e.g. `openssl`/`libssl3` or `libc6`).
4. Pick one dependency from the SBOM. Find whether Trivy reports a vulnerability for it (use the Day 2 scan technique on `hello-go:fat` or the image you scanned on Day 2). Record the package, version, and any CVE IDs in `workspace/week-05/day-03/crossref.txt`.
5. Scan the SBOM itself with Trivy (without the image) and confirm you get the same package findings.
6. Answer in the same file: "A new CVE is announced for package X < 1.2.3. How do you find which of your images are affected using SBOMs?"

## Check your work
- The table output has NAME / VERSION / TYPE columns; `fat` has clearly more entries than `slim`.
- `jq '.bomFormat' sbom.json` prints `"CycloneDX"`.
- Component count from `jq` matches the number of rows (approximately) from the table.
- `crossref.txt` shows the same package and version appearing in both the SBOM and a Trivy result.
- `trivy sbom sbom.json` produces a vulnerability report without needing the image.

## Answer
[answers/week-05-supply-chain-security/day-03-sbom-syft.md](../../answers/week-05-supply-chain-security/day-03-sbom-syft.md) — Attempt the task first; only then open the answer.
