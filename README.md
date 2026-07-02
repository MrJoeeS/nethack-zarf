# NetHack on UDS with Zarf

Build [NetHack 5.0](https://github.com/NetHack/NetHack) from source, serve it in the browser via [ttyd](https://github.com/tsl0922/ttyd), and deploy to [UDS Core](https://docs.defenseunicorns.com/core/) with [Zarf](https://docs.zarf.dev/).

**URL after deploy:** `https://nethack.<domain>` (e.g. `https://nethack.uds.dev`)

**Image:** [docker.io/mrjoees/nethack](https://hub.docker.com/r/mrjoees/nethack) (`1.0.4`)

## Prerequisites

Docker, Zarf (`v0.79+`), UDS CLI, and a UDS Core cluster.

## Quick test

```bash
docker build -t nethack-local .
docker run --rm -p 7681:7681 nethack-local
# http://localhost:7681
```

## Build and deploy

No Docker Hub push required — Zarf bundles the local image.

```bash
docker build -t docker.io/mrjoees/nethack:1.0.4 .
zarf package create . --confirm
uds zarf package deploy zarf-package-nethack-*.tar.zst --confirm
```

Bump the image tag in `zarf.yaml` and `values/upstream-values.yaml` on every rebuild, or Zarf may reuse a cached image. A Docker Hub `401` during `zarf package create` is normal; Zarf falls back to your local daemon.

Without UDS ingress: `zarf connect nethack`

## Configuration

| Change | File |
|--------|------|
| Hostname | `values/upstream-values.yaml` → `uds.host` |
| Player options (autopickup, keybinds) | `config/nethackrc` |
| NetHack version | `NETHACK_REF` build-arg in `Dockerfile` |
| Package/image version | `zarf.yaml` + Helm values |

Default `nethackrc`: autopickup on, `o` bound to travel. Vanilla 5.0 has no autoexplore.

## Layout

| Path | Purpose |
|------|---------|
| `Dockerfile` | Build NetHack + ttyd image |
| `entrypoint.sh`, `run-nethack.sh` | Start ttyd, wait for terminal size, launch game |
| `config/sysconf`, `config/nethackrc` | Runtime config |
| `chart/`, `zarf.yaml` | Helm chart and Zarf package |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Unable to open SYSCF_FILE` | Rebuild with current image (`config/sysconf`) |
| Crash on connect / can't write `record` | Image must run as uid `1000` (current Dockerfile + chart) |
| Tiny map in browser | Rebuild with `run-nethack.sh` |
| Stale image after rebuild | Bump image tag before `zarf package create` |
| Blank page | Check UDS `Package` port matches `service.port` (`7681`) |

## License

NetHack has its own license. See [NetHack/NetHack](https://github.com/NetHack/NetHack).
