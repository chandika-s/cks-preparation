# CKS exam cheatsheet

## Shell setup

```
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```

Fast scaffold-then-edit pattern: `k create deploy web --image=nginx $do > d.yaml`, `vi d.yaml`, `k apply -f d.yaml`.

## Context/namespace safety (do this first, every task)

```
kubectl config get-contexts
kubectl config use-context <name>
kubectl config set-context --current --namespace=<ns>
```

## RBAC

```
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n <ns>
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=<ns>:<sa> -n <ns>
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>
kubectl auth can-i --list --as=<user>
```

## NetworkPolicy skeleton (default-deny)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

## Pod Security Admission

```
kubectl label ns <ns> pod-security.kubernetes.io/enforce=restricted
```

## securityContext hardening block

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop: ["ALL"]
```

## Secrets

```
kubectl create secret generic my-secret --from-literal=key=value
# mount instead of env:
volumes: [{name: secret-vol, secret: {secretName: my-secret}}]
volumeMounts: [{name: secret-vol, mountPath: /etc/secret, readOnly: true}]
```

## kube-bench

```
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

## Trivy / Kubesec / KubeLinter

```
trivy image --severity HIGH,CRITICAL <image>
kubesec scan <manifest.yaml>
kube-linter lint <manifest.yaml>
```

## cosign

```
cosign generate-key-pair
cosign sign --key cosign.key <image>
cosign verify --key cosign.pub <image>
```

## Falco

```
kubectl logs -f -n falco -l app.kubernetes.io/name=falco
```

## Audit policy skeleton

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources: [{group: "", resources: ["secrets"]}]
  - level: Metadata
```
kube-apiserver flags: `--audit-policy-file=<path> --audit-log-path=<path>`, mount both as hostPath in the static pod manifest.

## vim quick config (if not already set in exam env)

```
:set expandtab
:set shiftwidth=2
:set tabstop=2
```

## Useful `kubectl debug`

```
kubectl debug node/<node> -it --image=busybox -- chroot /host bash
kubectl debug <pod> -it --image=busybox --target=<container>
```
