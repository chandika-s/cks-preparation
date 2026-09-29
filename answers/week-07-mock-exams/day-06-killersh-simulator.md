# Week 7 · Day 6 (Nov 10) — killer.sh simulator attempt #1 — Answers
Task: [plan/week-07-mock-exams/day-06-killersh-simulator.md](../../plan/week-07-mock-exams/day-06-killersh-simulator.md)

This day has no fixed solutions: killer.sh supplies its own solutions after the session. This file is the review checklist and the mapping from typical simulator topic areas back to this plan. Topic areas are the common ones reported for CKS-style questions; the actual question set can differ, so map anything unlisted by curriculum domain.

## Solution

### Post-session review procedure
1. For each question: read the official solution, redo the key commands in kind-cks where possible (the concept usually transfers even if the environment differs).
2. Classify the gap: (a) did not know the concept, (b) knew it but forgot a flag/field, (c) knew it but too slow, (d) careless (context, namespace, typo, wrong output path).
3. Map to the plan below; open the corresponding week/day task and re-attempt cold on Day 7.
4. Update the miss log; for class (c) and (d) also write the exact command sequence or checklist line you should have followed.

### Mapping table: typical killer.sh topics to this plan

| Topic area (typical killer.sh question) | CKS domain | Plan day(s) to revisit | Fast check that you have it |
|---|---|---|---|
| Default-deny and scoped NetworkPolicy (ingress/egress, namespace selectors, DNS) | Cluster Setup | Week 1 Day 1, Day 2; Week 7 Day 1 | Pod-to-pod matrix works; DNS still resolves |
| kube-bench findings on API server / kubelet / etcd / manifests permissions | Cluster Setup | Week 1 Day 3; Week 7 Day 2 | Fix a flag in a static pod manifest and a kubelet config, re-run |
| Ingress with TLS secret | Cluster Setup | Week 1 Day 4; Week 7 Day 4 | `curl --resolve` returns 200 and correct cert |
| Metadata endpoint blocked with NetworkPolicy | Cluster Setup | Week 1 Day 5; Week 7 Day 5 | `ipBlock` with `except` |
| Verify platform binary checksums | Cluster Setup | Week 1 Day 6; Week 7 Day 5 | `sha512sum`/`sha256sum --check` |
| RBAC Role/RoleBinding/ClusterRole, least privilege, can-i | Cluster Hardening | Week 2 Day 1, Day 2, Day 6; Week 7 Day 1 | `auth can-i` matrix |
| ServiceAccount hygiene: automount, projected tokens, default SA | Cluster Hardening | Week 2 Day 3; Week 7 Day 1 | No default token mount |
| Restrict API access (anonymous, NodeRestriction, authorization modes, exposed ports) | Cluster Hardening | Week 2 Day 4; Week 7 Day 4 | Read API server flags from manifest |
| kubeadm cluster upgrade, node drain/uncordon | Cluster Hardening | Week 2 Day 5; Week 7 Day 5 | Recite order without notes |
| Host OS footprint: unneeded packages/services, listening ports | System Hardening | Week 3 Day 1 | `ss -tulpn`, `systemctl` disable/stop |
| Least-privilege IAM / access, SSH hardening | System Hardening | Week 3 Day 2 | - |
| Limit external network access on the node | System Hardening | Week 3 Day 3 | - |
| seccomp profile (Localhost/RuntimeDefault) | System Hardening | Week 3 Day 4; Week 7 Day 4 | Pod with `localhostProfile` runs; blocked call fails |
| AppArmor profile (may be simulated in kind as conceptual) | System Hardening | Week 3 Day 5; Week 7 Day 4 | `appArmorProfile` snippet and node-side commands |
| Pod Security Admission labels, fix pod spec for `restricted` | Microservice Vulnerabilities | Week 4 Day 1, Day 2; Week 7 Day 2 | `dry-run=server` clean |
| Encryption at rest for Secrets; verify in etcd | Microservice Vulnerabilities | Week 4 Day 3; Week 7 Day 1 | etcdctl output shows `k8s:enc:aescbc` |
| Secrets hygiene: mount vs env, RBAC on secrets, rotate | Microservice Vulnerabilities | Week 4 Day 4 | - |
| ResourceQuota / LimitRange multi-tenancy | Microservice Vulnerabilities | Week 4 Day 5; Week 7 Day 5 | Quota `Used` matches prediction |
| RuntimeClass with gVisor/Kata | Microservice Vulnerabilities | Week 4 Day 6 | `runtimeClassName` pod schedules (or explain kind limit) |
| Pod-to-pod encryption (Cilium/Istio mTLS), conceptual | Microservice Vulnerabilities | Week 4 Day 7 | - |
| Minimise base image, Dockerfile hardening | Supply Chain | Week 5 Day 1; Week 7 Day 2 | USER numeric, pinned slim base |
| Trivy image scan and fix, delete vulnerable workloads | Supply Chain | Week 5 Day 2; Week 7 Day 2 | `--severity` + JSON/table parsing |
| SBOM generation and query | Supply Chain | Week 5 Day 3 | `trivy image --format spdx-json` / `bom` |
| CI/CD and artifact repository security (conceptual) | Supply Chain | Week 5 Day 4 | - |
| Permitted registries via admission policy (Kyverno/Gatekeeper/ImagePolicyWebhook) | Supply Chain | Week 5 Day 5; Week 7 Day 4 | Denied and admitted pod both shown |
| Image signing and verification (cosign, `verifyImages`) | Supply Chain | Week 5 Day 6; Week 7 Day 5 | Digest-pinned verify passes/fails correctly |
| Static analysis of manifests (kubesec, KubeLinter) | Supply Chain | Week 5 Day 7 | Score/violations addressed |
| Falco default and custom rules, read Falco output | Monitoring & Runtime | Week 6 Day 1, Day 2; Week 7 Day 3 | Rule loads, alert appears |
| Threat detection across layers, attack phases, incident response | Monitoring & Runtime | Week 6 Day 3, Day 4; Week 7 Day 3 | Isolate, preserve, remove |
| Container immutability, hardened securityContext, remove privileged | Monitoring & Runtime | Week 6 Day 5; Week 7 Day 3 | Writes to `/` fail; `/tmp` works |
| Enable audit logging (policy + flags + mounts) | Monitoring & Runtime | Week 6 Day 6; Week 7 Day 3 | Event for a secret get is in the log |
| Analyse audit logs with jq / grep | Monitoring & Runtime | Week 6 Day 7; Week 7 Day 3 | Answer "who/what/when" in under 3 min |
| Static pod / control plane component edits without breaking the cluster | All | Week 1 Day 3; Week 2 Day 4; Week 4 Day 3; Week 6 Day 6 | Backup outside manifests dir; check `crictl ps` |

### Scoring reference
| Score | Interpretation | Action for Day 7 and Week 8 |
|---|---|---|
| Above 75% | Ready pending speed | Drill only slow items |
| 55-75% | Normal for first attempt | Redo all Miss/Partial items; use session #2 in Week 8 |
| Below 55% | Gaps in fundamentals | Re-read the theory in the mapped week/day before drilling |

## Expected output
A completed tracker, a miss log where every row has a plan reference, and a percentage score.

## Why it works
Mapping each miss to the exact plan day turns a vague "I did badly on security" into specific rebuild tasks, and classifying the cause (knowledge, recall, speed, carelessness) selects the right remedy: read, flash-card, timed repetition, or a pre-flight checklist.

## Common mistakes / exam gotchas
- Activating the 36-hour window before you have 2 clear hours.
- Pausing to search the docs for things you should already know; use the docs only for exact field names and long YAML.
- Not switching context/namespace at the start of each question (writing to the wrong cluster).
- Spending 20 minutes on one 4-point question.
- Reviewing only what you got wrong; also review what you got right but slowly.
- Editing a control plane manifest without a backup outside `/etc/kubernetes/manifests`.
- Ignoring the required output file path or name.

## Cleanup
None. Keep session #2 unused for Week 8.
