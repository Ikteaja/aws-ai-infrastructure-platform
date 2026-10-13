$ErrorActionPreference = "Stop"

$expectedContext = "arn:aws:eks:eu-central-1:429496640190:cluster/ai-platform-dev"
$context = (& kubectl config current-context).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the active kubectl context."
}
if ($context -ne $expectedContext) {
    throw "Refusing to install Argo CD: active context '$context' is not '$expectedContext'."
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$valuesFile = Join-Path $scriptDirectory "values.yaml"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
if ($LASTEXITCODE -ne 0) {
    throw "Could not add the official Argo Helm repository."
}

helm repo update argo
if ($LASTEXITCODE -ne 0) {
    throw "Could not refresh the official Argo Helm repository."
}

helm upgrade --install argocd argo/argo-cd `
    --namespace argocd `
    --create-namespace `
    --version 10.10.2 `
    --values $valuesFile `
    --wait `
    --timeout 10m `
    --atomic
if ($LASTEXITCODE -ne 0) {
    throw "Argo CD Helm installation failed."
}

kubectl get pods -n argocd -o wide
