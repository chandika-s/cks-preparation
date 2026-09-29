# Environment setup — Day 1

## 1. Install CLI tools (Homebrew)

```
brew install kubectl kubernetes-cli helm derailed/k9s/k9s jq yq kind
brew install trivy kube-linter cosign syft
brew install kube-bench   # or run as a container, see Week 1

# kubesec isn't in Homebrew core (no maintained tap) — install the binary directly:
arch=$(uname -m); [ "$arch" = "arm64" ] && karch="arm64" || karch="amd64"
curl -sL "https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_darwin_${karch}.tar.gz" | tar -xz -C /tmp
mv /tmp/kubesec /opt/homebrew/bin/kubesec && chmod +x /opt/homebrew/bin/kubesec
```

## 2. Create the `cks` kind cluster (your one and only cluster for this whole plan)

Calico for real NetworkPolicy enforcement, two nodes for kubeadm-style multi-node practice, and a port mapping + node label so ingress-nginx works (needed for Week 1 Day 4).

```
cat <<'EOF' > kind-cks.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
EOF
kind create cluster --name cks --config kind-cks.yaml
kubectl config use-context kind-cks
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
kubectl get nodes -o wide   # wait until both nodes are Ready
```

Node shell access (used throughout the plan for static pod manifests, kubelet config, kube-bench remediation, kubeadm upgrades):

```
docker exec -it cks-control-plane bash
docker exec -it cks-worker bash
```

## 3. Exam-day muscle memory (set these up now)

```
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```
Add to `~/.zshrc`. In the real exam you get a browser terminal with vim and `kubectl` pre-aliased to `k` — practice using vim (not nano/VS Code) and imperative `kubectl create/run ... $do > file.yaml` then edit, since that's the fastest workflow under time pressure.

## 4. Known gap — AppArmor

`cks` runs inside Docker's own VM, and on macOS that VM (LinuxKit) doesn't ship AppArmor. Check with `aa-status` on the node before Week 3 Day 5. If it's unavailable, treat that day as a written/conceptual exercise and rely on killer.sh's environment (which has full AppArmor support) during Week 7–8. Everything else in the curriculum (NetworkPolicy, kubeadm upgrades, kube-bench, ingress, seccomp) works directly on this cluster.

## 5. Verify

```
kubectl config use-context kind-cks
kubectl get nodes -o wide               # 2 nodes Ready
kubectl get pods -A                     # calico pods Running
trivy --version && kube-bench version && cosign version && kube-linter version && kubesec version
```

If all of the above return without error, you're ready for Week 1.

## 6. Daily start/stop routine

The `cks` cluster's nodes are just Docker containers, so pausing/resuming is really about Docker Desktop, not `kind`.

**Start your study session:**
```
open -a Docker                    # wait for the whale icon in the menu bar to go steady (~30-60s)
docker start cks-control-plane cks-worker   # no-op if they're already running
kubectl config use-context kind-cks
kubectl get nodes                 # confirm both are Ready before starting the day's lab
```

**End your study session** (state is preserved — no need to delete anything):
- Just quit Docker Desktop from the menu bar (or `osascript -e 'quit app "Docker"'`). This stops the whole VM, including the `cks` containers.

**Full teardown** (only if you want to rebuild from scratch, e.g. after a bad `kubeadm upgrade` experiment): `kind delete cluster --name cks`, then redo step 2 above.
