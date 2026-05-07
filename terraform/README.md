# Terraform — reference IaC

> **This is reference infrastructure-as-code.** It is **not** applied by `make demo`. The demo runs entirely on local `kind` clusters; this directory shows what the production-shaped equivalent of one edge cluster looks like.

## What's here

- [`main.tf`](main.tf) — VPC + EKS cluster sized for one edge.
- [`variables.tf`](variables.tf) — region, cluster name, sizing.

## What would be added for full production

- Per-cloud edge modules: `terraform/aws/`, `terraform/azure/`, `terraform/gcp/`.
- Argo CD installed via Terraform on each cluster, pointed at this repo for GitOps sync of the Kustomize overlays.
- IRSA / Workload Identity / GCP WI Federation for the Thanos sidecar's S3/GCS/Blob access.
- A **central** module: separate cluster (different AWS account / Azure subscription / GCP project) with stricter IAM, hosting Thanos Query, Grafana, and the Compactor + Store Gateway tier.
- Private connectivity between edge and central — Transit Gateway, peering, or Cloud WAN.
- DNS zone(s), TLS certs (cert-manager + ACME), OIDC for Grafana.
- A remote state backend with locking (S3 + DynamoDB stub commented in `main.tf`).

## Why include it at all

So the topology in `kubernetes/overlays/aws/` has a real-world counterpart visible. Recruiters reading this repo can see the demo on local kind, then this file, and connect "this is what one edge would actually be" without any handwaving.

## Running it (if you really want to)

You'll spend real money. Only do this if you understand AWS billing.

```bash
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --name omni-obs-aws --region us-east-1
kubectl apply -k ../kubernetes/overlays/aws
terraform destroy   # don't forget!
```
