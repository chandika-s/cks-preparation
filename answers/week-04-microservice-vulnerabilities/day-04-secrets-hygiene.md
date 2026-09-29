# Week 4 · Day 4 (Oct 15) — Secrets hygiene — Answers
Task: [day-04-secrets-hygiene](../../plan/week-04-microservice-vulnerabilities/day-04-secrets-hygiene.md)

## Solution
1. Namespace and Secret:
```
kubectl create ns secrets-lab
kubectl create secret generic db-creds -n secrets-lab --from-literal=username=appuser --from-literal=password=S3cr3tPassw0rd
```
2. Env-based Deployment:
```
kubectl create deploy app -n secrets-lab --image=busybox:1.36 --dry-run=client -o yaml -- sleep 3600 > app.yaml
```
Edit `app.yaml` container to add:
```yaml
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-creds
              key: password
```
```
kubectl apply -f app.yaml
kubectl exec -n secrets-lab deploy/app -- env | grep DB_PASSWORD
```
3. Replace the `env` block with a volume:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: busybox
        image: busybox:1.36
        command: ["sleep", "3600"]
        volumeMounts:
        - name: creds
          mountPath: /etc/db-creds
          readOnly: true
      volumes:
      - name: creds
        secret:
          secretName: db-creds
          defaultMode: 0400
```
`kubectl apply -f app.yaml` (container name must match the earlier one or the labels must be consistent; `kubectl create deploy` names the container `busybox` after the image, and `app: app` as label).

4. Verify:
```
kubectl exec -n secrets-lab deploy/app -- cat /etc/db-creds/password
kubectl exec -n secrets-lab deploy/app -- env | grep DB_PASSWORD
kubectl exec -n secrets-lab deploy/app -- ls -lL /etc/db-creds/
```
5. Spec check:
```
kubectl get pod -n secrets-lab -o yaml | grep -ci -e S3cr3tPassw0rd -e UzNjcjN0UGFzc3cwcmQ
kubectl get pod -n secrets-lab -o yaml | grep -n -B2 -A4 db-creds
```
6. Write attempt:
```
kubectl exec -n secrets-lab deploy/app -- sh -c 'echo x > /etc/db-creds/password'
```
7. Options: Sealed Secrets (encrypt with the controller's public key, commit the SealedSecret); External Secrets Operator / Secrets Store CSI Driver (sync or mount from Vault/AWS Secrets Manager); SOPS (encrypt manifest values with KMS/age before commit).

## Expected output
```
S3cr3tPassw0rd                     (cat)
                                    (env grep: nothing, exit 1)
-r-------- ... password                          (ls -lL; plain ls -l shows symlinks into ..data/)
0                                   (grep count)
sh: can't create /etc/db-creds/password: Read-only file system
```
The pod YAML shows only `secret: {defaultMode: 256, secretName: db-creds}` under volumes (256 = 0400 octal).

## Why it works
`secretKeyRef` and `secret` volumes are resolved by the kubelet at container start; the pod object stores references only. The volume is a tmpfs mount populated by the kubelet, so the value lives in the container's filesystem view, not the API object. `readOnly: true` on the mount prevents modification.

## Common mistakes / exam gotchas
- Believing `kubectl get pod -o yaml` reveals a `secretKeyRef` value; it does not. The real env exposure is inside the container (`env`, `/proc/*/environ`) and anything that dumps it. Plaintext `env.value` is the case that leaks in the spec.
- `defaultMode` written as decimal `400` (that is octal 0620); write `0400` in YAML (YAML 1.1 octal) or decimal `256`. With a non-root `runAsUser`, mode 0400 owned by root is unreadable unless `fsGroup` is set (mode 0440 + `fsGroup`).
- `subPath` mounts do not receive Secret updates.
- Not restarting the pods after changing the env var source: env values do not refresh.
- Secrets in base64 are not "encrypted"; RBAC and encryption at rest are separate controls.

## Cleanup
```
kubectl delete ns secrets-lab
rm -f app.yaml
```
