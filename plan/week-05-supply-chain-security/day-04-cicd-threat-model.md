# Week 5 · Day 4 (Oct 23) — CI/CD and artifact repository security (conceptual)
**Domain:** Supply Chain Security (20%) — Understand your supply chain (CI/CD, artifact repositories) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Name the four stages of a software supply chain and what can go wrong at each.
- Produce a concrete threat model: one attack and one mitigation per stage.
- Connect mitigations to Kubernetes-side controls (digest pinning, admission verification, registry restrictions).

## Theory
Supply chain security spans: **source** (signed commits, protected branches) → **build** (isolated, reproducible CI runners) → **artifact storage** (private registries, provenance/attestation) → **deploy** (admission-time verification). Know the stages and what can go wrong at each, for example a compromised CI runner pushing a tampered image with a legitimate-looking tag.

- **Source:** attacks: stolen developer credentials, force-push/unreviewed merge, malicious dependency (typosquatting, dependency confusion). Controls: branch protection, required reviews, signed commits, MFA, dependency pinning/lockfiles, dependency scanning.
- **Build:** attacks: compromised runner or poisoned build cache, secrets leaked in logs, mutable base image (`FROM x:latest`). Controls: ephemeral isolated runners, least-privilege CI credentials, pinned base images by digest, reproducible builds, image scanning and SBOM generation in the pipeline, provenance (SLSA).
- **Artifact storage:** attacks: overwriting a mutable tag, registry credential theft, pushing to a public/rogue registry, pulling from an untrusted mirror. Controls: private registry with RBAC, immutable tags, sign images (cosign) and store attestations, vulnerability scanning on push, short-lived credentials.
- **Deploy:** attacks: cluster pulls an image not built by CI, tag re-pointed after review, unscanned image admitted. Controls: admission policy restricting registries, signature verification (Kyverno `verifyImages`, `ImagePolicyWebhook`), reference by digest (`image@sha256:...`), PSA/securityContext, `imagePullSecrets` scoped per namespace.
- Key terms: provenance (who/what/how built), attestation (signed statement about an artifact), SLSA levels, digest vs tag (tag is mutable; digest is content-addressed), immutable tags.
- Kubernetes objects to know: `imagePullSecrets` on pod/ServiceAccount, `kubectl create secret docker-registry`, `imagePullPolicy`, `status.containerStatuses[].imageID` (the resolved digest).

## Prerequisites
None (cluster access needed only for the optional digest exercise in step 4).

## Exam-style question
Context: a pipeline flows `GitHub repo -> shared CI runner -> Docker Hub/private registry -> Kubernetes cluster`, and a compromised runner is able to push a tampered image under the existing tag `myapp:1.4.2`. Task: document the pipeline's risks in `workspace/week-05/day-04/threat-model.md` with one attack and one mitigation per stage, and name two independent cluster-side controls that would block the tampered image. Requirements: for the cluster exercise, pod `dg` (`docker.io/library/nginx:1.27`) in `default` must be re-deployed as pod `dg-pinned` using `dg-pinned.yaml` that references the image by digest rather than tag.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create `workspace/week-05/day-04/threat-model.md`: a one-page bulleted threat model for a hypothetical pipeline `GitHub repo -> shared CI runner -> Docker Hub/private registry -> Kubernetes cluster`. For each of the four stages (source, build, artifact storage, deploy) list exactly one concrete attack and one concrete mitigation.
2. For the scenario "a compromised CI runner pushes a tampered image under the tag `myapp:1.4.2`", state (a) what an unprotected cluster does, and (b) two independent controls that would stop it at the cluster.
3. For each mitigation in your model, mark whether it is enforced (a) outside the cluster or (b) inside the cluster by an admission control, and name the tool.
4. Optional cluster exercise: in namespace `default`, run a pod `dg` from `docker.io/library/nginx:1.27`. Retrieve the resolved image digest from the pod status, then write and apply a second manifest `dg-pinned.yaml` (pod `dg-pinned`) that references the same image by digest instead of tag, and confirm it runs.

## Check your work
- The threat model has four labelled stages, each with a named attack and a named mitigation (not generic phrases like "be careful").
- The answer to step 2 names one control that verifies image identity (signature/digest) and one that restricts source (registry allow-list).
- Step 4: `kubectl get pod dg -o jsonpath='{.status.containerStatuses[0].imageID}'` outputs a `sha256:` digest, and pod `dg-pinned` shows the `image:` with `@sha256:`.

## Answer
[answers/week-05-supply-chain-security/day-04-cicd-threat-model.md](../../answers/week-05-supply-chain-security/day-04-cicd-threat-model.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete pod dg dg-pinned --ignore-not-found
```
