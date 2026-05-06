#!/bin/bash
# Create 3 local Kubernetes clusters simulating AWS, Azure, GCP

set -e

echo "🚀 Creating 3 simulated cloud clusters..."

# AWS-simulated cluster config
cat > /tmp/cluster-aws.yaml << 'KIND'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster-aws
nodes:
- role: control-plane
  labels:
    cloud-provider: aws
    region: us-east-1
- role: worker
  labels:
    cloud-provider: aws
    region: us-east-1
- role: worker
  labels:
    cloud-provider: aws
    region: us-east-1
KIND

# Azure-simulated cluster config
cat > /tmp/cluster-azure.yaml << 'KIND'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster-azure
nodes:
- role: control-plane
  labels:
    cloud-provider: azure
    region: eastus
- role: worker
  labels:
    cloud-provider: azure
    region: eastus
KIND

# GCP-simulated cluster config
cat > /tmp/cluster-gcp.yaml << 'KIND'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster-gcp
nodes:
- role: control-plane
  labels:
    cloud-provider: gcp
    region: us-central1
- role: worker
  labels:
    cloud-provider: gcp
    region: us-central1
KIND

# Create the clusters
kind create cluster --config /tmp/cluster-aws.yaml
kind create cluster --config /tmp/cluster-azure.yaml
kind create cluster --config /tmp/cluster-gcp.yaml

echo "✅ All 3 clusters created!"
echo ""
echo "📋 List all contexts:"
kubectl config get-contexts

echo ""
echo "🔄 Switch between clusters:"
echo "  kubectl config use-context kind-cluster-aws"
echo "  kubectl config use-context kind-cluster-azure"
echo "  kubectl config use-context kind-cluster-gcp"
