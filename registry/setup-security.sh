#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Creating registry..."

kubectl apply -f registry/registry-namespace.yaml

echo "📦 Creating storage..."
kubectl apply -f registry/registry-pv.yaml
kubectl apply -f registry/registry-pvc.yaml

echo "🚀 Deploying registry..."
kubectl apply -f registry/registry.yaml
kubectl apply -f registry/registry-service.yaml

echo "📁 Creating storage folder on nodes..."
for node in master worker1 worker2; do
  echo "-> $node"
  ssh vagrant@$node "sudo mkdir -p /data/registry && sudo chmod 777 /data/registry" || true
done

echo "⏳ Waiting pod..."
kubectl -n registry rollout status deployment/registry

echo "✅ Registry ready!"
echo "🌐 URL: http://192.168.56.25:30500/v2/_catalog"