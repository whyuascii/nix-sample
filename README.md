# NIX and NIX-OS


# Nix + Turborepo (TypeScript) Handbook

A practical, copy‑pasteable guide to wire up a TypeScript monorepo (Turborepo) with Nix for:

* Reproducible dev environments (no "works on my machine")
* Building OCI/Docker images **with Nix** (both with and **without** Docker)
* CI setup in GitHub Actions (build-on-change + push to registry)

> Scope: Pure TypeScript/Node workspace. If you later add other languages, you can extend this pattern per‑app.

---

## 0) Repo Layout (suggested)

```
.
├─ apps/
│  ├─ web/                  # Next.js or Vite app
│  └─ api/                  # Node API (Express/Fastify)
├─ packages/
│  ├─ ui/                   # shared React components
│  └─ config/               # eslint, tsconfig, etc.
├─ turbo.json
├─ package.json             # workspaces + turbo devDep
├─ flake.nix                # Nix: dev shells + image builders
├─ .envrc                   # direnv integration (optional but recommended)
└─ scripts/
   ├─ push-image.sh         # OCI push helper (no Docker required)
   └─ print-digest.sh       # Utility to fetch remote digest
```

---

## 1) Turborepo plumbing

**package.json (root)**

```json
{
  "name": "ts-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "devDependencies": {
    "turbo": "^2.1.0"
  },
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "image": "turbo run image"
  }
}
```

**turbo.json (root)**

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "dev":    { "cache": false, "persistent": true },
    "lint":   { "outputs": [] },
    "test":   { "outputs": ["coverage/**"] },
    "build":  { "dependsOn": ["^build"], "outputs": ["dist/**", ".next/**"] },
    "image":  { "dependsOn": ["build"], "outputs": [".image-digest"] }
  },
  "globalDependencies": [
    "**/package.json",
    "**/pnpm-lock.yaml",
    "**/yarn.lock",
    "**/package-lock.json"
  ],
  "globalEnv": ["NODE_ENV", "APP_ENV"]
}
```

> Tip: If you use **pnpm**, prefer it across the repo for deterministic/fast installs.

**apps/web/package.json**

```json
{
  "name": "web",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "test": "vitest",
    "lint": "eslint .",
    "image": "nix build ../..#image-web && ../../scripts/push-image.sh web > .image-digest"
  }
}
```

**apps/api/package.json**

```json
{
  "name": "api",
  "private": true,
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc -p tsconfig.json",
    "test": "vitest",
    "lint": "eslint .",
    "image": "nix build ../..#image-api && ../../scripts/push-image.sh api > .image-digest"
  }
}
```

---

## 2) Nix: dev shells + image builds (Docker & No‑Docker)

This `flake.nix` provides:

* `devShells.dev-web` and `devShells.dev-api` with Node + toolchain
* Two image builders: `packages.image-web` and `packages.image-api`
* Images are assembled by Nix (deterministic)

> You can use these images **without Docker** (via skopeo) or with Docker (`docker load`).

**flake.nix**

```nix
{
  description = "Turborepo TS monorepo: Nix dev shells + OCI images";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url      = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, flake-utils, devenv, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib  = nixpkgs.lib;

        node = pkgs.nodejs_22;  # single Node version for entire repo
        nodeTools = [ node pkgs.corepack pkgs.yarn pkgs.pnpm pkgs.jq pkgs.git ];

        # Resolve absolute repo root so devenv writes state into the checkout
        repoRoot = let pwd = builtins.getEnv "PWD"; in
          if (pwd != "" && lib.hasPrefix "/" pwd) then pwd
          else builtins.throw "Run with --impure or via direnv: `use flake . --impure`";

        # --- Copy app sources into the image context ---
        srcWeb = pkgs.runCommand "src-web" {} ''
          mkdir -p $out
          cp -R ${self}/apps/web/* $out/
        '';
        srcApi = pkgs.runCommand "src-api" {} ''
          mkdir -p $out
          cp -R ${self}/apps/api/* $out/
        '';

        # --- OCI images built by Nix ---
        imageWeb = pkgs.dockerTools.buildImage {
          name = "turborepo-web"; tag = "latest";
          contents = [ node ];
          extraCommands = ''
            mkdir -p app
            cp -R ${srcWeb}/* app/
          '';
          config = {
            WorkingDir = "/app";
            Entrypoint = [ "bash" "-lc" ];
            # For Next.js standalone: swap with "node .next/standalone/server.js"
            Cmd = [ "pnpm install --frozen-lockfile && pnpm start" ];
            Env = [ "NODE_ENV=production" ];
            ExposedPorts = { "3000/tcp" = {}; };
          };
        };

        imageApi = pkgs.dockerTools.buildImage {
          name = "turborepo-api"; tag = "latest";
          contents = [ node ];
          extraCommands = ''
            mkdir -p app
            cp -R ${srcApi}/* app/
          '';
          config = {
            WorkingDir = "/app";
            Entrypoint = [ "bash" "-lc" ];
            Cmd = [ "pnpm install --frozen-lockfile && node dist/index.js" ];
            Env = [ "NODE_ENV=production" ];
            ExposedPorts = { "3001/tcp" = {}; };
          };
        };
      in {
        # --- Dev shells ---
        devShells.dev-web = devenv.lib.mkShell {
          inherit pkgs;
          modules = [
            ({ pkgs, ... }: {
              devenv.root  = repoRoot;
              devenv.state = "${repoRoot}/.devenv";
              packages = nodeTools;
              env = { NODE_ENV = "development"; };
              enterShell = ''
                echo "Node: $(node -v) | pnpm: $(pnpm -v || true) | yarn: $(yarn -v || true)"
                echo "cd apps/web && pnpm dev"
              '';
            })
          ];
        };

        devShells.dev-api = devenv.lib.mkShell {
          inherit pkgs;
          modules = [
            ({ pkgs, ... }: {
              devenv.root  = repoRoot;
              devenv.state = "${repoRoot}/.devenv";
              packages = nodeTools;
              env = { NODE_ENV = "development"; };
              enterShell = ''
                echo "Node: $(node -v) | pnpm: $(pnpm -v || true) | yarn: $(yarn -v || true)"
                echo "cd apps/api && pnpm dev"
              '';
            })
          ];
        };

        # --- Build artifacts ---
        packages.${system}.image-web = imageWeb;
        packages.${system}.image-api = imageApi;
      }
    );
}
```

> For truly reproducible images, pre‑build `node_modules`/artifacts in CI or use `node2nix`/`pnpm2nix` to avoid network during image build.

---

## 3) direnv integration (optional but nice)

**.envrc (repo root)**

```bash
export DIRENV_WARN_TIMEOUT=20s
# Load devenv helpers
eval "$(devenv direnvrc)"
# Enter a default shell (pick one) – or set app-specific .envrc under apps/*
use flake .#dev-web --impure
```

**apps/web/.envrc**

```bash
use flake ../..#dev-web --impure
```

**apps/api/.envrc**

```bash
use flake ../..#dev-api --impure
```

Then run `direnv allow` in each app directory for instant shells.

---

## 4) Build images locally

**With Docker (optional)**

```bash
# Build
nix build .#image-web
# Load into Docker
docker load -i result
# Run
docker run --rm -p 3000:3000 turborepo-web:latest
```

**Without Docker (pure Nix + skopeo)**

```bash
# Build as docker-archive (OCI inside tar)
nix build .#image-web

# Push to a registry directly (ECR/GHCR/etc.) using skopeo
# Example (GHCR):
export REG=ghcr.io/your-org
export IMAGE=$REG/turborepo-web:latest

echo $GHCR_TOKEN | skopeo login ghcr.io -u your-username --password-stdin
skopeo copy docker-archive:result docker://$IMAGE

# Inspect digest
skopeo inspect docker://$IMAGE | jq -r .Digest
```

> Swap the login/URL for AWS ECR, GCR, or any OCI registry you use.

---

## 5) Push helper (registry‑agnostic)

**scripts/push-image.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
APP=${1:?app name (web|api)}
REGISTRY=${REGISTRY:-"ghcr.io/your-org"}
TAG=${TAG:-"latest"}
IMAGE="$REGISTRY/turborepo-$APP:$TAG"

# Auth: provide $REGISTRY, $REGISTRY_USER, $REGISTRY_PASSWORD or rely on existing creds
if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
  echo "$REGISTRY_PASSWORD" | skopeo login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
fi

# Build result should exist (nix build ran in package.json)
[[ -f result ]] || { echo "result not found (run nix build first)"; exit 1; }

# Copy tar to registry and print digest
skopeo copy docker-archive:result docker://"$IMAGE" >/dev/null
skopeo inspect docker://"$IMAGE" | jq -r .Digest
```

`chmod +x scripts/push-image.sh`

---

## 6) GitHub Actions (CI)

Two jobs:

1. **build** only what changed with Turbo, build images with Nix
2. **push/deploy** using skopeo (no Docker required) + pass digest to your deploy step (Terraform, etc.)

**.github/workflows/ci.yml**

```yaml
name: ci
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Install Nix (multi-user, cache-friendly)
      - uses: DeterminateSystems/nix-installer-action@v13

      - name: Cache Turbo
        uses: actions/cache@v4
        with:
          path: .turbo
          key: ${{ runner.os }}-turbo-${{ hashFiles('**/*.ts','**/*.tsx','**/package.json','**/pnpm-lock.yaml','**/yarn.lock','**/package-lock.json') }}

      - name: Install pnpm
        run: npm i -g pnpm

      - name: Install deps (root)
        run: pnpm i --frozen-lockfile

      - name: Build changed apps
        run: |
          npx turbo run build --since=origin/main --output-logs=new --summarize || true

      - name: Build images via Nix (only for changed apps)
        run: |
          # naive example; you can parse Turbo summary to detect which apps changed
          if git diff --name-only origin/main... | grep -q '^apps/web/'; then
            nix build .#image-web
            echo "web" > .apps-to-push
          fi
          if git diff --name-only origin/main... | grep -q '^apps/api/'; then
            nix build .#image-api
            echo "api" >> .apps-to-push
          fi

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: images-to-push
          path: |
            result
            .apps-to-push

  push:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@v13
      - uses: actions/download-artifact@v4
        with: { name: images-to-push }

      - name: Install skopeo & jq
        run: sudo apt-get update && sudo apt-get install -y skopeo jq

      - name: Push images (no Docker) & print digests
        env:
          REGISTRY: ghcr.io/your-org
          REGISTRY_USER: ${{ github.actor }}
          REGISTRY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
        run: |
          chmod +x scripts/push-image.sh || true
          if [[ -f .apps-to-push ]]; then
            while read -r app; do
              ./scripts/push-image.sh "$app" | tee "apps/$app/.image-digest"
            done < .apps-to-push
          fi

      - uses: actions/upload-artifact@v4
        with:
          name: digests
          path: apps/*/.image-digest
```

> You can add a third job that runs `terraform apply -var="image_digest=$(cat apps/web/.image-digest)"` for each app/service.

---

## 7) Local dev workflow

```bash
# (Optional) direnv for automatic shells
cd apps/web && direnv allow  # enters dev-web shell (Node preinstalled)
cd apps/api && direnv allow  # enters dev-api shell

# Run dev servers
pnpm dev

# Build, test, lint (root)
pnpm build
pnpm test
pnpm lint

# Build images
nix build .#image-web
nix build .#image-api

# Push without Docker (skopeo)
REGISTRY=ghcr.io/your-org ./scripts/push-image.sh web
REGISTRY=ghcr.io/your-org ./scripts/push-image.sh api
```

---

## 8) Tips for fully reproducible images

* Prefer a **single Node version** (here: Node 22) managed by Nix for all apps.
* Pin `nixpkgs` via flake (done) and your package manager lockfile (`pnpm-lock.yaml`).
* For hermetic, network‑free builds: bake dependencies ahead of time (e.g., build in CI, copy `node_modules`/`.next/standalone` into image) or use `node2nix/pnpm2nix`.
* Encode build args as environment variables passed at runtime, not during image build, to keep layers cacheable.

---

## 9) Troubleshooting

* **direnv complains about PWD** → ensure `.envrc` uses `use flake . --impure`.
* **Images fail on npm install** → prebuild `node_modules` in CI, or switch to `pnpm fetch` + `pnpm install --offline` inside the image.
* **Registry auth** → provide `$REGISTRY_USER/$REGISTRY_PASSWORD` or use the registry’s OIDC/github‑token flow.
* **Turbo builds nothing** → use `--since=origin/main` and make sure the checkout fetches history (`fetch-depth: 0`).

---

## 10) What you now have

* Deterministic dev shells for every app (via Nix + devenv)
* Turborepo orchestration (build/test/dev/image) across the monorepo
* OCI images built by Nix (either loaded into Docker or pushed directly with skopeo)
* CI that only builds what changed and pushes images without Docker
* Digests per app ready for deployment tooling (Terraform, ECS, etc.)

> Next steps (optional): wire a deploy job that reads each app’s `.image-digest` and updates your infra (ECS/Fly/K8s) with **digest‑pinned** images for fast, deterministic rollouts.
