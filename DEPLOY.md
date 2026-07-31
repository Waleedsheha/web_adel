# Deploy on Coolify

The repo *is* the web root — it holds the compiled Flutter web output, not Dart
source. The image just serves it with nginx.

## Coolify setup

1. **+ New Resource → Application → Public/Private Repository**, point at this repo,
   branch `main`.
2. **Build Pack:** `Dockerfile`. Base Directory `/`, Dockerfile Location `/Dockerfile`.
3. **Port:** `80`.
4. **Domain:** set the FQDN (e.g. `https://adel.example.com`). Coolify's proxy
   terminates TLS; nginx in the container stays plain HTTP on 80.
5. **Health Check:** path `/healthz`, port `80`.
6. Deploy.

No environment variables — the app is fully static, everything is baked in at
build time.

## Redeploying after a new Flutter build

```bash
flutter build web --release   # in the Flutter project
# copy build/web/* over this repo
git add -A && git commit -m "build: web release" && git push
```

Coolify rebuilds on push if **Automatic Deployment** is on.

## What the config does

- **gzip_static** — the build stage pre-gzips every `.js/.wasm/.json/.ttf/...`
  at level 9, so nginx ships `main.dart.js` at ~600 KB instead of 2.5 MB and the
  CanvasKit wasm at a fraction of 37 MB, with no per-request CPU cost.
- **Cache policy** — Flutter emits stable filenames, so anything whose *content*
  changes per build (`index.html`, `flutter_bootstrap.js`, `main.dart.js`,
  `version.json`, `manifest.json`) is `no-cache` + ETag: a redeploy is picked up
  immediately, unchanged files still return 304. `/canvaskit/` is cached 30 days
  (only moves on an SDK bump), `/assets|icons|splash/` 1 day.
- **SPA fallback** — `try_files ... /index.html` so deep links work.
- **`.symbols` / `.js.map` excluded** from the image via `.dockerignore` — debug
  artifacts the running app never fetches.

## Not enabled on purpose

`Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy:
require-corp` would let Flutter use the multi-threaded `skwasm_heavy` renderer,
but cross-origin isolation breaks any third-party image, font, or iframe that
doesn't send CORP headers. Add them to `nginx.conf` only if this app loads
nothing from other origins.
