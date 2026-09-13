# Local Kubernetes Cluster

This project uses [kind](https://kind.sigs.k8s.io/) to run a small Kubernetes cluster inside Docker Desktop. It is useful for testing Kubernetes manifests, Helm charts, services, ingress, and CI/CD workflows before deploying to Amazon EKS.

## Architecture

`kind-config.yaml` creates:

- One control-plane node for Kubernetes management components.
- One worker node for application workloads.

This is a development cluster, not a highly available production cluster. The control plane and worker are Docker containers managed by kind.

## Prerequisites

Verify Docker Desktop is running:

```powershell
docker info
```

Verify the tools:

```powershell
kind version
kubectl version --client
helm version --short
```

The local setup currently uses the Kubernetes `v1.34.0` kind node image because the Docker Desktop environment uses cgroup v1.

## Create the cluster

Run these commands from the project root:

```powershell
cd C:\Users\iktea\.vscode\aws-ai-infrastructure-platform
kind create cluster --config .\local-k8s\kind-config.yaml --image kindest/node:v1.34.0
```

The command creates the `kind-eks-local` kubectl context.

## Verify the cluster

```powershell
kubectl config current-context
kubectl get nodes
kubectl get pods --all-namespaces
```

Expected nodes:

```text
eks-local-control-plane   Ready
eks-local-worker          Ready
```

## Deploy a test application

```powershell
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80
kubectl get deployments
kubectl get services
kubectl port-forward service/nginx 8080:80
```

Open `http://localhost:8080` in a browser. Press `Ctrl+C` to stop port forwarding.

## Install the Headlamp Kubernetes GUI

Headlamp provides a Kubernetes UI for nodes, pods, deployments, services, logs, and events. It runs inside the local cluster and is separate from Docker Desktop, which mainly shows the underlying node containers.

Make sure the local cluster is selected:

```powershell
kubectl config use-context kind-eks-local
```

Install Headlamp with its official Helm repository:

```powershell
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
helm install headlamp headlamp/headlamp `
	--namespace headlamp `
	--create-namespace
```

Open the GUI through a local port-forward:

```powershell
kubectl port-forward -n headlamp service/headlamp 4466:80
```

Browse to `http://localhost:4466`. When Headlamp asks for a token, create one in another PowerShell window:

```powershell
kubectl create token headlamp -n headlamp
```

Paste the token into Headlamp. Do not share it. This local installation is intended for development; production should use SSO/OIDC and least-privilege RBAC instead of broad administrator permissions.

## Optional monitoring

Headlamp is a Kubernetes management UI. It does not replace monitoring tools:

- Prometheus collects and stores time-series metrics.
- Grafana displays dashboards and alerts using metrics from Prometheus.

Start with Headlamp only on this 16 GB laptop. Add Prometheus and Grafana when historical metrics, dashboards, or alerts are needed because they consume additional CPU and memory. Do not run them together with Ollama, databases, and several workloads unless Docker resource usage remains healthy.

## Delete the cluster

Deleting the cluster removes its Docker containers and local Kubernetes state:

```powershell
kind delete cluster --name eks-local
```

## Resource guidance

For a 16 GB Windows laptop, start Docker Desktop with about 4 CPUs and 6-8 GB memory. Run Ollama on Windows or WSL separately until resource usage is understood. Keep Prometheus, Grafana, databases, and AI models stopped when they are not needed.
