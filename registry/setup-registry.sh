#!/usr/bin/env bash
set -euo pipefail

# ---------------- CONFIG ----------------
REGISTRY_HOST="${REGISTRY_HOST:-192.168.56.25}"
REGISTRY_PORT="${REGISTRY_PORT:-30500}"
REGISTRY_NAMESPACE="registry"
REGISTRY_USER="${REGISTRY_USER:-cruise}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-ChangeMeNow!}"
TLS_DAYS="${TLS_DAYS:-365}"

# ---------------- CHECKS ----------------
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl required"; exit 1; }
command -v htpasswd >/dev/null 2>&1 || { echo "apache2-utils required"; exit 1; }

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# ---------------- TLS ----------------
cat > "$tmp_dir/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${REGISTRY_HOST}

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = ${REGISTRY_HOST}
EOF

openssl req -x509 -nodes -days "${TLS_DAYS}" -newkey rsa:2048 \
  -keyout "$tmp_dir/tls.key" \
  -out "$tmp_dir/tls.crt" \
  -config "$tmp_dir/openssl.cnf"

# ---------------- AUTH ----------------
htpasswd -Bbn "${REGISTRY_USER}" "${REGISTRY_PASSWORD}" > "$tmp_dir/htpasswd"

# ---------------- APPLY YAML (CURRENT DIR FIX) ----------------
kubectl apply -f registry-namespace.yaml
kubectl apply -f registry-pv.yaml
kubectl apply -f registry-pvc.yaml
kubectl apply -f registry.yaml
kubectl apply -f registry-service.yaml

# ---------------- SECRETS ----------------
kubectl -n registry create secret generic registry-auth \
  --from-file=htpasswd="$tmp_dir/htpasswd" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n registry create secret tls registry-tls \
  --cert="$tmp_dir/tls.crt" \
  --key="$tmp_dir/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------- PULL SECRET DEV ----------------
kubectl -n dev create secret docker-registry registry-pull-secret \
  --docker-server="${REGISTRY_HOST}:${REGISTRY_PORT}" \
  --docker-username="${REGISTRY_USER}" \
  --docker-password="${REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Registry deployed"
echo "➡️ ${REGISTRY_HOST}:${REGISTRY_PORT}"