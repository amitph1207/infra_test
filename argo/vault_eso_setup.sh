#!/usr/bin/env bash
# Vault + ESO: store secrets in Vault, sync to K8s secrets via External Secrets Operator.
# Usage: ./setup.sh [namespace]
# Prereq: existing K8s secret "hbn-user-password" with key "password" (or set SEED_PASSWORD env)

set -euo pipefail
NAMESPACE="${1:-default}"

# --- 1. Install Vault (dev mode) ---
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=false" \
  -n "$NAMESPACE" \
  --create-namespace

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n "$NAMESPACE" --timeout=120s

# --- 2. Seed Vault with secret (from existing K8s secret or SEED_PASSWORD) ---
if kubectl get secret hbn-user-password -n "$NAMESPACE" &>/dev/null; then
  PASSWORD=$(kubectl get secret hbn-user-password -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
elif [[ -n "${SEED_PASSWORD:-}" ]]; then
  PASSWORD="$SEED_PASSWORD"
else
  echo "No hbn-user-password secret or SEED_PASSWORD; using placeholder. Create the secret in Vault manually if needed."
  PASSWORD="change-me"
fi
kubectl exec vault-0 -n "$NAMESPACE" -- vault kv put secret/dpf/hbn-user-password password="$PASSWORD"

# --- 3. Configure Vault Kubernetes auth for ESO ---
kubectl exec vault-0 -n "$NAMESPACE" -- sh -c '
  vault auth enable kubernetes 2>/dev/null || true
  vault write auth/kubernetes/config \
    kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
  echo "path \"secret/data/dpf/*\" { capabilities = [\"read\"] }" | vault policy write external-secrets -
  vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces='"$NAMESPACE"' \
    policies=external-secrets \
    ttl=24h
'

# --- 4. Install External Secrets Operator ---
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n "$NAMESPACE" \
  --create-namespace

kubectl wait --for=condition=available deployment -l app.kubernetes.io/name=external-secrets -n "$NAMESPACE" --timeout=120s
# Wait for CRDs to be established
kubectl wait --for=condition=established crd/secretstores.external-secrets.io --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=established crd/externalsecrets.external-secrets.io --timeout=60s 2>/dev/null || true

# --- 5. SecretStore (Vault backend) ---
# ESO v0.10+ uses v1 API; if you have older ESO, change to external-secrets.io/v1beta1
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: $NAMESPACE
spec:
  provider:
    vault:
      server: "http://vault.$NAMESPACE.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets
            namespace: $NAMESPACE
EOF

# --- 6. ExternalSecret: Vault -> K8s secret ---
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hbn-user-password-sync
  namespace: $NAMESPACE
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: hbn-user-password
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: dpf/hbn-user-password
      property: password
EOF

echo "Waiting for ExternalSecret to sync..."
sleep 10
kubectl get externalsecret -n "$NAMESPACE"
kubectl get secret hbn-user-password -n "$NAMESPACE" -o yaml 2>/dev/null && echo "Secret synced successfully."
