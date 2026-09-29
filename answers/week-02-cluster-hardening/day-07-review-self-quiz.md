# Week 2 · Day 7 (Oct 6) — Review & self-quiz — Answers
Task: [plan/week-02-cluster-hardening/day-07-review-self-quiz.md](../../plan/week-02-cluster-hardening/day-07-review-self-quiz.md)

## Solution
1. ```
kubectl create namespace quiz-rbac
kubectl create serviceaccount viewer -n quiz-rbac
kubectl create role pod-viewer --verb=get,list,watch --resource=pods -n quiz-rbac
kubectl create rolebinding pod-viewer-binding --role=pod-viewer --serviceaccount=quiz-rbac:viewer -n quiz-rbac
V=system:serviceaccount:quiz-rbac:viewer
kubectl auth can-i list pods --as=$V -n quiz-rbac
kubectl auth can-i watch pods --as=$V -n quiz-rbac
kubectl auth can-i delete pods --as=$V -n quiz-rbac
kubectl auth can-i list pods --as=$V -n default
kubectl auth can-i get secrets --as=$V -n quiz-rbac
```
2. ```
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " -> " + ([.subjects[]? | .kind + "/" + .name] | join(", "))'
```
Expected on kind: `cluster-admin -> Group/system:masters` and `kubeadm:cluster-admins -> Group/kubeadm:cluster-admins`. Both are built-in. Anything binding a user, SA, `system:authenticated` or `system:unauthenticated` is a finding. Also check RoleBindings: `kubectl get rolebindings -A -o json | jq ...`.
3. Model answer:
   - There is no cluster-wide setting. The `default` SA exists per namespace (auto-created with the namespace), so for each namespace run:
     `for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do kubectl patch sa default -n $ns -p '{"automountServiceAccountToken": false}'; done`
   - Why: pods without `serviceAccountName` get `default` and a mounted token, giving a compromised container an API identity (plus any rights bound to `default`). Most workloads never call the API.
   - Caveats: applies only to pods created afterwards (restart existing workloads); a pod spec `automountServiceAccountToken: true` overrides the SA; new namespaces need the same treatment (automate via admission policy/CI); workloads that need the API get a dedicated SA with a least-privilege Role and automount true; never bind roles to `default`. Kube-system components (e.g. CoreDNS, kube-proxy) that need tokens must be checked before patching there; consider excluding `kube-system`.
4. Flags (kube-apiserver, `/etc/kubernetes/manifests/kube-apiserver.yaml`):
   - `--anonymous-auth=false`: reject unauthenticated requests (mind probe behaviour).
   - `--profiling=false`: remove pprof endpoints.
   - `--authorization-mode=Node,RBAC`: never `AlwaysAllow`.
   - `--enable-admission-plugins=NodeRestriction` (+ e.g. `PodSecurity` is on by default): kubelets limited to own Node/Pods.
   - No `--insecure-port` (removed in v1.24) and no `--token-auth-file` (static tokens).
   - `--kubelet-certificate-authority`: verify kubelet serving certs; `--tls-min-version`, `--tls-cipher-suites`: restrict TLS.
   - `--service-account-lookup=true`, `--service-account-key-file`, `--service-account-signing-key-file`.
   - `--audit-log-path`, `--audit-policy-file`, `--audit-log-maxage/maxbackup/maxsize`: audit logging.
   - `--encryption-provider-config`: encrypt secrets at rest in etcd.
   - `--client-ca-file`, `--etcd-cafile/certfile/keyfile`: mutual TLS for clients and etcd.
5. Sequence (control plane `cp`, worker `w`):
```
# on cp
apt-mark unhold kubeadm; apt-get update; apt-get install -y kubeadm=<ver>; apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v<ver>
kubectl drain cp --ignore-daemonsets
apt-get install -y kubelet=<ver> kubectl=<ver>   # after unhold
systemctl daemon-reload; systemctl restart kubelet
kubectl uncordon cp
# on cp (kubectl)
kubectl drain w --ignore-daemonsets
# on w
apt-get install -y kubeadm=<ver>
kubeadm upgrade node
apt-get install -y kubelet=<ver> kubectl=<ver>
systemctl daemon-reload; systemctl restart kubelet
# on cp
kubectl uncordon w
kubectl get nodes
```

## Expected output
Item 1: `yes yes no no no`. Item 2: two built-in lines. Item 5: nodes end `Ready` at the new version.

## Why it works
Recap of the week: RBAC is additive and scoped by binding type; SA tokens are ambient credentials to minimise; API server flags govern authn/authz/admission; upgrades keep components patched with control plane first to respect version skew.

## Common mistakes / exam gotchas
- Naming the Role but binding a different name; wrong `ns:sa` format.
- Believing `default` SA can be disabled globally.
- Forgetting worker uses `upgrade node`, not `upgrade apply`.
- Forgetting `daemon-reload`/kubelet restart and uncordon.
- Listing flags without saying what they do; state the effect for each.

## Cleanup
```
kubectl delete ns quiz-rbac
```
