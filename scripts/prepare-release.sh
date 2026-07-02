#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: prepare-release.sh VERSION (e.g. 1.0.0)}"
IMAGE="docker.io/mrjoees/nethack:${VERSION}"

echo "Preparing release ${VERSION} (image: ${IMAGE})"

if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

"${SED_INPLACE[@]}" "s/^  version: .*/  version: \"${VERSION}\"/" zarf.yaml
"${SED_INPLACE[@]}" "s|      - docker.io/mrjoees/nethack:.*|      - ${IMAGE}|" zarf.yaml

for values_file in chart/values.yaml values/upstream-values.yaml; do
  "${SED_INPLACE[@]}" "s|  tag: .*|  tag: \"${VERSION}\"|" "${values_file}"
done

echo "Updated zarf.yaml and Helm values for version ${VERSION}"
