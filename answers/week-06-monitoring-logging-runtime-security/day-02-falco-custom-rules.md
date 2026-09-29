# Week 6 · Day 2 (Oct 29) — Falco: custom rules — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-02-falco-custom-rules.md](../../plan/week-06-monitoring-logging-runtime-security/day-02-falco-custom-rules.md)

## Solution
1. Lab:
```
kubectl create ns rules-lab
kubectl run probe -n rules-lab --image=nginx
```
2. Rule file:
```
mkdir -p workspace/week-06
```
`workspace/week-06/shadow-rule.yaml`:
```yaml
- rule: Read shadow file in container
  desc: Detect any process opening /etc/shadow for reading inside a container
  condition: >
    open_read and container and fd.name = /etc/shadow
  output: >
    CUSTOM: shadow file read (user=%user.name proc=%proc.name cmd=%proc.cmdline
    file=%fd.name container=%container.name pod=%k8s.pod.name ns=%k8s.ns.name)
  priority: WARNING
  tags: [custom, filesystem]
```
3. Validate (default rules first so macros resolve). Copy the file into a Falco pod and validate:
```
POD=$(kubectl get pod -n falco -o name | head -1)
kubectl cp workspace/week-06/shadow-rule.yaml falco/${POD#pod/}:/tmp/shadow-rule.yaml -c falco
kubectl exec -n falco $POD -c falco -- falco -V /etc/falco/falco_rules.yaml -V /tmp/shadow-rule.yaml
```
Expect `Ok` for both files. If `kubectl cp` fails (no `tar` in the Falco image), skip to step 4 and watch startup logs for rule-load errors instead.
4. Deliver via Helm. The `customRules` value needs the rule as a string; use `--set-file` with the file name as the key (escape the dot):
```
helm upgrade falco falcosecurity/falco -n falco --reuse-values \
  --set-file 'customRules.shadow-rule\.yaml=workspace/week-06/shadow-rule.yaml'
kubectl rollout restart ds/falco -n falco
kubectl rollout status ds/falco -n falco
```
Equivalent with a values file `custom-rules-values.yaml`:
```yaml
customRules:
  shadow-rule.yaml: |-
    - rule: Read shadow file in container
      ...
```
and `helm upgrade falco falcosecurity/falco -n falco --reuse-values -f custom-rules-values.yaml`.
5. Present:
```
kubectl exec -n falco $POD -c falco -- ls /etc/falco/rules.d
```
6. Trigger:
```
kubectl exec -n rules-lab probe -- cat /etc/shadow
```
(No TTY needed; this rule does not depend on one.)
7. Find alert:
```
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=50 | grep -E 'CUSTOM|sensitive file'
```
8. `kubectl exec -n rules-lab probe -- cat /etc/hostname` produces no custom alert.

## Expected output
```
10:31:44.0: Warning CUSTOM: shadow file read (user=root proc=cat cmd=cat /etc/shadow file=/etc/shadow container=probe pod=probe ns=rules-lab)
10:31:44.0: Warning Sensitive file opened for reading by non-trusted program (file=/etc/shadow ...)
```
The second line is the default rule; it may or may not fire depending on rule version, and both firing is normal.

## Why it works
`open_read` (default macro) matches `open`/`openat` syscalls with read flags; `container` restricts to container processes; `fd.name = /etc/shadow` is an exact path match. Files in `/etc/falco/rules.d` are loaded after the default file, so the macros resolve. Falco reads rules at startup, so pods must restart (or use hot reload) to pick up changes.

## Common mistakes / exam gotchas
- YAML: rule must be a list item (`- rule:`); folded scalars (`>`) for multi-line conditions/outputs.
- Unknown macro/field -> Falco fails to start: check `kubectl logs` of the crash-looping pod. Fix or remove the rule.
- Using `helm upgrade` without `--reuse-values` resets earlier `driver.kind`/`tty` settings.
- Unescaped dot in `--set-file customRules.shadow-rule.yaml=...` creates nested keys.
- Editing `/etc/falco/falco_rules.yaml` directly: on a real exam host that is fine (then `systemctl restart falco`), but on Helm-managed Falco it is overwritten; use `rules.d`.
- Using `fd.name contains shadow` matches too much (`/etc/shadow-`, `gshadow`).
- Not restarting Falco after changing rules.

## Cleanup
```
kubectl delete ns rules-lab
```
