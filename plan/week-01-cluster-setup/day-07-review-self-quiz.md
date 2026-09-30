# Week 1 · Day 7 (Sep 29) — Review & self-quiz
**Domain:** Cluster Setup (15%) — review of all Week 1 items | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Reproduce each Week 1 lab from memory, without notes, in 10 minutes or less.
- Identify weak spots and redo the corresponding day's lab before Week 2.

## Theory
Review, no new material. Key facts to have ready:
- NetworkPolicy: `podSelector: {}` + `policyTypes` + no rules = deny; empty rule (`- {}`) = allow all; rules are additive; namespaceSelector + podSelector in one element = AND; DNS must be explicitly allowed once egress is restricted.
- kube-bench: CIS Kubernetes Benchmark checker; sections master, etcd, control plane config, worker, policies; remediation = edit static pod manifest, kubelet config or file permissions.
- Ingress TLS: `kubernetes.io/tls` Secret in the Ingress namespace, `spec.tls[].hosts/secretName`, `ingressClassName`.
- Metadata: egress `ipBlock` with `except` for `169.254.169.254/32`; kubelet `anonymous.enabled=false`, `authorization.mode=Webhook`, `readOnlyPort=0`.
- Binaries: verify SHA-256, pin images by digest.
- Time budget: the exam has ~2 hours for ~15-20 tasks; you must average about 6-7 minutes per task.

## Prerequisites
Ingress-nginx installed (Day 4). Use fresh namespaces `quiz1` to `quiz5` so earlier state does not help or interfere. Timer (phone/stopwatch). No notes, but `kubectl explain` and the Kubernetes docs (kubernetes.io/docs) are allowed, as on the exam.

## Exam-style question
Context: cluster `kind-cks` with ingress-nginx installed, and fresh namespaces `quiz1`, `quiz2`, `quiz4` and `quiz5`. Task: without notes (only `kubectl explain` and kubernetes.io/docs), complete these Week 1 items at exam pace, at most 10 minutes each. In `quiz1`, apply default-deny policy `default-deny-all`. In `quiz2`, allow only `client` to reach `web` on TCP/80 with DNS working. In `quiz4`, publish Deployment `app` over TLS at `quiz.example.com` with Secret `quiz-tls` and Ingress `app-tls`. In `quiz5`, apply `block-imds`, which blocks egress to `169.254.169.254/32` only. Requirements: prove each allowed and denied flow, and state how you would remediate kube-bench finding 1.2.1 and which two kubelet settings protect port 10250.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Time each item; limit 10 minutes. Record the time and whether you used notes.
1. In new namespace `quiz1`, with pods `a` and `b` (nginx) running, write and apply a NetworkPolicy `default-deny-all` denying all ingress and egress for every pod. Prove it with a failed request.
2. In `quiz2`, with pods `web` (nginx, label `app=web`) and `client` (busybox sleep, label `app=client`), and Service `web`, apply a default-deny baseline and then policies so that only `client` can reach `web` on TCP/80 and both can resolve DNS via CoreDNS. Prove allowed and denied flows.
3. Explain out loud (about 60 seconds): what kube-bench checks, how the results are structured, and exactly how you would remediate a finding `[FAIL] 1.2.1 Ensure that the --anonymous-auth argument is set to false`, including the file, the edit, how the component restarts, and one risk. Write down your answer in 5 bullets, then compare with the model answer.
4. In `quiz4`, create a Deployment `app` (2 replicas nginx) with Service `app`, generate a self-signed certificate for `quiz.example.com`, create the TLS Secret `quiz-tls`, and create an Ingress `app-tls` (class `nginx`) terminating TLS for that host. Verify with `curl -k --resolve`.
5. In `quiz5`, write a NetworkPolicy `block-imds` that selects all pods and blocks egress to `169.254.169.254/32` while allowing all other egress. State the two kubelet settings that protect port 10250.
6. Reflection: list any item that took more than 10 minutes or needed notes.

## Check your work
- Item 1: request from `a` to `b` times out; `kubectl describe netpol` shows both policy types with no rules.
- Item 2: `client` gets the nginx page from `web:80`, other pods and other ports are refused/time out, `nslookup` works.
- Item 3: your 5 bullets cover: benchmark for control-plane/etcd/kubelet/worker/policies, PASS/FAIL/WARN, run as a Job on the node with host mounts, fix by editing `/etc/kubernetes/manifests/kube-apiserver.yaml` to add `--anonymous-auth=false` and let the kubelet restart the static pod, then re-run; risk is health probes / anonymous-dependent clients.
- Item 4: HTTPS returns the page and the served cert subject is `CN=quiz.example.com`.
- Item 5: policy has `0.0.0.0/0` with `except: [169.254.169.254/32]`.
- If any item took over 10 minutes or needed notes, redo that day's lab before starting Week 2.

## Answer
[answers/week-01-cluster-setup/day-07-review-self-quiz.md](../../answers/week-01-cluster-setup/day-07-review-self-quiz.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns quiz1 quiz2 quiz4 quiz5`. Remove any temporary files in `~/`.
