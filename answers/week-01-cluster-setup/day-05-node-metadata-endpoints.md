# Week 1 · Day 5 (Sep 27) — Protect node metadata and endpoints — Answers
Task: [plan/week-01-cluster-setup/day-05-node-metadata-endpoints.md](../../plan/week-01-cluster-setup/day-05-node-metadata-endpoints.md)

## Solution
1. Pods:
```bash
kubectl create ns meta-lab
kubectl run web --image=nginx -n meta-lab
kubectl run client --image=busybox -n meta-lab -- sleep 3600
kubectl wait --for=condition=Ready pod/web pod/client -n meta-lab --timeout=120s
```
2. Policy:
```yaml
# ~/netpol/block-metadata.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: meta-lab
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```
```bash
kubectl apply -f ~/netpol/block-metadata.yaml
```
3. Verify:
```bash
WEB_IP=$(kubectl get pod web -n meta-lab -o jsonpath='{.status.podIP}')
kubectl exec -n meta-lab client -- wget -qO- -T 3 http://$WEB_IP
kubectl exec -n meta-lab client -- nslookup kubernetes.default
sed "s#169.254.169.254/32#$WEB_IP/32#" ~/netpol/block-metadata.yaml | kubectl apply -f -
kubectl exec -n meta-lab client -- wget -qO- -T 3 http://$WEB_IP
kubectl apply -f ~/netpol/block-metadata.yaml
kubectl exec -n meta-lab client -- wget -qO- -T 3 http://$WEB_IP
```
The metadata IP itself will time out either way on kind (no such service), so it cannot prove the policy; the stand-in test does.

4. Kubelet config:
```bash
docker exec cks-worker cat /var/lib/kubelet/config.yaml
```
Kubeadm default excerpt:
```yaml
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
```
`readOnlyPort` is normally absent (defaults to 0 = disabled).

5. Unauthenticated request:
```bash
WORKER_IP=$(kubectl get node cks-worker -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
docker exec cks-control-plane curl -sk https://$WORKER_IP:10250/pods
```
6. Insecure state:
```bash
docker exec cks-worker cp /var/lib/kubelet/config.yaml /root/kubelet-config.bak
docker exec cks-worker bash -c "sed -i '0,/enabled: false/s//enabled: true/; s/mode: Webhook/mode: AlwaysAllow/' /var/lib/kubelet/config.yaml && systemctl restart kubelet"
sleep 10
docker exec cks-control-plane curl -sk https://$WORKER_IP:10250/pods | head -c 300
```
The `0,/enabled: false/` range flips the first `enabled: false`, which is `anonymous.enabled` in the kubeadm layout; check the file with `grep -n -B1 -A2 anonymous` before restarting.

7. Restore:
```bash
docker exec cks-worker bash -c "cp /root/kubelet-config.bak /var/lib/kubelet/config.yaml && systemctl restart kubelet"
sleep 10
docker exec cks-control-plane curl -sk https://$WORKER_IP:10250/pods
kubectl get nodes
```

## Expected output
```
# step 3 wget with real policy: nginx HTML; nslookup answers
# with web IP excepted: wget: download timed out; after restore: nginx HTML
# step 5 / 7:
Unauthorized
# step 6:
{"kind":"PodList","apiVersion":"v1",...
```

## Why it works
The `ipBlock` allows the whole IPv4 space except the metadata /32, so the metadata address is the only external destination dropped by Calico. The kubelet authenticates requests (anonymous/webhook/x509) then authorises them; with anonymous off, an unauthenticated request stops at 401. With `AlwaysAllow`, any authenticated request, including anonymous, is authorised.

## Common mistakes / exam gotchas
- Using `ipBlock` for pod-to-pod isolation and expecting `except` to override other allow rules: policies are additive; another policy allowing the metadata IP would win.
- Forgetting DNS when the policy scopes egress narrowly.
- Blocking `169.254.0.0/16` unintentionally is fine, but a `/24` or wrong mask misses it; use `/32`.
- Editing `/var/lib/kubelet/config.yaml` but not restarting the kubelet; or editing kubeadm flags file `/var/lib/kubelet/kubeadm-flags.env` when the setting lives in the config file.
- `anonymous.enabled: false` alone is not enough if `authorization.mode: AlwaysAllow`: any authenticated client (e.g. any cert signed by the CA) is fully authorised.
- Killing the kubelet on the worker leaves the node `NotReady`; always restore.
- Cloud clusters: also enforce IMDSv2 with hop limit 1 or use workload identity; a NetworkPolicy is one layer.
- On kind the 169.254.169.254 endpoint does not exist; the exam test is usually "does the policy object correctly exclude it".

## Cleanup
```bash
docker exec cks-worker rm -f /root/kubelet-config.bak
kubectl delete ns meta-lab
```
