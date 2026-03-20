#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./bin/deploy.sh [options]

Bootstraps a KubeAid cluster using kubeaid-cli and runs a small set of post-deploy checks.

Options:
  --config-dir PATH   Directory containing generated config files (default: outputs/configs)
  --kubeconfig PATH   Expected kubeconfig path after bootstrap (default: outputs/kubeconfigs/main.yaml)
  --skip-checks       Skip post-deploy kubectl checks
  -h, --help          Show this help message
USAGE
}

CONFIG_DIR="outputs/configs"
KUBECONFIG_PATH="outputs/kubeconfigs/main.yaml"
SKIP_CHECKS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir)
      CONFIG_DIR="$2"
      shift 2
      ;;
    --kubeconfig)
      KUBECONFIG_PATH="$2"
      shift 2
      ;;
    --skip-checks)
      SKIP_CHECKS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command kubeaid-cli
require_command kubectl
if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: docker was not found in PATH. This is fine for some bare-metal flows, but ClusterAPI and local K3D deployments need Docker." >&2
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "Configuration directory not found: $CONFIG_DIR" >&2
  echo "Generate your config first, then retry deployment." >&2
  exit 1
fi

echo "==> Starting KubeAid deployment"
echo "    config dir : $CONFIG_DIR"
echo "    kubeconfig : $KUBECONFIG_PATH"

kubeaid-cli cluster bootstrap

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "Expected kubeconfig was not created: $KUBECONFIG_PATH" >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "==> Deployment completed"
echo "    exported KUBECONFIG=$KUBECONFIG"

if [[ "$SKIP_CHECKS" == "true" ]]; then
  echo "==> Skipping post-deploy checks"
  exit 0
fi

echo "==> Running post-deploy checks"
kubectl cluster-info
kubectl get nodes
kubectl get applications -n argocd
