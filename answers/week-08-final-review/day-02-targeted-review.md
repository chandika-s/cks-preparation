# Week 8 · Day 2 (Nov 13) — Targeted review — Answers
Back to task: [day-02-targeted-review](../../plan/week-08-final-review/day-02-targeted-review.md)

## Solution
**Step 1: redo Day 1 misses.** Timed, max 10 min each, from memory. Order by domain weight. If it fails twice, read the killer.sh solution, then the matching week note, then redo the next day.

**Step 2: cheatsheet out loud.** Read `../../cheatsheet.md` top to bottom; for each block say what it does and when to use it. Any block you stumble on: type it from memory once.

**Step 3: filled-in self-assessment.** Week links go to the week index; day files are listed in each index (task under `plan/week-0X-*/`, answers under `answers/week-0X-*/`).

### Cluster Setup (10%) — [plan index](../../plan/week-01-cluster-setup/README.md), answers dir [answers/week-01-cluster-setup/](../week-01-cluster-setup/)
| # | Meaning (one sentence) | Prove it |
|---|---|---|
| 1 | NetworkPolicy default-deny then explicit allows restrict pod traffic; needs a CNI that enforces it (Calico here). | `kubectl apply -f` a policy with `podSelector: {}` and `policyTypes: [Ingress, Egress]`; `kubectl exec` curl fails, then allow rule works |
| 2 | kube-bench checks components against the CIS benchmark and lists FAIL items to remediate in manifests/config. | `kube-bench run --targets master` (or `kube-bench` job); fix e.g. `--profiling=false` in `/etc/kubernetes/manifests/kube-apiserver.yaml`, rerun |
| 3 | Ingress with a `tls` section and a `kubernetes.io/tls` Secret terminates HTTPS for a host. | `kubectl create secret tls web-tls --cert=tls.crt --key=tls.key`; Ingress `spec.tls[].secretName`; `curl -k --resolve host:443:IP https://host` |
| 4 | Block pods from the cloud metadata endpoint 169.254.169.254 and limit exposed node ports/kubelet. | Egress NetworkPolicy with `ipBlock` `0.0.0.0/0` `except: [169.254.169.254/32]`; `curl -m3 169.254.169.254` fails from pod |
| 5 | Verify downloaded binaries by checksum so tampered ones are rejected. | `sha512sum kubelet` vs published `.sha512`; `echo "<hash>  kubelet" \| sha512sum -c` |

### Cluster Hardening (15%) — [plan index](../../plan/week-02-cluster-hardening/README.md), answers dir [answers/week-02-cluster-hardening/](../week-02-cluster-hardening/)
| # | Meaning | Prove it |
|---|---|---|
| 6 | Grant least-privilege Roles/RoleBindings, avoid wildcards and cluster-admin. | `kubectl create role r --verb=get,list --resource=pods -n ns`; `kubectl create rolebinding ... --serviceaccount=ns:sa`; `kubectl auth can-i delete pods --as=system:serviceaccount:ns:sa -n ns` |
| 7 | Default SA tokens should not auto-mount and new SAs get minimal rights. | `automountServiceAccountToken: false` on SA/pod; `kubectl get sa default -o yaml`; `kubectl auth can-i --list --as=system:serviceaccount:ns:default -n ns` |
| 8 | Limit who can reach the API server: disable anonymous auth, secure port, authorization modes. | Check `--anonymous-auth=false`, `--authorization-mode=Node,RBAC`, `--enable-admission-plugins` in the apiserver manifest; `curl -k https://<api>:6443/version` as anonymous returns 401/403 |
| 9 | Upgrade to patched versions using the kubeadm flow, one minor at a time, control plane first. | `kubeadm upgrade plan`, `kubeadm upgrade apply v1.x.y`, drain/upgrade kubelet/uncordon workers. Limited on kind nodes; known conceptually |

### System Hardening (15%) — [plan index](../../plan/week-03-system-hardening/README.md), answers dir [answers/week-03-system-hardening/](../week-03-system-hardening/)
| # | Meaning | Prove it |
|---|---|---|
| 10 | Remove unneeded packages, services and users on nodes to shrink attack surface. | `systemctl list-units --type=service --state=running`; `systemctl disable --now <svc>`; `apt remove <pkg>`; `ss -tlnp` shows fewer listeners |
| 11 | Least-privilege IAM: minimal cloud roles for nodes, no broad instance profile use, no shared root. | Conceptual on kind; show restricted Linux users, `sudo` config, node role scoped to needed APIs |
| 12 | Close unnecessary host ports and restrict inbound access with a firewall. | `ss -tlnp`; `ufw default deny incoming; ufw allow 22/tcp; ufw enable` (or iptables) |
| 13 | AppArmor confines programs by profile; seccomp filters syscalls. | Pod `securityContext.seccompProfile: {type: Localhost, localhostProfile: ...}` or `RuntimeDefault`; AppArmor: `securityContext.appArmorProfile` (v1.30+) with `apparmor_parser -q profile`. AppArmor unavailable on kind/macOS; conceptual there |

### Minimize Microservice Vulnerabilities (20%) — [plan index](../../plan/week-04-microservice-vulnerabilities/README.md), answers dir [answers/week-04-microservice-vulnerabilities/](../week-04-microservice-vulnerabilities/)
| # | Meaning | Prove it |
|---|---|---|
| 14 | PSA enforces privileged/baseline/restricted per namespace via labels. | `kubectl label ns x pod-security.kubernetes.io/enforce=restricted`; apply a privileged pod and see it rejected; a compliant pod (runAsNonRoot, drop ALL, seccomp RuntimeDefault, no privilege escalation) passes |
| 15 | Secrets are base64, not encrypted, unless encryption at rest is configured; limit access and mount narrowly. | `kubectl create secret generic s --from-literal=k=v`; `EncryptionConfiguration` + `--encryption-provider-config`; `etcdctl get /registry/secrets/ns/s` shows `k8s:enc:` prefix |
| 16 | Isolation via namespaces, quotas, NetworkPolicy, and sandboxed runtimes (gVisor/Kata) with a RuntimeClass. | `RuntimeClass` with `handler: runsc`; pod `runtimeClassName: gvisor`; `dmesg` inside shows gVisor. Runtime not installed on kind; conceptual |
| 17 | Cilium can transparently encrypt pod-to-pod traffic (WireGuard or IPsec). | Cilium helm `--set encryption.enabled=true --set encryption.type=wireguard`; `cilium status \| grep Encryption`. Not applicable to Calico kind-cks; conceptual |

### Supply Chain Security (20%) — [plan index](../../plan/week-05-supply-chain-security/README.md), answers dir [answers/week-05-supply-chain-security/](../week-05-supply-chain-security/)
| # | Meaning | Prove it |
|---|---|---|
| 18 | Smaller images (multi-stage, distroless/alpine, non-root) have fewer vulnerabilities. | Dockerfile with multi-stage build and `USER 1000`; `docker images` size diff; `trivy image` count diff |
| 19 | Know what's in your images and pipeline: SBOMs, provenance, controlled repositories. | `trivy image --format spdx-json -o sbom.json img`; `syft img`; describe CI/CD trust points |
| 20 | Only allow trusted registries and verified signatures via admission control. | ImagePolicyWebhook or ValidatingAdmissionPolicy/OPA Gatekeeper limiting registries; `cosign verify --key cosign.pub img`; pod from a disallowed registry is denied |
| 21 | Scan manifests and images statically before deploy. | `kubesec scan pod.yaml`; `kube-linter lint pod.yaml`; `trivy image --severity HIGH,CRITICAL img`; `trivy config .` |

### Monitoring, Logging and Runtime Security (20%) — [plan index](../../plan/week-06-monitoring-logging-runtime-security/README.md), answers dir [answers/week-06-monitoring-logging-runtime-security/](../week-06-monitoring-logging-runtime-security/)
| # | Meaning | Prove it |
|---|---|---|
| 22 | Falco rules detect anomalous syscall behaviour at runtime. | Falco running; `kubectl exec` shell into a pod; `journalctl -u falco` / `kubectl logs -n falco ds/falco` shows "Terminal shell in container" |
| 23 | Combine runtime, network and audit signals across workloads, nodes and users to spot threats. | Falco alert plus audit log entry plus `kubectl get events`; correlate by pod/user/time |
| 24 | Reconstruct an attack from logs: who, what, when, which phase (access, execution, persistence, exfil). | `grep` audit log for `"user"`, `"verb"`, `"objectRef"`; Falco output fields `user.name`, `proc.cmdline`, `container.id` |
| 25 | Immutable containers: read-only root FS, no shells or package installs at runtime. | `readOnlyRootFilesystem: true`, emptyDir for writable paths; `kubectl exec pod -- touch /x` fails |
| 26 | Audit policy records API requests at chosen levels to a log file or webhook. | Policy file with `rules` (level None/Metadata/Request/RequestResponse); apiserver flags `--audit-policy-file`, `--audit-log-path`, mounts for both; `tail` the log |

**Grading rule:** green = sentence plus command run from memory in under 3 min; amber = needed docs; red = could not do. Spend remaining time only on red then amber.

## Expected output
- A completed table with no red rows; a list of 3–5 amber rows re-run and turned green; cheatsheet read once aloud.

## Why it works
- Forcing a sentence and a command per bullet tests both understanding and speed, the two things the exam measures. The exam bullets map to tasks nearly one to one.

## Common mistakes / exam gotchas
- Confusing flags: audit needs both policy file and log path plus volume mounts on the static pod; encryption at rest needs the config file mounted too.
- Treating base64 as encryption.
- Forgetting DNS egress when writing egress policies.
- AppArmor/gVisor/Cilium/kubeadm-upgrade cannot be fully proven on kind-cks; the exam clusters will support what the task asks.
- Starting new labs today instead of fixing red rows.
- Command details in the table are model shorthand; confirm exact flags in kubernetes.io/docs during practice, not on exam day.

## Cleanup
- Remove any leftover resources from redo tasks (`kubectl delete ns <lab-ns>`); revert control-plane manifest edits from backups.
