# Nix + Turborepo Sample Project

TypeScript monorepo that demonstrates how to use **Nix** for reproducible development environments, CI/CD pipelines, and building OCI (Docker-compatible) container images—all without requiring Docker.

## What This Project Demonstrates

This repository shows you how to:

-   **Develop reproducibly** - Everyone on your team uses the exact same Node.js version, package manager, and tools
-   **Build fast** - Turborepo caches everything and only rebuilds what changed
-   **Create container images without Docker** - Use Nix to build OCI-compliant images as deterministic build artifacts
-   **Run CI/CD without Docker** - GitHub Actions builds and pushes images using only Nix and skopeo
-   **Deploy with confidence** - Image digests ensure you deploy the exact container you tested

### What's Included

**Applications:**

-   `apps/web` - Next.js 14 web application (App Router)
-   `apps/api` - Express.js REST API

**Packages:**

-   `packages/ui` - Shared React component library

**Infrastructure:**

-   `flake.nix` - Nix configuration defining dev environments and OCI image builders
-   `turbo.json` - Turborepo configuration for monorepo task orchestration
-   `scripts/` - Helper scripts for pushing images to registries (using skopeo, not Docker)
-   `.github/workflows/ci.yml` - Complete CI/CD pipeline

---

## What is Nix and Why Use It?

### What is Nix?

**Nix** is a package manager and build system that treats packages and environments as **pure functions**. Given the same inputs (source code + dependencies), Nix always produces the exact same output.

Think of it as:

-   **For development:** Like Docker, but for your dev environment instead of production
-   **For building:** Like a Makefile, but with automatic dependency management and caching
-   **For deployment:** Like Docker, but images are built deterministically without a daemon

### Why Use Nix?

#### 1. True Reproducibility

```bash
# Traditional approach - "works on my machine" problems
$ node --version  # v18.0.0 on your machine
$ node --version  # v20.0.0 on CI
$ node --version  # v16.0.0 on teammate's machine

# Nix approach - everyone gets the exact same environment
$ nix develop
$ node --version  # v22.x.x everywhere, defined in flake.nix
```

#### 2. No System Pollution

-   Nix packages don't interfere with your system packages
-   Each project can use different versions of the same tool
-   Uninstalling is clean—no leftover files

#### 3. Declarative Configuration

Everything your project needs is declared in one file (`flake.nix`):

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }: {
    devShells.default = {
      packages = [ nodejs_22 pnpm git ];  # Exactly what you need
    };
  };
}
```

#### 4. Docker Without Docker

Nix can build OCI (container) images without requiring Docker:

-   No Docker daemon needed in CI
-   Images are reproducible (same source = same image hash)
-   Faster builds with Nix's binary caching
-   Push directly to registries with skopeo

#### 5. Binary Caching

Nix caches built packages. If someone already built Node.js 22 with your exact configuration, Nix downloads the binary instead of recompiling—even in CI.

---

## What You Need to Install

### 1. Nix (Required)

Nix is the only hard requirement. It will provide Node.js, pnpm, and all other tools.

**Install Nix:**

```bash
# Official Nix installer (recommended)
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

**Enable experimental features** (required for flakes):

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Reload your shell
exec $SHELL
```

**Verify:**

```bash
nix --version
# Should show: nix (Nix) 2.x.x
```

**What Nix gives you:**

-   Reproducible package management
-   Isolated development environments
-   Declarative configuration
-   Binary caching for fast downloads
-   Cross-platform (Linux, macOS)

---

### 2. direnv (Optional but Highly Recommended)

Automatically activates the Nix environment when you `cd` into the project.

**Install:**

```bash
# macOS
brew install direnv

# Linux (Ubuntu/Debian)
sudo apt-get install direnv

# Or with Nix
nix profile install nixpkgs#direnv
```

**Setup** - Add to your shell config:

```bash
# For zsh: Add to ~/.zshrc
eval "$(direnv hook zsh)"

# For bash: Add to ~/.bashrc
eval "$(direnv hook bash)"

# Reload your shell
exec $SHELL
```

**Usage:**

```bash
cd ~/nix-sample
direnv allow  # First time only

# Now every time you cd here, the environment loads automatically!
```

**What direnv gives you:**

-   No need to run `nix develop` manually
-   Automatic environment switching between projects
-   Per-directory environment isolation

---

### 3. skopeo (Required Only for Pushing Images)

A tool for working with OCI images without Docker. Already included in the Nix dev shell, but you can install it globally:

```bash
# macOS
brew install skopeo

# Linux (Ubuntu/Debian)
sudo apt-get install skopeo
```

**What skopeo gives you:**

-   Push/pull OCI images without Docker daemon
-   Inspect remote images
-   Copy images between registries

---

### 4. Node.js & pnpm (Provided by Nix - Don't Install Manually!)

**Do not install these yourself.** Nix provides them automatically in the development shell, ensuring everyone uses the same versions.

To verify (after entering the Nix shell):

```bash
nix develop --impure  # or just 'cd .' if using direnv
node --version   # v22.x.x
pnpm --version   # 9.x.x
```

---

## Quick Start

### Step 1: Clone and Enter the Environment

```bash
# Clone or cd into the project
cd ~/nix-sample

# Method A: Use direnv (if installed)
direnv allow

# Method B: Manually enter Nix shell
nix develop --impure
```

You should see:

```
🚀 Nix + Turborepo Monorepo
Node: v22.x.x | pnpm: 9.x.x
```

### Step 2: Install Dependencies

```bash
pnpm install
```

### Step 3: Start Development Servers

```bash
# Start all apps
pnpm dev
```

Visit:

-   **Web app:** http://localhost:3000
-   **API:** http://localhost:3001

### Step 4: Build Everything

```bash
pnpm build
```

Turborepo will cache the results. Run it again—it completes instantly!

### Step 5: Build OCI Images (No Docker Required!)

```bash
# Build the web app image
nix build .#image-web

# Inspect the image without Docker
skopeo inspect docker-archive:result

# Optional: Load into Docker if you want to run it locally
docker load -i result
docker run --rm -p 3000:3000 nix-sample-web:latest
```

---

## Project Structure Explained

```
.
├── .github/workflows/
│   └── ci.yml                    # CI/CD pipeline (builds, tests, pushes images)
│
├── apps/
│   ├── web/                      # Next.js 14 web application
│   │   ├── src/app/              # App Router pages
│   │   │   ├── layout.tsx        # Root layout
│   │   │   └── page.tsx          # Home page
│   │   ├── package.json          # Dependencies + scripts
│   │   ├── next.config.js        # Next.js configuration
│   │   ├── tsconfig.json         # TypeScript config
│   │   └── .envrc                # Auto-loads dev-web shell (if using direnv)
│   │
│   └── api/                      # Express.js API
│       ├── src/
│       │   └── index.ts          # API server (health check, info endpoints)
│       ├── package.json          # Dependencies + scripts
│       ├── tsconfig.json         # TypeScript config
│       └── .envrc                # Auto-loads dev-api shell (if using direnv)
│
├── packages/
│   └── ui/                       # Shared React component library
│       ├── src/
│       │   ├── Button.tsx        # Example component
│       │   └── index.ts          # Package exports
│       └── package.json
│
├── scripts/
│   ├── push-image.sh             # Push images to registry using skopeo
│   └── print-digest.sh           # Fetch remote image digest
│
├── flake.nix                     # 🔑 The heart of the setup
├── flake.lock                    # Lock file (like package-lock.json for Nix)
├── .envrc                        # direnv config (auto-loads default shell)
├── package.json                  # Root workspace config
├── turbo.json                    # Turborepo configuration
└── .gitignore                    # Ignores build artifacts, node_modules, etc.
```

### Key Files

#### `flake.nix` - The Heart of the Setup

This file defines:

1. **Inputs** - External dependencies (nixpkgs, devenv, flake-utils)
2. **Development Shells** - Three environments:
    - `default` - General monorepo work
    - `dev-web` - Web app specific (auto-loaded by `apps/web/.envrc`)
    - `dev-api` - API specific (auto-loaded by `apps/api/.envrc`)
3. **Build Outputs** - OCI images:
    - `packages.image-web` - Web app image
    - `packages.image-api` - API image

All shells provide: Node.js 22, pnpm, git, jq, skopeo

#### `turbo.json` - Monorepo Task Orchestration

Defines tasks (build, dev, test, lint, image) and their:

-   **Dependencies** - e.g., `build` depends on `^build` (dependencies must build first)
-   **Outputs** - What directories to cache (dist/, .next/, etc.)
-   **Cache behavior** - Some tasks never cache (dev), others always do (build)

#### `.github/workflows/ci.yml` - CI/CD Pipeline

The workflow:

1. Installs Nix in GitHub Actions
2. Detects which apps changed using Turborepo and git
3. Builds and tests only changed apps
4. Builds OCI images with Nix (no Docker daemon!)
5. Pushes images to GitHub Container Registry using skopeo
6. Saves image digests as artifacts for deployment

---

## Core Concepts

### 1. Nix Flakes

A **flake** is a Nix file with a standardized structure:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Where to get packages
  };

  outputs = { nixpkgs, ... }: {
    devShells.default = { /* dev environment */ };
    packages.my-app = { /* build outputs */ };
  };
}
```

**Why flakes?**

-   Reproducible: Lock file pins exact versions
-   Composable: Flakes can depend on other flakes
-   Standard: All Nix flakes follow the same structure

### 2. Turborepo

A build system for monorepos that:

-   **Caches** task outputs (never rebuild unchanged code)
-   **Parallelizes** independent tasks
-   **Understands** dependencies (builds packages in the right order)

**Example:**

```bash
# First run: Builds everything
pnpm turbo build
# → web: 45s, api: 12s

# Second run: Nothing changed
pnpm turbo build
# → web: CACHED, api: CACHED (instant!)

# Change only the API
echo "// comment" >> apps/api/src/index.ts
pnpm turbo build
# → web: CACHED, api: 8s (only rebuilds API)
```

### 3. OCI Images (Docker-compatible, Docker-free!)

OCI (Open Container Initiative) images are the standard container format. Docker uses OCI, but so do Kubernetes, Podman, and others.

**How Nix builds OCI images:**

```nix
pkgs.dockerTools.buildImage {
  name = "my-app";
  contents = [ nodejs bash ];  # What goes in the image
  config = {
    Cmd = [ "node" "index.js" ];  # What runs at startup
  };
}
```

**Output:** A `.tar` file containing the complete image.

**Benefits:**

-   **No Docker daemon** - Build and push without Docker
-   **Reproducible** - Same source = same image (bit-for-bit)
-   **Cacheable** - Nix reuses layers aggressively
-   **Secure** - Builds run in sandboxes, no privileged operations

### 4. devenv

A Nix framework for creating development environments with:

-   Clean shell definitions
-   Service orchestration (databases, Redis, etc.)
-   Environment variables
-   Welcome messages

**Example from our flake.nix:**

```nix
devShells.dev-web = devenv.lib.mkShell {
  inherit inputs pkgs;
  modules = [
    ({ pkgs, ... }: {
      devenv.root = repoRoot;
      packages = [ nodejs pnpm git ];
      env.NODE_ENV = "development";
      enterShell = ''
        echo "🚀 Web App Dev Environment"
      '';
    })
  ];
};
```

---

## Development Workflow

### Starting Development

```bash
# Option A: With direnv (automatic)
cd nix-sample
direnv allow
# Environment loads automatically!

# Option B: Manual
nix develop --impure
```

### Running Apps

```bash
# All apps at once
pnpm dev

# Individual apps
cd apps/web && pnpm dev   # http://localhost:3000
cd apps/api && pnpm dev   # http://localhost:3001
```

### Building

```bash
# Build everything
pnpm build

# Build only changed apps (since last commit)
pnpm turbo build --filter="...[HEAD^1]"

# Build only the web app and its dependencies
pnpm turbo build --filter=web...

# Force rebuild (ignores cache)
pnpm turbo build --force
```

### Testing and Linting

```bash
pnpm test   # Run all tests
pnpm lint   # Lint all code
```

### Cleaning Up

```bash
pnpm clean                # Clean node_modules and build outputs
rm -rf result result-*    # Clean Nix build results
rm -rf .devenv .direnv    # Clean environment state
```

---

## Building OCI Images

### Local Builds

```bash
# Build web app image
nix build .#image-web
# Output: ./result → /nix/store/.../image.tar.gz

# Build API image
nix build .#image-api

# Build both
nix build  # Uses packages.default
```

### Inspect Images (Without Docker!)

```bash
# View image metadata
skopeo inspect docker-archive:result

# View image layers
tar -tvf result | head -20

# Extract image contents
mkdir extracted
tar -xf result -C extracted
```

### Run Images Locally

```bash
# Option A: Load into Docker
docker load -i result
docker run --rm -p 3000:3000 nix-sample-web:latest

# Option B: Run with Podman (Docker alternative)
podman load -i result
podman run --rm -p 3000:3000 nix-sample-web:latest
```

### Push Images to a Registry

#### Using skopeo (No Docker!)

```bash
# Build the image
nix build .#image-web

# Login to registry
echo $GITHUB_TOKEN | skopeo login ghcr.io -u your-username --password-stdin

# Push image
skopeo copy \
  docker-archive:result \
  docker://ghcr.io/your-org/nix-sample-web:latest

# Get the digest (for deterministic deployments)
skopeo inspect docker://ghcr.io/your-org/nix-sample-web:latest | jq -r .Digest
```

#### Using the Helper Script

```bash
nix build .#image-web

REGISTRY=ghcr.io/your-org \
REGISTRY_USER=your-username \
REGISTRY_PASSWORD=$GITHUB_TOKEN \
./scripts/push-image.sh web

# Output: sha256:abc123... (the digest)
```

**Why use digests?** Tags like `:latest` can change. Digests (`sha256:...`) are immutable hashes of the image content. Deploying by digest guarantees you deploy the exact tested image.

### Integration with Turborepo

Each app has an `image` task in `package.json`:

```json
{
    "scripts": {
        "image": "nix build ../..#image-web && ../../scripts/push-image.sh web > .image-digest"
    }
}
```

Run it:

```bash
cd apps/web
pnpm image
# Builds and pushes the image, saves digest to .image-digest
```

Or build all images:

```bash
pnpm turbo image  # Only builds images for changed apps
```

---

## CI/CD with GitHub Actions

### Overview

**Location:** `.github/workflows/ci.yml`

The CI workflow:

1. **Detects changes** - Uses Turborepo + git to find which apps changed
2. **Builds and tests** - Only builds/tests changed apps (saves time)
3. **Builds images** - Uses Nix to create OCI images (no Docker daemon!)
4. **Pushes images** - Uses skopeo to push to GitHub Container Registry
5. **Saves digests** - Stores image digests as artifacts for deployment

### Key Features

#### Multi-Level Caching

1. **Nix cache** - Binary packages are cached across runs
2. **Turborepo cache** - Build outputs are cached
3. **GitHub Actions cache** - `.turbo` directory persists

Result: Second builds are 10-50x faster!

#### Docker-Free Operation

```yaml
# No Docker required!
- name: Install Nix
  uses: DeterminateSystems/nix-installer-action@v13

- name: Build images
  run: nix build .#image-web

- name: Push with skopeo
  run: skopeo copy docker-archive:result docker://ghcr.io/...
```

#### Only Build What Changed

```yaml
- name: Build changed apps
  run: |
      pnpm turbo build \
        --filter="...[origin/${{ github.base_ref || 'main' }}]"
```

### Deployment Integration

The workflow saves image digests. Use them for deterministic deployments:

```bash
# Download digest from CI artifacts
WEB_DIGEST=$(cat web.txt)

# Deploy to ECS (example)
aws ecs update-service \
  --cluster my-cluster \
  --service web \
  --force-new-deployment \
  --task-definition my-task

# Or update task definition to use digest
aws ecs register-task-definition \
  --family web-task \
  --container-definitions "[{
    \"name\": \"web\",
    \"image\": \"ghcr.io/your-org/nix-sample-web@${WEB_DIGEST}\"
  }]"

# Deploy to Kubernetes (example)
kubectl set image deployment/web \
  web=ghcr.io/your-org/nix-sample-web@$WEB_DIGEST
```

---

## Customization & Next Steps

### Add a New App

```bash
# Create app structure
mkdir -p apps/mobile
cd apps/mobile
pnpm init

# Add to root package.json workspaces
# Edit: package.json → "workspaces": ["apps/*", "packages/*"]

# Add to turbo.json tasks
# Add entries in turbo.json for build, dev, etc.

# Create .envrc for auto-loading (optional)
echo "use flake ../..#dev-mobile --impure" > .envrc

# Add a dev shell in flake.nix (optional)
# Copy dev-web or dev-api and rename to dev-mobile
```

---

### Change Node.js Version

Edit `flake.nix`:

```nix
# Change this line:
node = pkgs.nodejs_22;

# To any available version:
node = pkgs.nodejs_20;   # Node 20 LTS
node = pkgs.nodejs_18;   # Node 18
```

Then:

```bash
rm -rf .devenv .direnv
direnv reload  # or nix develop --impure
```

---

### Add More Tools to Dev Environment

Edit `flake.nix`:

```nix
nodeTools = [
  node
  pkgs.pnpm
  pkgs.git
  pkgs.jq
  pkgs.skopeo
  # Add more:
  pkgs.redis           # Redis CLI
  pkgs.postgresql      # PostgreSQL CLI
  pkgs.kubectl         # Kubernetes CLI
  pkgs.awscli2         # AWS CLI
  pkgs.terraform       # Terraform
];
```

---

### Add a Database to Dev Environment

Edit `flake.nix` in any devShell:

```nix
devShells.default = devenv.lib.mkShell {
  inherit inputs pkgs;
  modules = [
    ({ pkgs, ... }: {
      packages = nodeTools;

      # Add PostgreSQL service
      services.postgres = {
        enable = true;
        package = pkgs.postgresql_16;
        initialDatabases = [{ name = "myapp_dev"; }];
        listen_addresses = "127.0.0.1";
      };

      # Add Redis service
      services.redis.enable = true;

      # Set environment variables
      env.DATABASE_URL = "postgresql://localhost/myapp_dev";
      env.REDIS_URL = "redis://127.0.0.1:6379";
    })
  ];
};
```

---

### Optimize Images for Production

Current images install dependencies at runtime. For production:

**Option A: Prebuild dependencies in the image**

```nix
extraCommands = ''
  mkdir -p app
  cp -R ${srcWeb}/* app/
  cd app && pnpm install --frozen-lockfile --prod
'';
```

**Option B: Use Next.js standalone mode**

```javascript
// next.config.js
module.exports = {
    output: "standalone",
};
```

Then modify flake.nix to copy only `.next/standalone/` into the image.

---

### Set Up Multi-Architecture Builds

Build for both amd64 and arm64:

```bash
# Build for x86_64 (amd64)
nix build .#image-web --system x86_64-linux

# Build for ARM64
nix build .#image-web --system aarch64-linux

# Push both
skopeo copy docker-archive:result docker://ghcr.io/your-org/app:latest-amd64
skopeo copy docker-archive:result docker://ghcr.io/your-org/app:latest-arm64

# Create manifest list (multi-arch image)
docker manifest create ghcr.io/your-org/app:latest \
  ghcr.io/your-org/app:latest-amd64 \
  ghcr.io/your-org/app:latest-arm64
docker manifest push ghcr.io/your-org/app:latest
```

---

### Set Up Your Own Binary Cache

Speed up builds by sharing built packages:

**Using Cachix (easy, hosted):**

```bash
# Install cachix
nix profile install nixpkgs#cachix

# Create and use cache
cachix authtoken YOUR_TOKEN
cachix use your-cache-name

# Push to cache after builds
nix build .#image-web
cachix push your-cache-name ./result
```

**In CI:**

```yaml
- name: Setup Cachix
  uses: cachix/cachix-action@v14
  with:
      name: your-cache-name
      authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
```

---

## Quick Command Reference

### Development

```bash
pnpm dev          # Start all dev servers
pnpm build        # Build all apps
pnpm test         # Run all tests
pnpm lint         # Lint all code
pnpm clean        # Clean build outputs
```

### Turborepo

```bash
pnpm turbo build --filter=web               # Build only web app
pnpm turbo build --filter=web...            # Build web + its dependencies
pnpm turbo build --filter="...[HEAD^1]"     # Build changed apps
pnpm turbo build --force                    # Force rebuild (ignore cache)
```

### Nix Shells

```bash
nix develop --impure                # Default shell
nix develop .#dev-web --impure      # Web shell
nix develop .#dev-api --impure      # API shell
```

### Building Images

```bash
nix build .#image-web               # Build web image
nix build .#image-api               # Build API image
nix build                           # Build all images
```

### Working with Images

```bash
skopeo inspect docker-archive:result                    # Inspect image
docker load -i result                                   # Load into Docker
skopeo copy docker-archive:result docker://registry/... # Push to registry
./scripts/push-image.sh web                             # Push with helper script
```

### Cleanup

```bash
pnpm clean                               # Clean build outputs
rm -rf result result-*                   # Clean Nix build results
rm -rf .devenv .direnv                   # Clean environment state
rm -rf node_modules                      # Clean dependencies
nix-collect-garbage                      # Clean Nix store (frees disk space)
```

---

## Learn More

### Documentation

-   [Nix Manual](https://nixos.org/manual/nix/stable/) - Official Nix documentation
-   [Nix Pills](https://nixos.org/guides/nix-pills/) - Learn Nix deeply
-   [Zero to Nix](https://zero-to-nix.com/) - Beginner-friendly Nix guide
-   [Turborepo Docs](https://turbo.build/repo/docs) - Turborepo documentation
-   [devenv Guide](https://devenv.sh/) - devenv documentation
-   [skopeo](https://github.com/containers/skopeo) - skopeo documentation

### Community

-   [Nix Discourse](https://discourse.nixos.org/) - Official forum
-   [NixOS Wiki](https://wiki.nixos.org/) - Community wiki
-   [r/NixOS](https://reddit.com/r/NixOS) - Reddit community

---
