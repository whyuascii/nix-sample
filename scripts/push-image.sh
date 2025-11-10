#!/usr/bin/env bash
#
# Push OCI images to a registry using skopeo (NO Docker required!)
#
# Usage:
#   REGISTRY=ghcr.io/your-org ./scripts/push-image.sh web
#   REGISTRY=ghcr.io/your-org TAG=v1.2.3 ./scripts/push-image.sh api
#
# Environment Variables:
#   APP              - App name (web|api) - passed as first argument
#   REGISTRY         - Container registry URL (default: ghcr.io/your-org)
#   TAG              - Image tag (default: latest)
#   REGISTRY_USER    - Registry username (optional, for authentication)
#   REGISTRY_PASSWORD - Registry password (optional, for authentication)
#
# This script uses skopeo to push images directly from the Nix-built tar archive
# to a remote registry without needing Docker installed.
#
# How it works:
# 1. nix build creates a docker-archive (OCI image in tar format) as 'result'
# 2. skopeo copies the tar directly to the remote registry
# 3. skopeo fetches and prints the image digest for deployment verification

set -euo pipefail

# Parse arguments
APP=${1:?Usage: $0 <app-name>}
REGISTRY=${REGISTRY:-"ghcr.io/your-org"}
TAG=${TAG:-"latest"}
IMAGE="$REGISTRY/nix-sample-$APP:$TAG"

echo "📦 Pushing image for app: $APP"
echo "🎯 Target: $IMAGE"

# Authenticate if credentials are provided
# In CI, these would come from secrets (e.g., GITHUB_TOKEN)
if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
  echo "🔐 Authenticating with registry..."
  echo "$REGISTRY_PASSWORD" | skopeo login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
fi

# Verify the Nix build result exists
[[ -f result ]] || {
  echo "❌ Error: 'result' file not found"
  echo "Run 'nix build .#image-$APP' first"
  exit 1
}

# Copy the OCI image from tar to registry
# This is where the magic happens - no Docker daemon needed!
echo "🚀 Pushing image to registry..."
skopeo copy \
  --dest-compress \
  docker-archive:result \
  docker://"$IMAGE"

echo "✅ Image pushed successfully!"

# Fetch and print the digest
# This digest can be used for deployment to ensure you deploy the exact image
echo "📋 Fetching image digest..."
DIGEST=$(skopeo inspect docker://"$IMAGE" | jq -r .Digest)
echo "🔍 Digest: $DIGEST"

# Output just the digest (used by CI/deployment tools)
echo "$DIGEST"
