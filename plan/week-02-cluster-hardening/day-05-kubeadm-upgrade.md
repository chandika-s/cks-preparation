# Week 2 · Day 5 (Oct 4) — Upgrade Kubernetes with kubeadm
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Know the kubeadm upgrade sequence for control plane and worker nodes.
- Run the read-only and safe parts on the kind cluster; drain and uncordon a node.
- Understand the limits of upgrading kind nodes in place.

## Theory
- Upgrade rules: one minor version at a time (v1.34 -> v1.35, never skip). kubelet may be older than the apiserver (within the supported skew) but never newer; kubectl within one minor. Patch upgrades within a minor are allowed directly.
- Order: control plane first (`kubeadm upgrade apply`), then each additional control plane (`kubeadm upgrade node`), then workers (`kubeadm upgrade node`), one node at a time.
- Control plane node sequence: upgrade the `kubeadm` package -> `kubeadm upgrade plan` -> `kubeadm upgrade apply vX.Y.Z` -> drain node -> upgrade `kubelet` and `kubectl` packages -> `systemctl daemon-reload && systemctl restart kubelet` -> uncordon.
- Worker sequence: drain (from control plane) -> on the worker upgrade `kubeadm` -> `kubeadm upgrade node` -> upgrade `kubelet` (+`kubectl`) -> restart kubelet -> uncordon (from control plane).
- `kubectl drain <node> --ignore-daemonsets [--delete-emptydir-data]`: cordons and evicts pods; PodDisruptionBudgets can block it. `kubectl uncordon <node>`.
- Packages are held (`apt-mark hold kubeadm kubelet kubectl`) and come from the version-specific repo `pkgs.k8s.io/core:/stable:/vX.Y/deb/`. To upgrade a minor, change the repo file to the new minor first. `apt-cache madison kubeadm` lists versions.
- Security angle: staying on a supported patch release picks up CVE fixes; read the changelog of the target version.
- Kind caveat: kind nodes are containers built from `kindest/node` images with the k8s binaries and control-plane images preloaded and no Kubernetes apt repository configured. The supported way to change versions is to recreate the cluster with another node image. In-place `kubeadm upgrade apply` may fail (image pulls, no package repo, no target binaries). Treat package steps as conceptual; run what works (`plan`, `--dry-run`, drain/uncordon).

## Prerequisites
Cluster `cks` with nodes `cks-control-plane` and `cks-worker` Ready. Day 4 API server change left healthy.

## Exam-style question
Context: a two-node kubeadm-style cluster is given with nodes `cks-control-plane` and `cks-worker`, both Ready. Task: determine the available upgrade target for the control plane, validate the upgrade without forcing it, and safely take `cks-worker` out of service and back. Write the exact command sequence for upgrading both nodes to the next minor version to `workspace/week02-upgrade-runbook.md`. Requirements: upgrade control plane before worker, never skip a minor version, and do not break the cluster; at the end no node may be cordoned and all nodes must be Ready.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Record the current version of every node (`kubectl get nodes -o wide`) and the apiserver version (`kubectl version`).
2. In `cks-control-plane` (`docker exec -it cks-control-plane bash`): run `kubeadm version` and `kubeadm upgrade plan`. Write down which target versions it offers (it may warn that it cannot fetch remote versions on kind).
3. Run `kubeadm upgrade apply <target-patch-version> --dry-run` where `<target-patch-version>` is the next patch of your running minor (or the version shown by `plan`). Report the result. Do a real apply only if the plan shows binaries/images are available; do not force it.
4. Drain `cks-worker` with `--ignore-daemonsets` (add `--delete-emptydir-data` if required). Confirm the node shows `SchedulingDisabled` and workload pods moved off it (or are Pending if no capacity).
5. Write, in a file `workspace/week02-upgrade-runbook.md`, the exact command sequence you would run on a real 2-node kubeadm cluster to move from v1.34.x to v1.35.y (control plane then worker), including repo change, package hold/unhold, drain, uncordon.
6. Uncordon `cks-worker`.
7. Verify all nodes report the same version, are `Ready`, and none is cordoned.

## Check your work
- Node versions recorded before and after; on kind they are unchanged unless a real upgrade was possible.
- `kubectl get nodes` shows both `Ready`, with no `SchedulingDisabled`.
- You can explain each section of the `kubeadm upgrade plan` output (component "Current" vs "Target", the `kubeadm upgrade apply` hint).
- The runbook contains: `kubeadm upgrade plan`, `kubeadm upgrade apply`, `kubeadm upgrade node`, drain/uncordon, kubelet restart, and control plane before worker.

## Answer
[answers/week-02-cluster-hardening/day-05-kubeadm-upgrade.md](../../answers/week-02-cluster-hardening/day-05-kubeadm-upgrade.md) — Attempt the task first; only then open the answer.

## Cleanup
Ensure `kubectl uncordon cks-worker` was run; no node may remain cordoned.
