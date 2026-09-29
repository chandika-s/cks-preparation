# Start here

Follow this file top to bottom the first time. After that, your daily loop is section 5.

## 1. What you need

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon or Intel) | Commands assume macOS + Homebrew + zsh. On Linux, replace `brew` with your package manager and skip the Docker Desktop steps. |
| Docker Desktop, running | The `kind` cluster runs as Docker containers. Give Docker ≥ 4 CPUs and ≥ 8 GB RAM. |
| [Homebrew](https://brew.sh) | Used to install every CLI tool. |
| ~10 GB free disk | Images, the kind node images, tool caches. |
| A **passed CKA** | Prerequisite for the CKS exam itself. See [`00-exam-and-cka-renewal.md`](00-exam-and-cka-renewal.md). |

## 2. Get the repo

```
git clone <repo-url> ~/cks-preparation
cd ~/cks-preparation
```

Everything below is run from the repo root.

## 3. Build your lab (Day 1, ~1 hour)

Do [`SETUP.md`](SETUP.md) in order. It takes you through:

1. Installing the CLI tools (`kubectl`, `kind`, `helm`, `trivy`, `kube-bench`, `cosign`, `syft`, `kubesec`, `kube-linter`, …).
2. Creating the `cks` kind cluster from [`kind-cks.yaml`](kind-cks.yaml) (2 nodes, Calico CNI) — run `kind create cluster --name cks --config kind-cks.yaml`.
3. Setting the exam aliases (`k`, `$do`, `$now`).
4. The verify step. **Do not start Week 1 until it passes** (2 nodes `Ready`, Calico pods `Running`, all tool versions print).

## 4. Understand the layout

```
START-HERE.md            <- you are here
SETUP.md                 <- Day 1: install tools + create the cluster
README.md                <- plan overview, calendar, curriculum weighting
00-exam-and-cka-renewal.md
cheatsheet.md            <- kubectl / vim / YAML snippets to memorise
kind-cks.yaml            <- the cluster definition
plan/
  week-01-cluster-setup/
    README.md            <- week index (day, date, topic, links)
    day-01-....md        <- ONE FILE PER DAY: theory + the task + how to check it
    day-02-....md
answers/
  week-01-cluster-setup/
    day-01-....md        <- solution for the matching day (same filename)
workspace/               <- your scratch YAML; put your own work here
scripts/                 <- optional daily reminder (section 6)
```

Rule: **`plan/…/day-NN-*.md` = the question. `answers/…/day-NN-*.md` = the solution, same filename.** Never open the answer first.

## 5. Daily loop (60–90 min)

1. Find today's file: open the calendar in [`README.md`](README.md), or run `bash scripts/today.sh`. Otherwise just take the next unfinished `day-NN` file in the current week folder — the plan is by day number; the dates are only a suggested pace.
2. Start your session: open Docker Desktop, then
   ```
   docker start cks-control-plane cks-worker
   kubectl config use-context kind-cks
   kubectl get nodes        # both Ready before you begin
   ```
3. Read the **Theory**, then do the **Task** cold — only `kubectl`, vim, and kubernetes.io / tool docs (what the real exam allows).
4. Use **Check your work** in the day file to decide if you succeeded.
5. Then open the matching file under `answers/` and compare. Note anything you missed.
6. Stuck for more than 10 minutes? Read the answer, then redo the task from scratch the next day before moving on.
7. Finish with the day's **Cleanup** section if it has one, and quit Docker Desktop (state is preserved).

Week order: Weeks 1–6 cover the six exam domains, Week 7 is timed mixed mock sets, Week 8 is final review + exam. The last day of each domain week is a self-quiz that doubles as catch-up slack.

## 6. Optional: daily reminders (macOS)

Add to `~/.zshrc` (adjust the path if you cloned elsewhere) to get `cks-today` and an auto-print in the first terminal each day:

```
cks-today() { bash "$HOME/cks-preparation/scripts/today.sh"; }
```

`scripts/notify.sh` fires a macOS notification; schedule it with a launchd agent — see the "Staying consistent" section of [`README.md`](README.md). The scripts key off the dates in the day headings and the plan window (Sep 22 → Nov 15, 2026). If you start on a different date, shift the dates in the headings (or edit `START_ISO`/`END_ISO` in the scripts) — or ignore the scripts and just follow day numbers.

## 7. When something breaks

- Cluster won't come up after a reboot: `docker start cks-control-plane cks-worker`, wait ~1 min, `kubectl get nodes`.
- Broke the control plane experimenting (bad static-pod flag, failed upgrade): `kind delete cluster --name cks`, then redo step 2 of [`SETUP.md`](SETUP.md). Re-apply any earlier-day state the current task lists under **Prerequisites**.
- AppArmor tasks (Week 3, Day 5) may not work on macOS Docker Desktop — the day file and its answer say what to do instead.
