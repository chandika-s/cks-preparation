# Week 5 · Day 5 (Oct 24) — Secure your supply chain: permitted registries
**Domain:** Supply Chain Security (20%) — Secure your supply chain (registries) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Install Kyverno on the kind cluster.
- Write a `ClusterPolicy` that only admits pods whose images come from an allowed registry.
- Verify a rejected and an accepted deployment, and read the violation message.

## Theory
Restrict which registries pods can pull images from using an admission controller / policy engine: OPA Gatekeeper, Kyverno, or the built-in `ImagePolicyWebhook`.

- **Kyverno** runs as a validating/mutating admission webhook. A `ClusterPolicy` has `spec.rules[]`, each with `match`/`exclude` (kinds, namespaces, selectors) and a `validate`, `mutate`, `generate` or `verifyImages` action. Validation uses a `pattern` (overlay-style, supports `*` wildcards and `|` alternatives) or `deny`/`cel`/`foreach`.
- Enforcement mode: `validate.failureAction: Enforce` (block) vs `Audit` (log in PolicyReports only). Older policies use `spec.validationFailureAction`, still accepted but deprecated. Newer Kyverno releases are moving toward `ValidatingPolicy` / `ImageValidatingPolicy` (`policies.kyverno.io`); `ClusterPolicy` still works and is what this lab uses.
- Kyverno does not expand short image names in matched resources: `nginx` is compared as `nginx`, not `docker.io/library/nginx`. Use fully qualified image names with a registry prefix in patterns and manifests.
- Patterns must cover `containers`, `initContainers` and `ephemeralContainers`. `=(field)` means "if present, then match".
- Useful commands: `kubectl get clusterpolicy`, `kubectl describe clusterpolicy <name>`, `kubectl get policyreport -A` / `kubectl get cpolr`, `kubectl -n kyverno logs deploy/kyverno-admission-controller`.
- Alternatives: **Gatekeeper** (`ConstraintTemplate` in Rego + `Constraint`, e.g. K8sAllowedRepos); **ImagePolicyWebhook** admission plugin: `--enable-admission-plugins=...,ImagePolicyWebhook` and `--admission-control-config-file=<file>` on the kube-apiserver, where the file (an `AdmissionConfiguration`) points to a kubeconfig for an external image review service with `allowTTL`, `denyTTL`, `retryBackoff`, `defaultAllow` (`false` = fail closed). Config files and certs must be mounted into the static-pod apiserver.
- Kubernetes-side hygiene: private registries with `imagePullSecrets`, never `latest`.

## Prerequisites
Cluster `kind-cks` up with Calico, internet access from nodes and host. Admission webhooks add latency; do not install Kyverno while other heavy labs are running.

## Task
1. Install Kyverno on the cluster from the official release install manifest (use `kubectl create`, not `apply`, because the CRDs are too large for client-side apply). Wait until all deployments in namespace `kyverno` are available.
2. Create namespace `registry-test`.
3. Write `workspace/week-05/day-05/allow-registries.yaml`: a `ClusterPolicy` named `restrict-image-registries` that:
   - applies only to Pods in namespace `registry-test`;
   - denies (Enforce) any pod where any container, init container or ephemeral container image does not start with `docker.io/library/`;
   - returns the message `Images must come from docker.io/library/`.
   Apply it and confirm it is Ready.
4. In `registry-test`, try to create pod `bad` with image `quay.io/nginx/nginx-unprivileged:latest`. Capture the rejection message.
5. In `registry-test`, create pod `good` with image `docker.io/library/nginx:1.27` and confirm it runs.
6. In `registry-test`, try pod `bad-init` that has a permitted main container (`docker.io/library/nginx:1.27`) but an init container using `quay.io/prometheus/busybox:latest` and confirm it is rejected.
7. Switch the policy to `Audit`, re-create `bad`, and confirm it is admitted and that a policy report entry records the failure. Switch back to `Enforce`.

## Check your work
- `kubectl -n kyverno get pods` shows all Kyverno pods Running/Ready; `kubectl get clusterpolicy restrict-image-registries` shows READY `True`.
- Step 4 fails at admission with an error from webhook `validate.kyverno.svc-fail` that includes the policy name, rule name and your message.
- Pod `good` reaches `Running`.
- Step 6 is rejected (initContainers are covered).
- In Audit mode `bad` is created and `kubectl get policyreport -n registry-test` (or `kubectl get polr`) lists a `fail` result for the policy.

## Answer
[answers/week-05-supply-chain-security/day-05-kyverno-allowed-registries.md](../../answers/week-05-supply-chain-security/day-05-kyverno-allowed-registries.md) — Attempt the task first; only then open the answer.

## Cleanup
Keep Kyverno installed for Day 6. Remove the lab objects:
```
kubectl delete clusterpolicy restrict-image-registries
kubectl delete ns registry-test
```
