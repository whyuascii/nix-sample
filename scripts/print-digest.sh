#!/usr/bin/env bash
#
# Print the digest of a remote OCI image
#
# Usage:
#   ./scripts/print-digest.sh ghcr.io/your-org/nix-sample-web:latest
#
# This is useful for:
# - Verifying that an image was pushed correctly
# - Getting the exact digest for deployment (deploy by digest, not tag)
# - Comparing local and remote images

set -euo pipefail

IMAGE=${1:?Usage: $0 <image-url>}

echo "🔍 Fetching digest for: $IMAGE"

# Use skopeo to inspect the remote image and extract the digest
# The digest is a SHA256 hash that uniquely identifies the image
DIGEST=$(skopeo inspect docker://"$IMAGE" | jq -r .Digest)

echo "Digest: $DIGEST"
