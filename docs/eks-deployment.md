# HealthOps EKS dev deployment

**Status: Terraform and IAM configuration prepared; the EKS cluster and node
group have not been deployed or verified.** This guide describes the proposed
`ai-platform-dev` lab deployment. No Terraform apply or destroy is authorized
by this change.

## Architecture

```mermaid
flowchart TB
    Admin["Admin laptop\nAWS IAM Identity Center"]
    Admin -->|"ai-lab-admin assumes healthops-dev-eks-admin\nPublic API allowlist: current administrator /32"| API["EKS Kubernetes API"]

    subgraph VPC["Existing VPC 10.40.0.0/16"]
        subgraph PrivateA["Private subnet eu-central-1a"]
            WorkerA["On-Demand x86 worker\nai-platform-dev-cpu"]
        end
        subgraph PrivateB["Private subnet eu-central-1b"]
            WorkerB["Second worker only if scaled"]
        end
        EKS["EKS managed control plane\nKubernetes 1.35"]
        CPGroup["Prepared control-plane security group"]
        WorkerGroup["Prepared worker security group"]
        EKS --> CPGroup
        WorkerA --> WorkerGroup
        WorkerB --> WorkerGroup
        CPGroup <-->|"443, 10250"| WorkerGroup
        WorkerGroup <-->|"node/pod internal"| WorkerGroup
        WorkerA -->|"private routes"| NAT["Existing NAT Gateway"]
        NAT --> ECR["Existing ECR: api and mock-model"]
        WorkerA --> CNI["VPC CNI / CoreDNS / kube-proxy"]
    end
    ECR -->|"image pulls via HTTPS and S3 endpoint"| WorkerA
```

The existing network is reused through `module.network` outputs. The plan must
not create a second VPC, subnet, NAT Gateway, S3 endpoint, or copy of either
prepared security group.

| Responsibility | Proposed configuration |
|---|---|
| EKS control plane | AWS-managed Kubernetes API, etcd, scheduler and controllers |
| CPU workers | EKS managed node group in both existing private subnets; Amazon Linux 2023 x86_64; On-Demand |
| Node bootstrap | EKS-managed node group lifecycle; no SSH key or remote-access block |
| Pod networking | AWS VPC CNI EKS add-on, using a dedicated Pod Identity role |
| Cluster DNS and service forwarding | Managed CoreDNS and kube-proxy add-ons |
| Control-plane logs | All five EKS log types, CloudWatch retention of 30 days |
| Application images | Existing `healthops-dev/api` and `healthops-dev/mock-model` ECR repositories |
| Public application access | Not included; services remain ClusterIP and no ALB is created |

Kubernetes `1.35` was selected on 6 October 2026. AWS lists it in standard
support through 27 March 2027. AWS's current VPC CNI, CoreDNS, and kube-proxy
compatibility tables include 1.35. Terraform queries the EKS API for the newest
compatible version of each add-on at plan time; those versions are visible in
the reviewed plan. Recheck regional EKS version and add-on availability before
deployment or upgrading:

- [EKS Kubernetes version lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- [VPC CNI versions](https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html)
- [CoreDNS versions](https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html)
- [kube-proxy versions](https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html)

The EKS Pod Identity Agent is also installed so the VPC CNI can use its
dedicated IAM role. It is an identity prerequisite, not an application
platform component.

CloudWatch Logs encrypts log data at rest by default using service-managed
encryption; this lab does not create a separate customer-managed KMS key for
the cluster log group. The 30-day retention is intentional for a cost-conscious
development environment and must be increased before production. EKS clusters
running Kubernetes 1.28 and later also receive default envelope encryption for
all Kubernetes API data using an AWS-owned KMS key; a customer-managed key is
not configured in this milestone. See the AWS documentation for [CloudWatch
Logs encryption](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/data-protection.html)
and [EKS default envelope encryption](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html).

## Existing and proposed AWS resources

The known live network values below are verification references only. Terraform
uses module outputs instead of these IDs.

| Resource | Reference | Status |
|---|---|---|
| VPC | `vpc-0213b3c62cb94e86d` | Existing; reused through `module.network.vpc_id` |
| Private subnet A | `subnet-097a6504a725de799` | Existing; reused through `module.network.private_subnet_ids` |
| Private subnet B | `subnet-0a520b845174e472e` | Existing; reused through `module.network.private_subnet_ids` |
| Prepared additional control-plane SG | `sg-09328f4bbdd240d6c` | Existing; reused through `module.network.eks_control_plane_security_group_id` |
| Prepared worker SG | `sg-0b14ae0a05f3d32b7` | Existing; reused through `module.network.eks_worker_security_group_id` |
| NAT, S3 endpoint, routes and seven standalone egress rules | Existing network configuration | Already created and checked in AWS; not duplicated here |
| ECR images | `healthops-dev/api`, `healthops-dev/mock-model` | Already published; worker role gets pull-only permissions |
| EKS cluster, node group, launch template, add-ons, log group and access entry | `ai-platform-dev` | Proposed by the dev Terraform module; not deployed |
| EKS cluster, worker and VPC CNI IAM roles | `healthops-dev-eks-cluster`, `healthops-dev-eks-workers`, `healthops-dev-eks-vpc-cni` | Created by bootstrap on 6 October 2026 with required AWS-managed policy attachments |
| EKS Terraform plan/apply policies | `healthops-dev-eks-plan-read`, `healthops-dev-eks-apply` | Created by bootstrap and attached to the Terraform plan/apply roles on 6 October 2026 |
| EKS administrator role | `healthops-dev-eks-admin` | Existing; trust is configured for the verified SSO role |

The existing administrator role trust names the previously verified IAM Identity
Center role:
`arn:aws:iam::429496640190:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_4af4e9b42a20d275`.
The role receives no broad AWS permissions; Kubernetes administrator rights
come from the EKS access entry and cluster-scoped
`AmazonEKSClusterAdminPolicy` association. Bootstrap configuration is the
source of truth; review its refreshed plan before changing IAM.

## Security-group attachment and communication

The cluster's `vpc_config` attaches the prepared additional control-plane SG.
EKS also creates and attaches its AWS-managed cluster SG to control-plane
interfaces. For the managed node group, a launch template attaches **only the
prepared worker SG**. It does **not** attach the AWS-managed cluster SG to
workers, and custom SGs in a launch template mean EKS does not automatically
add that managed SG to worker instances. This is deliberate: the prepared
standalone rules provide the required paths without inheriting the managed
cluster SG's broad default egress.

| Flow | Rule path |
|---|---|
| Worker to Kubernetes API | Worker SG egress TCP 443 to the control-plane SG; control-plane SG ingress TCP 443 from the worker SG |
| Control plane to kubelet and HTTPS webhooks | Control-plane SG egress TCP 10250 and 443 to worker SG; worker SG ingress on those ports from control-plane SG |
| Node and pod traffic between workers | Worker SG self-referencing all-protocol ingress and egress |
| Worker DNS | Worker SG egress UDP and TCP 53 to the VPC CIDR |
| Worker outbound registry/AWS HTTPS | Worker SG egress TCP 443 to `0.0.0.0/0`, routed through the existing private-subnet NAT; there is no public worker address or internet ingress |

These are the existing standalone `aws_vpc_security_group_*_rule` resources;
the EKS module does not take ownership of inline SG rules. Before deployment,
confirm the live rules still match this table and that the next plan contains no
unexpected SG rule revocations.

## IAM and workflow permissions

IAM roles and service policies are declared in bootstrap so the GitHub dev apply
role does not create or broadly administer IAM identities:

- Cluster role trusts `eks.amazonaws.com` and receives
  `AmazonEKSClusterPolicy`.
- Worker role trusts `ec2.amazonaws.com` and receives
  `AmazonEKSWorkerNodePolicy` plus `AmazonEC2ContainerRegistryPullOnly`.
- VPC CNI role trusts `pods.eks.amazonaws.com` for this account and this
  cluster only, and receives `AmazonEKS_CNI_Policy`.
- The plan role gets region- and resource-scoped EKS, launch-template, log-group
  and IAM role read access.
- The apply role gets narrowly named EKS cluster/node-group/add-on/access-entry
  actions, launch-template management, log retention and `iam:PassRole` limited
  to those three roles and their respective AWS services. It does not receive
  administrator access.

The EKS service roles and scoped plan/apply policies were created and attached
by a reviewed bootstrap apply on 6 October 2026 (11 resources added, none
changed or destroyed). The plan role's attachment and effective permissions
were then verified with AWS IAM policy simulation. Bootstrap does not need to
be reapplied for this permission repair. Review and apply bootstrap again only
if later changes to these IAM resources are proposed; dev planning reads the
three service roles by name.
See [IAM policy map](IAM-POLICY-MAP.md).

GitHub repository Actions variables required by the plan and apply workflows:

| Variable | Value |
|---|---|
| `EKS_ADMIN_PUBLIC_IPV4_CIDR` | The administrator's **currently verified** public IPv4 `/32`; do not assume the old `195.14.217.35/32` is still current |
| `EKS_ADMIN_IAM_ROLE_ARN` | `arn:aws:iam::429496640190:role/healthops-dev-eks-admin` |

The apply workflow requires the current CIDR to be entered again when a saved
plan creates or changes the EKS cluster. It must exactly match the CIDR in the
plan's repository variable. If the address has changed, update the variable and
generate a new plan; do not apply a plan made with the old address.

## Administrator access

Check the current public address immediately before planning:

```powershell
aws sso login --profile ai-lab-admin
aws sts get-caller-identity --profile ai-lab-admin
$currentIpv4 = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
$currentAdminCidr = "$currentIpv4/32"
$currentAdminCidr
```

Compare that `/32` with `eks_administrator.public_ipv4_cidr` in the ignored
`infrastructure/terraform/environments/dev/terraform.tfvars` and the GitHub
repository variable. Update either value if it differs; never widen it to
`0.0.0.0/0`. For GitHub applies, enter the same current CIDR in the
`confirmed_admin_public_ipv4_cidr` workflow input.

Configure a named AWS CLI role profile once in the current PowerShell session:

```powershell
aws configure set role_arn arn:aws:iam::429496640190:role/healthops-dev-eks-admin --profile healthops-eks-admin
aws configure set source_profile ai-lab-admin --profile healthops-eks-admin
aws configure set role_session_name ikteaja-eks-admin --profile healthops-eks-admin
aws configure set region eu-central-1 --profile healthops-eks-admin
aws sts get-caller-identity --profile healthops-eks-admin
aws eks update-kubeconfig --profile healthops-eks-admin --name ai-platform-dev --region eu-central-1 --alias ai-platform-dev
kubectl config use-context ai-platform-dev
kubectl auth can-i get nodes
kubectl get nodes -o wide
```

The first identity check should show the `ai-lab-admin` SSO role. The second
should show an assumed `healthops-dev-eks-admin` role. `kubectl` authentication
uses the role profile in kubeconfig; neither the SSO administrator nor the
Terraform execution role is granted Kubernetes access directly.

## Lab sizing and limitations

The default node group is one `t3.medium` (`2 vCPU`, `4 GiB`), minimum 1,
desired 1, maximum 2. `eks_cpu_instance_type` is configurable and must be an
x86_64 EKS-supported type in the selected region. The API and mock-model images
have small lab resource requests, but the node also runs system pods. If memory
pressure or `Insufficient memory` events appear, use `t3.large` (8 GiB) and
review cost before applying.

One desired node is a cost-conscious learning setup, **not highly available**.
Both subnets are eligible for node placement, but one node does not provide
cross-AZ capacity or node-failure tolerance; CoreDNS's two default replicas
can share that single node. `max_size = 2` only sets the Auto Scaling group's
upper bound. It does not install a cluster autoscaler or cause pending pods to
add nodes. Karpenter and GPU nodes are later milestones.

## Deployment procedure

Do not run an apply until the administrator CIDR has just been verified, the
bootstrap changes are deployed, and the dev plan has been reviewed.

1. Confirm the current address using the commands above. Update the ignored
   local tfvars and GitHub repository variable if needed.
2. From the repository root, log in to the verified administrator profile,
   review, and apply the bootstrap IAM plan through the existing bootstrap
   process:

   ```powershell
   aws sso login --profile ai-lab-admin
   $env:AWS_PROFILE = "ai-lab-admin"
   terraform -chdir=infrastructure/terraform/bootstrap init -lockfile=readonly
   terraform -chdir=infrastructure/terraform/bootstrap validate
   terraform -chdir=infrastructure/terraform/bootstrap plan -out=bootstrap.tfplan
   terraform -chdir=infrastructure/terraform/bootstrap show bootstrap.tfplan
   ```

   Apply only after confirming it creates the three EKS service roles, their
   scoped managed-policy attachments, and the plan/apply EKS permissions, with
   no unexpected IAM changes:

   ```powershell
   terraform -chdir=infrastructure/terraform/bootstrap apply bootstrap.tfplan
   ```

3. Run a dev plan using the normal Terraform Plan workflow after bootstrap has
   completed. The local equivalent, from the repository root, is:

   ```powershell
   terraform -chdir=infrastructure/terraform/environments/dev init -lockfile=readonly
   terraform -chdir=infrastructure/terraform/environments/dev validate
   terraform -chdir=infrastructure/terraform/environments/dev plan -out=dev.tfplan
   terraform -chdir=infrastructure/terraform/environments/dev show dev.tfplan
   ```

4. Review the exact plan for the `ai-platform-dev` cluster, one named CPU launch
   template and managed node group, control-plane log group, four managed
   add-ons (Pod Identity Agent, VPC CNI, kube-proxy, CoreDNS), and administrator
   access entry/association. It must reuse the existing VPC, subnets, NAT,
   endpoint and SG rules, with no unrelated deletes or replacements.
5. For CI deployment, use the protected manual Apply workflow with the
   successful `main` plan-run ID, type `apply-dev`, and enter the freshly
   verified CIDR in `confirmed_admin_public_ipv4_cidr`. The workflow refuses an
   EKS create/update if the entered CIDR differs from the repository variable.
   For local deployment, apply only the reviewed saved plan after independently
   checking that the CIDR in it is current:

   ```powershell
   terraform -chdir=infrastructure/terraform/environments/dev apply dev.tfplan
   ```

6. Use the administrator role profile above to run the post-deployment checks.
   Do not enable a public application endpoint as part of this milestone.

The version data sources ask AWS for compatible add-on builds, so a plan needs
valid AWS credentials and the bootstrap plan role's newly applied read access.
If a saved plan becomes stale, create and review a fresh plan rather than
applying the stale file.

## Post-deployment acceptance checks

These commands are for after an explicitly approved deployment. They are not
evidence that the resources exist now.

```powershell
aws eks describe-cluster --name ai-platform-dev --region eu-central-1 --profile healthops-eks-admin --query "cluster.status" --output text
aws eks describe-nodegroup --cluster-name ai-platform-dev --nodegroup-name ai-platform-dev-cpu --region eu-central-1 --profile healthops-eks-admin --query "nodegroup.status" --output text
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
aws eks list-addons --cluster-name ai-platform-dev --region eu-central-1 --profile healthops-eks-admin
```

Expect cluster and node group status `ACTIVE`, the expected worker `Ready`, and
the VPC CNI, CoreDNS, kube-proxy and Pod Identity Agent pods healthy. CoreDNS
creation is explicitly ordered after the worker group so it has schedulable
capacity.

To run the existing API and mock-model manifests against the published ECR
images, use an immutable tag or digest from the ECR publishing workflow. This
PowerShell example replaces the local image name in memory; it does not edit
the checked-in manifests:

```powershell
$apiImage = Read-Host "Paste the full ECR API URI with immutable tag or @sha256 digest"
$modelImage = Read-Host "Paste the full ECR mock-model URI with immutable tag or @sha256 digest"
kubectl apply -f .\kubernetes\base\namespace.yaml
kubectl apply -f .\kubernetes\base\api-service.yaml
kubectl apply -f .\kubernetes\base\mock-model-service.yaml
$apiManifest = Get-Content .\kubernetes\base\api-deployment.yaml -Raw
$apiManifest = $apiManifest.Replace("secure-ai-platform-api:0.2.0", $apiImage)
$apiManifest | kubectl apply -f -
$modelManifest = Get-Content .\kubernetes\base\mock-model-deployment.yaml -Raw
$modelManifest = $modelManifest.Replace("secure-ai-platform-mock-model:0.1.0", $modelImage)
$modelManifest | kubectl apply -f -
kubectl rollout status deployment/secure-ai-api -n ai-platform --timeout=5m
kubectl rollout status deployment/mock-model -n ai-platform --timeout=5m
kubectl get pods -n ai-platform -o wide
kubectl port-forward -n ai-platform service/secure-ai-api 8080:8000
```

In another PowerShell window, verify the API health and readiness endpoints and
exercise the API-to-model request:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
Invoke-RestMethod http://127.0.0.1:8080/ready
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8080/ask `
  -ContentType "application/json" `
  -Body '{"question":"How does the HealthOps lab route API traffic to the mock model?"}'
```

The checked-in API manifest sets `MODEL_BASE_URL=http://mock-model:8002`, the
same-namespace ClusterIP Service. That confirms DNS and internal service
connectivity in the `/ask` request. The API and model deployments are application
acceptance tests; Terraform does not install them.

## Troubleshooting

### Worker nodes do not join

- Confirm cluster and node group are `ACTIVE`, the nodes use the two existing
  private subnets, and the node group has no public IP or SSH configuration.
- Verify the worker launch template has only the prepared worker SG, and the
  cluster has the prepared control-plane SG in addition to its AWS-managed SG.
- Check both sides of TCP 443 (worker to API), TCP 10250 and 443 (control plane
  to worker), worker self-referencing node traffic, DNS TCP/UDP 53 and HTTPS
  egress. Do not add inline rules to the `aws_security_group` resources.
- Confirm private routes reach NAT, the S3 gateway endpoint is attached, and
  outbound DNS/HTTPS works. Inspect node-group health issues and CloudWatch
  control-plane logs before changing security rules.

### `kubectl` says unauthorized or forbidden

- Run `aws sts get-caller-identity --profile healthops-eks-admin`; it must show
  the assumed dedicated role, not only `ai-lab-admin`.
- Verify the role's trust and `AmazonEKSClusterAdminPolicy` access-policy
  association for this cluster, then refresh kubeconfig.
- Confirm the public address in the cluster allowlist still equals the
  administrator's current `/32`. Update the GitHub variable and create a new
  plan before applying any CIDR change.

### Pods show `ImagePullBackOff`

- Check the image URI/tag/digest and repository names:
  `healthops-dev/api` and `healthops-dev/mock-model`.
- Confirm the node role has `AmazonEC2ContainerRegistryPullOnly`; never grant
  image-publisher credentials to pods or nodes.
- Inspect `kubectl describe pod` events for ECR authentication, DNS, HTTPS or
  S3 layer errors. Check the private NAT route, ECR API/registry reachability,
  S3 gateway endpoint and worker DNS egress.
- Use immutable ECR tags/digests that still exist; do not change a running
  Deployment to a local `kind` image name.

## Cleanup order and retained resources

Remove application Deployments/Services first. Then use a reviewed Terraform
plan to remove the EKS add-ons/access entry, managed node group and launch
template before removing the cluster. Delete the EKS control-plane log group
only when its logs are no longer needed. Remove the bootstrap-managed IAM roles
only after the cluster is gone and their policies are detached; their
`prevent_destroy` lifecycle guards require an intentional bootstrap change.

The EKS service-linked role may remain after cluster deletion. Existing VPC,
subnets, NAT, routes, endpoint and prepared security groups are independent
network resources and must not be removed as part of an EKS-only cleanup.
ECR repositories/images and the ECR encryption key also remain. Review each
plan; do not use a broad environment destroy for this milestone.
