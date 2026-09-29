# CKS Preparation — Sep 22 → Nov 15, 2026

55-day plan built from the **official CNCF CKS Exam Curriculum** (`cncf/curriculum`, `CKS_Curriculum v1.34.pdf`, exam runs on Kubernetes v1.35) and the official exam page (training.linuxfoundation.org). **New here? Read [`START-HERE.md`](START-HERE.md) first.** See [`00-exam-and-cka-renewal.md`](00-exam-and-cka-renewal.md) for exam logistics and your CKA question.

Hands-on labs are practiced daily on a single local **`kind` cluster** (`cks`, 2 nodes + Calico) per [`SETUP.md`](SETUP.md) — one cluster for the whole plan, close to exam parity for NetworkPolicy enforcement, multi-node/kubeadm layout, and static pod manifest access.

> Labs below are original tasks written to match the curriculum and the public, documented question **style** (same style used by killer.sh/KodeKloud-type practice sets). They are not reproductions of real proctored exam questions — sharing actual exam content violates the CNCF candidate agreement.

## Curriculum weighting (official)

| Domain | Weight | Week(s) |
|---|---|---|
| Cluster Setup | 15% | [Week 1](plan/week-01-cluster-setup/README.md) |
| Cluster Hardening | 15% | [Week 2](plan/week-02-cluster-hardening/README.md) |
| System Hardening | 10% | [Week 3](plan/week-03-system-hardening/README.md) |
| Minimize Microservice Vulnerabilities | 20% | [Week 4](plan/week-04-microservice-vulnerabilities/README.md) |
| Supply Chain Security | 20% | [Week 5](plan/week-05-supply-chain-security/README.md) |
| Monitoring, Logging and Runtime Security | 20% | [Week 6](plan/week-06-monitoring-logging-runtime-security/README.md) |

Days allocated per domain are roughly proportional to exam weight.

## Calendar

| Days | Dates | Focus |
|---|---|---|
| 1 | Sep 22 | [Environment setup](SETUP.md) |
| 2–8 | Sep 23–29 | [Week 1 — Cluster Setup](plan/week-01-cluster-setup/README.md) |
| 9–15 | Sep 30–Oct 6 | [Week 2 — Cluster Hardening](plan/week-02-cluster-hardening/README.md) |
| 16–20 | Oct 7–11 | [Week 3 — System Hardening](plan/week-03-system-hardening/README.md) |
| 21–28 | Oct 12–19 | [Week 4 — Minimize Microservice Vulnerabilities](plan/week-04-microservice-vulnerabilities/README.md) |
| 29–36 | Oct 20–27 | [Week 5 — Supply Chain Security](plan/week-05-supply-chain-security/README.md) |
| 37–44 | Oct 28–Nov 4 | [Week 6 — Monitoring, Logging & Runtime Security](plan/week-06-monitoring-logging-runtime-security/README.md) |
| 45–51 | Nov 5–11 | [Week 7 — Mixed timed mocks](plan/week-07-mock-exams/README.md) |
| 52–55 | Nov 12–15 | [Week 8 — Final review & exam](plan/week-08-final-review/README.md) |

Each week is a folder with one file per day under `plan/` (**theory** + a detailed **task** + how to check it) and a matching solution under `answers/` (same filename). Attempt the task before opening its answer. The last day of every domain week is a review/self-quiz day — use it as slack if a prior day ran long.

## Daily routine (suggested, ~60–90 min)

1. Read the day's theory bullets (10 min) — pull up `kubectl explain` / official docs for anything unfamiliar.
2. Do the hands-on task cold, from memory, using only `kubectl` + vim + the allowed doc sites (kubernetes.io, kubectl cheat sheet, tools' own docs) — that's what's allowed in the real exam.
3. Check your work against the day file's "Check your work" section, then compare with the matching file in `answers/`.
4. If stuck >10 min, read the answer, then redo the task from scratch the next day before moving on.

## Staying consistent

- **Terminal:** the first new Terminal window you open each day auto-prints today's section (via a snippet added to `~/.zshrc`). Run `cks-today` anytime to see it again.
- **Notification:** a macOS notification fires daily at 4:00 PM with today's topic, via `~/Library/LaunchAgents/com.cks.dailyreminder.plist` running `scripts/notify.sh`. If you don't see it, check System Settings → Notifications → Terminal/Script Editor is allowed.
- To change the time: edit the `Hour`/`Minute` in the plist, then `launchctl unload/load ~/Library/LaunchAgents/com.cks.dailyreminder.plist`.
- To turn either off: remove the snippet from `~/.zshrc`, or `launchctl unload ~/Library/LaunchAgents/com.cks.dailyreminder.plist && rm ~/Library/LaunchAgents/com.cks.dailyreminder.plist`.

## Reference

- [`cheatsheet.md`](cheatsheet.md) — imperative kubectl, vim/tmux exam setup, common admission/security snippets.
- [`00-exam-and-cka-renewal.md`](00-exam-and-cka-renewal.md) — exam format, CKA prerequisite, and whether CKS extends your CKA.
