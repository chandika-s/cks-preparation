# Week 6 · Day 8 (Nov 4) — Review & self-quiz
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Reproduce this week's tasks from memory under time limits.
- Identify weak spots for another pass.

## Theory
Quick recall:
- Falco: `helm install falco falcosecurity/falco -n falco --create-namespace --set driver.kind=modern_ebpf --set tty=true`; custom rules in `/etc/falco/rules.d` (`customRules` value); rule = `rule/desc/condition/output/priority`; `falco -V` validates; logs from the `falco` container.
- Incident order: contain, evidence, remove privilege, replace workload.
- Immutability: `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, scoped `emptyDir`.
- Audit: policy file + `--audit-policy-file` + `--audit-log-path` + hostPath volumes/mounts; first matching rule wins; levels None/Metadata/Request/RequestResponse.
- jq: `select(...)`; check `impersonatedUser`; `responseStatus.code`.

## Prerequisites
Days 1–7 completed. Falco installed; audit logging enabled (Day 6). Start each item from a clean namespace.

## Exam-style question
Context: a timed mixed review (about 75 minutes, no notes) across Falco, incident response, runtime immutability, audit policy and audit log analysis, using namespaces `quiz1`, `quiz2`, `quiz3` and the Day 7 file `workspace/week-06/audit.log`. Task: (1) alert at `CRITICAL` when `curl` or `wget` runs in pod `app` in `quiz1`; (2) contain compromised Deployment `api` in `quiz2`, collect evidence, remove its excess RBAC and replace the pod; (3) harden Deployment `svc` in `quiz3` to be immutable with only `/tmp` writable; (4) replace the audit policy with `/etc/kubernetes/audit/policy2.yaml` and prove a ConfigMap create is logged at `Request`; (5) write `jq` filters over the audit log. Requirements: keep earlier Falco rule files and do not break the apiserver.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Use a timer. No notes on the first attempt.
1. (15 min) A namespace `quiz1` has a pod `app` (image `nginx`). Write a custom Falco rule from scratch that alerts at `CRITICAL` whenever a process named `curl` or `wget` runs inside a container in `quiz1`, output including pod, user and command line. Deliver it via the Helm release, keeping earlier rule files, and trigger it.
2. (20 min) Namespace `quiz2` has Deployment `api` (label `app=api`, ServiceAccount `api-sa`) and a RoleBinding granting `api-sa` the ClusterRole `edit` in `quiz2`. A pod of `api` is compromised. Isolate it, collect its logs/describe to a file, remove the RBAC binding, and replace the pod.
3. (10 min) In namespace `quiz3`, Deployment `svc` (image `nginxinc/nginx-unprivileged:1.27-alpine`, port 8080) has no hardening. Make it immutable (read-only root FS, no priv-esc, all caps dropped, writable `/tmp` only) and prove writes fail outside `/tmp`.
4. (20 min) Write a new audit policy at `/etc/kubernetes/audit/policy2.yaml` that logs `configmaps` at `Request`, `pods/exec` at `Metadata`, ignores `get`/`list`/`watch` from `system:kube-proxy` (level `None`), and everything else at `Metadata`. Wire it into the apiserver in place of the Day 6 policy and verify a ConfigMap `create` is logged at `Request`.
5. (10 min) Given `workspace/week-06/audit.log` from Day 7, write `jq` filters for: (a) pod `exec` events, (b) anything a user in group `system:unauthenticated` did, (c) events where a ClusterRoleBinding was created or updated, (d) counts of events per verb.

## Check your work
- Item 1: Falco log shows the `CRITICAL` line for the pod in `quiz1` when `wget` runs.
- Item 2: `kubectl auth can-i create pods -n quiz2 --as=system:serviceaccount:quiz2:api-sa` is `no`; new pod running; NetworkPolicy present; evidence file exists.
- Item 3: `touch /newfile` fails, `touch /tmp/x` works, `CapEff` all zeros.
- Item 4: `kubectl get --raw /healthz` returns `ok`; audit log has a `create` event on `configmaps` with `"level":"Request"` and `requestObject`.
- Item 5: each filter returns expected output without jq errors.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-08-review-self-quiz.md](../../answers/week-06-monitoring-logging-runtime-security/day-08-review-self-quiz.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns quiz1 quiz2 quiz3`. Optionally restore the Day 6 backup manifest to disable audit logging. Falco may remain.
