# NetHack on UDS with Zarf

Package [NetHack](https://github.com/NetHack/NetHack) as a Zarf bundle for deployment on [UDS Core](https://docs.defenseunicorns.com/core/). The container builds NetHack from upstream source and exposes it in the browser through [ttyd](https://github.com/tsl0922/ttyd).

Once deployed on a UDS cluster, the game is available at:

`https://nethack.<your-domain>`

For a default local UDS dev cluster that is typically `https://nethack.uds.dev`.

## What is in this repo

| Path | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build: compile NetHack 5.0, serve with ttyd |
| `entrypoint.sh` | Starts ttyd on port 7681 with browser-friendly client options |
| `run-nethack.sh` | Waits for terminal sizing before launching NetHack |
| `config/sysconf` | Container sysconf required by NetHack's SYSCF build option |
| `config/nethackrc` | Default player options (autopickup, travel keybind) |
| `chart/` | Helm chart (Deployment, Service, UDS `Package` CR) |
| `values/upstream-values.yaml` | Helm values used by Zarf |
| `zarf.yaml` | Zarf package definition |

Container image registry: [Docker Hub – mrjoees/nethack](https://hub.docker.com/r/mrjoees/nethack)

Current image tag: `1.0.4`

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Zarf](https://docs.zarf.dev/) (`v0.79+` tested)
- [UDS CLI](https://docs.defenseunicorns.com/core/) (`uds`) for UDS cluster workflows
- A Kubernetes cluster with UDS Core installed (or a local [k3d-core-dev-slim](https://github.com/defenseunicorns/uds-core) cluster)

## Quick local smoke test (no cluster)

Verify the image before packaging or deploying:

```bash
docker build -t nethack-local .
docker run --rm -p 7681:7681 nethack-local
```

Open **http://localhost:7681**. You should see the NetHack title screen.

## Build and publish the container image

The image is published under the [mrjoees](https://app.docker.com/accounts/mrjoees) Docker Hub account.

```bash
# Build for your machine (amd64 or arm64)
docker build -t docker.io/mrjoees/nethack:1.0.4 .

# Push to Docker Hub (optional — not required for local Zarf deploy)
docker login
docker push docker.io/mrjoees/nethack:1.0.4
```

Or use the helper script:

```bash
IMAGE=docker.io/mrjoees/nethack:1.0.4 ./scripts/build-image.sh
PUSH=true IMAGE=docker.io/mrjoees/nethack:1.0.4 ./scripts/build-image.sh
```

## Test locally without publishing to Docker Hub

Zarf bundles the image from your **local Docker daemon** when you create the package. You do not need to push to Docker Hub for cluster testing.

```bash
docker build -t docker.io/mrjoees/nethack:1.0.4 .
zarf package create . --confirm
uds zarf package deploy zarf-package-nethack-*.tar.zst --confirm
```

When `zarf package create` warns that it cannot pull from Docker Hub (`401 unauthorized`), that is expected if the image is not published yet. Zarf falls back to your local daemon:

```text
WRN unable to find image, attempting pull from docker daemon as fallback
INF pulling image from docker daemon name=docker.io/mrjoees/nethack:1.0.4
```

**Important:** bump the image tag in `zarf.yaml` and `values/upstream-values.yaml` whenever you rebuild, or Zarf may reuse a cached image from its in-cluster registry.

## Deploy to a UDS cluster

```bash
# With UDS CLI (recommended on UDS Core clusters)
uds zarf package deploy zarf-package-nethack-*.tar.zst --confirm

# Or with Zarf directly
zarf package deploy zarf-package-nethack-*.tar.zst --confirm
```

The UDS Operator reads the `Package` CR and configures:

- Istio tenant gateway ingress at `nethack.<domain>`
- Network policies for the namespace

### Local access without ingress

If you deploy to a plain Zarf/K3s cluster without UDS ingress:

```bash
zarf connect nethack
```

## Configuration

### Change the public hostname

Edit `values/upstream-values.yaml`:

```yaml
uds:
  host: nethack    # becomes nethack.<cluster-domain>
  gateway: tenant
```

The cluster domain comes from your UDS configuration (commonly `uds.dev` in local dev).

### Player defaults (`config/nethackrc`)

Shipped defaults include:

- **Autopickup** for gold, scrolls, potions, wands, rings, amulets, spellbooks, and tools
- **`o` bound to travel** — press `o`, pick a map square, and path there automatically

Vanilla NetHack 5.0 does not include autoexplore (that is a variant feature). Travel is the closest built-in equivalent.

Edit `config/nethackrc` and rebuild the image to change defaults. The file is installed at `/var/nethack/.nethackrc` inside the container.

### Pin a different NetHack release

Build with a different upstream branch or tag:

```bash
docker build \
  --build-arg NETHACK_REF=NetHack-5.0 \
  -t docker.io/mrjoees/nethack:1.0.4 .
```

Update `zarf.yaml` and chart image tags when you cut a new package version.

### Package and image version

Bump these together when releasing:

- `metadata.version` in `zarf.yaml` (Zarf package version)
- Image tag in `zarf.yaml`, `values/upstream-values.yaml`, and `chart/values.yaml`

Or tag a release and let CI do it (see below).

## GitHub Actions releases

Pushing a version tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which:

1. Sets the package and image version from the tag (e.g. `v1.0.4` → `1.0.4`)
2. Builds the Docker image
3. Creates the Zarf package tarball
4. Pushes `docker.io/mrjoees/nethack:<version>` and `:latest` to Docker Hub
5. Publishes a GitHub Release with the Zarf package attached

### Required repository secrets

Configure these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|--------|
| `DOCKERHUB_USERNAME` | `mrjoees` |
| `DOCKERHUB_TOKEN` | Docker Hub access token ([create one here](https://hub.docker.com/settings/security)) |

`GITHUB_TOKEN` is provided automatically for the release upload.

### Cut a release

```bash
git tag v1.0.4
git push origin v1.0.4
```

Pull requests and pushes to `main` run [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which builds the Docker image without publishing.

## How it works

1. **Build** — NetHack is cloned from GitHub (`NetHack-5.0` by default), configured with the `linux-minimal` hints file, and installed under `/opt/nethack`.
2. **Configure** — A container-specific `sysconf` satisfies NetHack's SYSCF requirement; a default `.nethackrc` sets player options.
3. **Serve** — `ttyd` exposes an interactive terminal in the browser. `run-nethack.sh` waits for the browser to report terminal dimensions before starting the game.
4. **Deploy** — Zarf ships the image and Helm manifests into the cluster namespace `nethack`. The pod runs as uid/gid `1000` to match UDS defaults.
5. **Expose** — The UDS `Package` CR registers the service on the tenant gateway so users reach it at `https://nethack.<domain>`.

## Troubleshooting

**Docker build fails at compile time**

Ensure build dependencies are available in the builder stage (see `Dockerfile`). NetHack must be configured with `setup.sh` before `make fetch-lua`.

**Image pull errors on deploy**

Confirm the image exists on Docker Hub or was included in the Zarf tarball. After air-gap deploy, images are served from the in-cluster Zarf registry, not Docker Hub.

**`Unable to open SYSCF_FILE` or reconnect loop on startup**

NetHack 5.0 requires a readable `sysconf` when built with SYSCF. This repo ships `config/sysconf` into the image. Rebuild and redeploy with a new image tag if you see this on an older deployment.

**`Warning: cannot write scoreboard file 'record'` or immediate crash (signal/backtrace)**

UDS runs pods as uid `1000`. The image user and game data files must match. The Dockerfile creates the `nethack` user at uid/gid `1000`, and the Helm chart sets `runAsUser` / `fsGroup` accordingly.

**Game map is tiny in the corner of the browser**

NetHack reads terminal size at startup. `run-nethack.sh` waits for ttyd to apply the browser's fitted dimensions. Rebuild with the current image if you still see a postage-stamp map.

**Zarf reuses an old image after rebuild**

Bump the image tag (e.g. `1.0.4` → `1.0.5`) in `zarf.yaml` and values files before `zarf package create`, or the in-cluster Zarf registry may serve a cached layer.

**Blank browser page**

ttyd listens on port `7681`. Verify the UDS `Package` CR port matches `service.port` in the Helm values.

## License

NetHack is distributed under its own license. See the [upstream repository](https://github.com/NetHack/NetHack). Packaging files in this repository are provided as-is for learning and deployment.
