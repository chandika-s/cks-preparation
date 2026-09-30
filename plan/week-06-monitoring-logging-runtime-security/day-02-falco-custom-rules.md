# Week 6 · Day 2 (Oct 29) — Falco: custom rules
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Write a Falco rule from scratch using conditions, macros and output fields.
- Deliver it to Falco through a ConfigMap and reload Falco.
- Trigger the rule and verify the custom output.

## Theory
Custom rules are YAML list items. Required rule fields: `rule` (name), `desc`, `condition`, `output`, `priority`. Optional: `enabled`, `tags`, `exceptions`.

- `condition`: boolean filter expression over event fields. Operators: `=`, `!=`, `in (...)`, `contains`, `startswith`, `and`, `or`, `not`, parentheses.
- Common fields: `evt.type`, `evt.dir`, `proc.name`, `proc.cmdline`, `user.name`, `fd.name`, `fd.sip`, `fd.snet`, `container.id`, `container.name`, `container.image.repository`, `k8s.ns.name`, `k8s.pod.name`.
- Macros from the default rules file are reusable: `open_read`, `open_write`, `container`, `spawned_process`, `shell_procs`. Custom files in `/etc/falco/rules.d/` are loaded after `falco_rules.yaml`, so they can reference its macros. Validate a rule file with `falco -V`.
- `output`: template with `%field` substitutions; include enough to investigate (user, process, file, container, pod, namespace).
- `priority`: EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG.
- Helm delivery: value `customRules.<filename>: |-` creates a ConfigMap (`falco-rules`) mounted at `/etc/falco/rules.d`. Reload by `helm upgrade` (pod template changes) or `kubectl rollout restart ds/falco -n falco`.
- Write rules against a threat model (what must never happen), not only defaults. Scope tightly to avoid alert noise.

## Prerequisites
Day 1: Falco installed in namespace `falco` (release `falco`, `modern_ebpf`, `tty=true`).

## Exam-style question
Context: Falco is running as Helm release `falco` in namespace `falco`, and namespace `rules-lab` contains a pod `probe` (image `nginx`). Task: create a custom rule named `Read shadow file in container` in `workspace/week-06/shadow-rule.yaml` that alerts at `WARNING` with tags `custom` and `filesystem` whenever a container process opens `/etc/shadow` for reading. Requirements: the output must start with `CUSTOM: shadow file read` and include user, process, command line, file name, container, pod and namespace; the rule must be loaded by every Falco pod without dropping earlier Helm values; reading `/etc/hostname` must not trigger it.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create namespace `rules-lab` and a pod `probe` in it running `nginx`.
2. Write a custom Falco rule file `workspace/week-06/shadow-rule.yaml` containing one rule named `Read shadow file in container`:
   - Fires when any process opens `/etc/shadow` for reading inside a container.
   - Priority `WARNING`, tags `[custom, filesystem]`.
   - Output must start with `CUSTOM: shadow file read` and include user name, process name, command line, file name, container name, pod name and namespace.
3. Validate the rule file syntax using the Falco binary (the default rules must be loaded too, since you use its macros).
4. Deliver the rule to Falco as a ConfigMap-backed rules file via the Helm release, keeping all earlier values, and make sure every Falco pod has restarted and is ready.
5. Confirm the file is present in a Falco pod under `/etc/falco/rules.d/`.
6. Exec into `probe` and run `cat /etc/shadow`.
7. Find the alert with your custom message in the Falco pod logs on that node. Note whether the default rule "Read sensitive file untrusted" also fired.
8. Run `cat /etc/hostname` in `probe` and confirm no custom alert.

## Check your work
- `helm get values falco -n falco` shows `customRules` plus the earlier `driver.kind` and `tty` values.
- Falco pods show a recent `AGE` and are ready.
- The log contains `Warning CUSTOM: shadow file read` with `container=probe pod=probe ns=rules-lab`.
- No custom alert for `/etc/hostname`.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-02-falco-custom-rules.md](../../answers/week-06-monitoring-logging-runtime-security/day-02-falco-custom-rules.md) — Attempt the task first; only then open the answer.

## Cleanup
Leave the rule loaded (harmless). `kubectl delete ns rules-lab`.
