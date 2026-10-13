# Argo CD bootstrap and administration

This guide installs a small, single-replica Argo CD on the existing
`ai-platform-dev` EKS cluster. Helm owns the Argo CD installation. Argo CD
manually deploys the application resources from Git. Terraform does not install
Argo CD or own its Kubernetes resources.

The official `argo/argo-cd` Helm chart is pinned to `10.10.2` (Argo CD
`v3.5.4`). The committed configuration is in
[`kubernetes/bootstrap/argocd/values.yaml`](../kubernetes/bootstrap/argocd/values.yaml);
the context-guarded bootstrap script is
[`kubernetes/bootstrap/argocd/install.ps1`](../kubernetes/bootstrap/argocd/install.ps1).
The script uses the official Argo Helm repository and refuses to install unless
the active context is the verified EKS cluster ARN.

## Prerequisites and verified capacity

Verified on 9 October 2026:

| Prerequisite | Observed state |
|---|---|
| AWS account and region | `429496640190`, `eu-central-1` |
| EKS cluster and active kubectl context | `ai-platform-dev`; `arn:aws:eks:eu-central-1:429496640190:cluster/ai-platform-dev` |
| Kubernetes version and worker architecture | Kubernetes `1.35.8`; one Ready `t3.medium` Linux `amd64` node |
| Existing cluster add-ons | VPC CNI, CoreDNS, kube-proxy and Pod Identity Agent are healthy |
| Operator access | Administrator role access works |
| Worker pull access | Worker role already has ECR pull access |
| Git source | Public repository `https://github.com/Ikteaja/aws-ai-infrastructure-platform.git`; current checkout branch `feature/dev-network` |

Before every install, check the context and current allocatable/requested
capacity. Do not add or resize AWS infrastructure as an implicit response to
an unschedulable pod:

```powershell
kubectl config current-context
kubectl get nodes -o wide
kubectl describe nodes
kubectl get pods -A -o wide
```

The single node reported `1930m` allocatable CPU and about `3.2Gi` allocatable
memory. Existing system pods requested `350m` CPU and `140Mi` memory. The
committed Argo CD components request `225m` CPU / `576Mi` memory; the two
application pods together request `200m` / `256Mi`. This fits the observed
request budget with room remaining. Recheck live capacity: actual usage,
other workloads and future requests can change. The limits are caps rather
than reserved capacity. If pods remain `Pending` for insufficient resources,
do not silently change Terraform; reduce optional workloads/requests only
after review or ask for explicit approval to resize the worker infrastructure.

Requirements on the operator machine:

- PowerShell, AWS CLI and an authenticated kubeconfig for the EKS administrator.
- `kubectl` and Helm 3.14 or newer.
- Git read access to the public repository; no GitHub token, deploy key or
  Kubernetes Git credential is needed.
- The Argo CD bootstrap and application manifests committed and pushed to the
  configured branch before Argo CD is expected to read them.

Confirm the intended context immediately before the bootstrap:

```powershell
kubectl config current-context
```

Expected:

```text
arn:aws:eks:eu-central-1:429496640190:cluster/ai-platform-dev
```

The script verifies this exact context before running Helm:

```powershell
.\kubernetes\bootstrap\argocd\install.ps1
```

It installs release `argocd` in namespace `argocd`, waits up to ten minutes,
and rolls back a failed Helm upgrade. Helm is the sole owner of the Argo CD
chart release and its rendered resources. Do not also install Argo CD with
Terraform, Kustomize, or `kubectl`.

## Installation settings and access boundary

The chart values configure one replica each of the application controller,
repo server, API/UI server and Redis. Redis HA, Dex, notifications and
ApplicationSet are disabled to reduce lab resource use. Each enabled component
has explicit CPU/memory requests and limits. The server Service is
`ClusterIP`; both HTTP and gRPC Ingress are disabled. No LoadBalancer, public
DNS name or public ingress is created.

The server uses HTTP behind the Kubernetes Service to support a local
port-forward. The Service is internal and the port-forward binds to loopback
by default. Do not expose the server through a NodePort, public LoadBalancer,
or Ingress. Initial access uses the built-in `admin` account. Rotate its
generated password before ongoing use; do not put it in Git, a terminal
transcript, an issue, or a report.

Verify the chart release and pods:

```powershell
helm status argocd -n argocd
kubectl get pods -n argocd -o wide
kubectl get service argocd-server -n argocd
```

Expected: Helm reports release `argocd` deployed; the controller, repo-server,
server and Redis pods are Ready; `argocd-server` is `ClusterIP`.

## Open the UI locally and rotate the password

Keep this command running in a dedicated PowerShell window:

```powershell
kubectl port-forward -n argocd service/argocd-server 8080:80
```

Open `http://127.0.0.1:8080`. The endpoint is available only through the
operator's local port-forward; stop port-forwarding when finished.

To retrieve the one-time initial password on the trusted administrator
workstation, decode the Kubernetes Secret locally and use the value only in
the UI login. The command prints a secret, so do not run it while recording a
terminal session or sharing the screen:

```powershell
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret `
  -o "jsonpath={.data.password}"
[System.Text.Encoding]::UTF8.GetString(
  [System.Convert]::FromBase64String($encoded)
)
```

Immediately after signing in, use the user menu's password-update option to
set a unique password. Do not reuse an AWS, GitHub or workstation password.
The password is held by Argo CD in its own Kubernetes Secret. A password
rotation does not require a Git commit or an AWS access key.

## Public Git repository access

The source repository is public:

```text
https://github.com/Ikteaja/aws-ai-infrastructure-platform.git
```

Argo CD reads it over unauthenticated HTTPS using its repo-server. No
repository Secret, personal access token, deploy key or AWS credential is
configured. The Application currently tracks `feature/dev-network`, the
verified current checkout branch. Its source path is
`kubernetes/applications/overlays/dev`.

The branch must exist on GitHub and contain the reviewed GitOps files before
the Application can render them. Check the source status in the Application
details after bootstrapping it. A successful comparison with rendered
manifests and no repository authentication or fetch error confirms that the
repo-server can read Git. If the repository becomes private, stop and configure
a read-only deploy key or restricted GitHub credential through a separately
reviewed Secret setup; never commit credential material or include it in
command output.

## Bootstrap Argo CD project and Application

The AppProject and Application are explicitly bootstrapped by the operator;
they are not managed by Terraform, Helm, or an app-of-apps Application.
After Argo CD CRDs are Ready and the GitOps files have been pushed, check the
context again and apply the two bootstrap objects:

```powershell
kubectl config current-context
kubectl apply --dry-run=server -f .\kubernetes\argocd\projects\healthops-dev.yaml
kubectl apply --dry-run=server -f .\kubernetes\argocd\applications\healthops-dev.yaml
kubectl apply -f .\kubernetes\argocd\projects\healthops-dev.yaml
kubectl apply -f .\kubernetes\argocd\applications\healthops-dev.yaml
```

The `healthops-dev` AppProject permits only this Git repository, the in-cluster
destination and namespace `healthops-dev`, the Namespace cluster resource,
and the application Deployment, Service and ConfigMap namespaced kinds. The
Application has no automated sync, prune or self-heal policy. Review its
rendered diff and trigger the first sync explicitly from the UI's **Sync**
button or with the Argo CD CLI:

```powershell
argocd app get healthops-dev
argocd app diff healthops-dev
argocd app sync healthops-dev
argocd app wait healthops-dev --sync --health --timeout 300
```

Do not apply application Deployments or Services directly with `kubectl`.
Argo CD owns those workloads after the manual sync. The `healthops-dev`
Namespace is declared by the dev Kustomize overlay and is created/reconciled
by this Application; do not create a second namespace owner using a separate
script, Terraform resource or Argo `CreateNamespace` option.

For application tests, image replacement, request verification, rollback and
cleanup, see the [EKS application deployment runbook](eks-application-deployment.md).

## Upgrade and cleanup

To upgrade Argo CD, review the official chart release and compatibility notes,
update the pinned chart version in `install.ps1`, validate the new chart with
`helm lint` and `helm template`, and review the resource diff before rerunning
the script. Helm remains the one release owner.

Application cleanup must be deliberate. With automated pruning disabled,
removing an object from Git does not remove it until an operator manually
syncs with prune. Deleting only the Application may orphan its managed
resources unless cascading deletion is explicitly requested. Follow the
runbook's cascade cleanup procedure before deleting the AppProject. To remove
Argo CD itself, review and run `helm uninstall argocd -n argocd`; the chart
retains its CRDs by design. Delete namespace `argocd` and retained CRDs only
after confirming that no Argo CD Applications or other users depend on them.
