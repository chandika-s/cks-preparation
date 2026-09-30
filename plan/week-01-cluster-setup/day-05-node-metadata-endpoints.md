# Week 1 · Day 5 (Sep 27) — Protect node metadata and endpoints
**Domain:** Cluster Setup (15%) — protect node metadata and endpoints | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Block pod access to the cloud metadata IP with an egress NetworkPolicy while allowing everything else.
- Audit the kubelet's authentication, authorization and read-only port settings.
- Demonstrate the kubelet API's behaviour with and without anonymous access, then restore the secure configuration.

## Theory
- Cloud instance metadata endpoint `169.254.169.254` (AWS/GCP/Azure) can hand out node IAM credentials and instance data to any pod that can reach it. Mitigate with an egress NetworkPolicy using `ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}`, and by cloud-side controls (IMDSv2 hop limit, workload identity).
- Kind has no metadata service, so the IP is not reachable anyway; practise the policy shape and verify it functionally with a stand-in IP (a pod IP).
- Once a pod is selected by an egress policy, only what the policy allows is permitted. DNS is allowed in its own explicit rule so the intent is visible; note `ipBlock` also matches pod IPs.
- Kubelet API (port 10250) serves `/pods`, `/exec`, `/run`, `/logs`. Secure it: `authentication.anonymous.enabled: false`, `authentication.webhook.enabled: true`, `authorization.mode: Webhook`, plus client CA (`authentication.x509.clientCAFile`). Flag equivalents: `--anonymous-auth=false`, `--authorization-mode=Webhook`, `--client-ca-file`.
- Read-only port (10255): unauthenticated; disable with `readOnlyPort: 0` (`--read-only-port=0`).
- Kubelet config file on kubeadm nodes: `/var/lib/kubelet/config.yaml`; the service is `kubelet` (restart with `systemctl restart kubelet`).
- Response semantics: 401 Unauthorized = unauthenticated request rejected; 403 Forbidden = authenticated but not authorised; JSON pod list = open.
- Useful commands: `kubectl get node -o wide`, `grep -A6 -E 'authentication|authorization|readOnlyPort' /var/lib/kubelet/config.yaml`, `ss -ltnp`.

## Prerequisites
None required. This lab uses a fresh namespace so Day 1-2 policies do not apply. Shell access via `docker exec cks-control-plane` and `docker exec cks-worker`.

## Exam-style question
Context: cluster `kind-cks` has nodes `cks-control-plane` and `cks-worker`. Task: in namespace `meta-lab` with pods `web` (nginx) and `client` (busybox), create NetworkPolicy `block-metadata` so every pod can send egress anywhere except the cloud metadata address `169.254.169.254`, while DNS to CoreDNS in `kube-system` stays allowed and ingress is unaffected. Save it as `~/netpol/block-metadata.yaml`. Also audit the kubelet on `cks-worker` so anonymous requests to port 10250 are rejected (HTTP 401), authorization uses Webhook, and the read-only port is disabled. Requirements: both nodes must be Ready at the end and the kubelet config must be in its secure state.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create namespace `meta-lab` and run pods `web` (image `nginx`) and `client` (image `busybox`, `sleep 3600`) in it.
2. Create NetworkPolicy `block-metadata` in `meta-lab` applying to all pods: allow all egress to any IPv4 address except `169.254.169.254/32`, and allow DNS (UDP and TCP 53) to the CoreDNS pods in `kube-system` in a separate rule. Ingress must not be affected. Save it as `~/netpol/block-metadata.yaml`.
3. Verify functionally: from `client`, `web`'s pod IP must be reachable and DNS must resolve. Then edit a temporary copy of the policy that excepts `web`'s pod IP `/32` instead of the metadata IP and show `client` can no longer reach `web`; restore the original policy afterwards.
4. On node `cks-worker`, inspect `/var/lib/kubelet/config.yaml`. Record the values of `authentication.anonymous.enabled`, `authentication.webhook.enabled`, `authorization.mode` and `readOnlyPort`.
5. Get the worker node's InternalIP. From inside the control-plane node container, request `https://<worker-ip>:10250/pods` with no credentials and record the HTTP status/body.
6. To see the insecure state: on `cks-worker` temporarily set `authentication.anonymous.enabled: true` and `authorization.mode: AlwaysAllow`, restart the kubelet, and repeat the request from step 5. Record the result.
7. Restore `anonymous.enabled: false` and `authorization.mode: Webhook`, restart the kubelet, repeat the request, and confirm it is rejected again and that the node is `Ready`.

## Check your work
- `kubectl get netpol -n meta-lab block-metadata -o yaml` has an `ipBlock` with `cidr: 0.0.0.0/0` and `except: [169.254.169.254/32]`, and a separate DNS rule with port 53 UDP and TCP.
- Client can `wget` web's IP and resolve names under the real policy.
- With the stand-in exception the request to `web` times out; after restoring it works again.
- Secure kubelet config: anonymous disabled, webhook authn enabled, authorization `Webhook`, `readOnlyPort: 0` (or absent, which defaults to disabled on kubeadm).
- Step 5 returns `Unauthorized` (HTTP 401) on the secure config; step 6 returns pod JSON; step 7 returns `Unauthorized` again.
- `kubectl get nodes` shows both nodes `Ready` at the end and `/var/lib/kubelet/config.yaml` on `cks-worker` matches the secure values.

## Answer
[answers/week-01-cluster-setup/day-05-node-metadata-endpoints.md](../../answers/week-01-cluster-setup/day-05-node-metadata-endpoints.md) — Attempt the task first; only then open the answer.

## Cleanup
Ensure step 7 restored the kubelet config. `kubectl delete ns meta-lab`.
