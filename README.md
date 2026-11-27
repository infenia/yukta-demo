# Yukta demo

A try-it-now deployment of [Yukta](https://github.com/infenia/yukta): no login, the standalone examples already loaded.

- The released server image runs on loopback with two keys made fresh at every start: an ADMIN key that only the seed step
  uses, and an OPERATOR key that nginx adds to every request.
- At start, `examples/run-all.sh 1` from the same release applies the standalone examples and leaves a few runs in the history.
- Visitors can start, approve, pause and stop runs and answer inputs. They cannot create, edit or delete sessions, run draft
  workflows or read `/api/config` (all ADMIN-only). `/mcp`, `/hooks` and the actuator (except health) are not exposed.
- Everything is in memory: a restart (the Render free plan sleeps when idle) resets the demo.

## Deploy on Render

New > Blueprint, pick this repository (`render.yaml`). Nothing to configure.

## Run locally

```bash
docker build -t yukta-demo . && docker run --rm -p 10000:10000 yukta-demo   # http://localhost:10000
```

## Upgrade

Change `YUKTA_VERSION` in the `Dockerfile` (the image tag and the examples tarball use it).

Settings you can override with environment variables: `YUKTA_PLUGINS_ENABLED`, `YUKTA_PROCESS_ALLOWED_COMMANDS`, `ADMIN_KEY`,
`OPERATOR_KEY`.
