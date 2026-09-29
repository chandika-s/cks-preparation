# Week 8 · Day 2 (Nov 13) — Targeted review
**Domain:** All domains (curriculum self-assessment) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Redo shaky tasks from the Nov 12 simulation and earlier weak spots.
- Read `cheatsheet.md` end to end once, out loud.
- For every curriculum bullet: state its meaning in one sentence and demonstrate it hands-on.

## Theory
- Curriculum (Kubernetes v1.35 CKS) weights: Cluster Setup 10%, Cluster Hardening 15%, System Hardening 15%, Minimize Microservice Vulnerabilities 20%, Supply Chain Security 20%, Monitoring, Logging and Runtime Security 20%.
- Reading aloud forces recall and exposes gaps silently skimming hides.
- A bullet is "done" only when both the sentence and a working command/manifest exist; prefer the fastest imperative form (`kubectl create ...`, `--dry-run=client -o yaml`).
- kind caveats: AppArmor is unavailable on Docker Desktop/macOS nodes, kubeadm upgrade is limited on kind nodes, Cilium pod-to-pod encryption needs a Cilium cluster (kind-cks uses Calico). Know these conceptually and note the exam environment differs.
- Verify the bullet list against the official curriculum linked from `00-exam-and-cka-renewal.md` sources (github.com/cncf/curriculum); if a bullet differs, follow the official text.

## Prerequisites
- Day 1 target list. Cluster `kind-cks` running (see `SETUP.md`). Weeks 1–7 material available under `plan/` and `answers/`.

## Task
1. Redo every item on your Day 1 target list, timed (max 10 min each). Any that still fail: re-read the answer, redo once more.
2. Read `../../cheatsheet.md` top to bottom out loud, once. Mark unclear sections.
3. Fill in the self-assessment table below in a scratch file (`workspace/week8-selfassessment.md`): columns "One-sentence meaning", "Command/manifest that proves it", "Status (green/amber/red)".
4. For each amber/red row, do the hands-on within 10 minutes, then re-grade.
5. Stop new labs when done; do not start new topics.

| # | Domain | Curriculum bullet |
|---|---|---|
| 1 | Cluster Setup | Use network security policies to restrict cluster-level access |
| 2 | Cluster Setup | Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kube-apiserver) |
| 3 | Cluster Setup | Properly set up Ingress with TLS |
| 4 | Cluster Setup | Protect node metadata and endpoints |
| 5 | Cluster Setup | Verify platform binaries before deploying |
| 6 | Cluster Hardening | Use RBAC to minimize exposure |
| 7 | Cluster Hardening | Exercise caution in using service accounts (disable defaults, minimize permissions on newly created ones) |
| 8 | Cluster Hardening | Restrict access to the Kubernetes API |
| 9 | Cluster Hardening | Upgrade Kubernetes to avoid vulnerabilities |
| 10 | System Hardening | Minimize host OS footprint (reduce attack surface) |
| 11 | System Hardening | Use least-privilege identity and access management |
| 12 | System Hardening | Minimize external access to the network |
| 13 | System Hardening | Use kernel hardening tools such as AppArmor and seccomp |
| 14 | Microservice Vulnerabilities | Implement Pod Security Standards |
| 15 | Microservice Vulnerabilities | Manage Kubernetes Secrets |
| 16 | Microservice Vulnerabilities | Understand and implement isolation techniques (multi-tenancy, sandboxed runtimes) |
| 17 | Microservice Vulnerabilities | Implement Pod-to-Pod encryption using Cilium |
| 18 | Supply Chain Security | Minimize base image footprint |
| 19 | Supply Chain Security | Understand your supply chain (SBOM, CI/CD, artifact repositories) |
| 20 | Supply Chain Security | Secure your supply chain (permitted registries, sign and validate images) |
| 21 | Supply Chain Security | Perform static analysis of user workloads and container images (Kubesec, KubeLinter) |
| 22 | Monitoring/Logging/Runtime | Perform behavioral analytics to detect malicious activity |
| 23 | Monitoring/Logging/Runtime | Detect threats within physical infrastructure, apps, networks, data, users and workloads |
| 24 | Monitoring/Logging/Runtime | Investigate and identify phases of attack and bad actors within the environment |
| 25 | Monitoring/Logging/Runtime | Ensure immutability of containers at runtime |
| 26 | Monitoring/Logging/Runtime | Use Kubernetes audit logs to monitor access |

## Check your work
- Every Day 1 target item passes on a timed re-run.
- All 26 rows have a sentence and a proving command/manifest; no red rows remain.
- You can recite the cheatsheet sections (context safety, RBAC, NetworkPolicy, PSA, securityContext, etc.) without reading.

## Answer
[answers/week-08-final-review/day-02-targeted-review.md](../../answers/week-08-final-review/day-02-targeted-review.md) — Attempt the task first; only then open the answer.
