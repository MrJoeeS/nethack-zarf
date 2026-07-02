#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-docker.io/mrjoees/nethack:1.0.0}"
NETHACK_REF="${NETHACK_REF:-NetHack-5.0}"
PUSH="${PUSH:-false}"

echo "Building ${IMAGE} (NetHack ref: ${NETHACK_REF})..."
docker build \
  --build-arg "NETHACK_REF=${NETHACK_REF}" \
  -t "${IMAGE}" \
  .

if [[ "${PUSH}" == "true" ]]; then
  echo "Pushing ${IMAGE} to Docker Hub..."
  docker push "${IMAGE}"
fi

echo "Done."
