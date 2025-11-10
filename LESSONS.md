# Nix for Local Development, CI, and OCI Images - Lessons

This document explains what you need to install, what each component does, and how to use this sample project effectively.

---

## Table of Contents

1. [Prerequisites & Installation](#prerequisites--installation)
2. [Core Concepts](#core-concepts)
3. [Project Structure](#project-structure)
4. [Local Development Workflow](#local-development-workflow)
5. [Building OCI Images](#building-oci-images)
6. [CI/CD with GitHub Actions](#cicd-with-github-actions)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Prerequisites & Installation

### What You Need to Install

#### 1. Nix (Required)

**What it is:** A package manager and build system that provides reproducible, declarative builds.

**Why we use it:** Ensures everyone has the exact same development environment and build outputs, regardless of their OS or existing tools.

**How to install:**

```bash
# Recommended: Determinate Systems installer (better UX)
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

**Verify installation:**

```bash
nix --version
# Should output: nix (Nix) 2.x.x
```

**What it gives you:**
- Reproducible package management
- Declarative environment definitions
- Binary caching for fast builds
- Cross-platform support (Linux, macOS)

---

#### 2. direnv (Optional but Recommended)

**What it is:** Automatically loads environment variables and tools when you enter a directory.

**Why we use it:** Eliminates the need to manually run `nix develop` every time. Your shell automatically gets the right Node.js version, pnpm, and other tools.

**How to install:**

```bash
# macOS
brew install direnv

# Linux (Ubuntu/Debian)
sudo apt-get install direnv

# Or with Nix
nix profile install nixpkgs#direnv
```

**Setup (add to your shell config):**

```bash
# For bash: Add to ~/.bashrc
eval "$(direnv hook bash)"

# For zsh: Add to ~/.zshrc
eval "$(direnv hook zsh)"

# For fish: Add to ~/.config/fish/config.fish
direnv hook fish | source
```

**Verify installation:**

```bash
direnv version
```

**What it gives you:**
- Automatic environment activation when you `cd` into the project
- Per-directory environment isolation
- No need to remember to activate environments

---

#### 3. skopeo (Required for pushing images)

**What it is:** A command-line tool for OCI/Docker image operations that works without Docker.

**Why we use it:** Allows us to push Nix-built images to registries without needing the Docker daemon.

**How to install:**

```bash
# macOS
brew install skopeo

# Linux (Ubuntu/Debian)
sudo apt-get install skopeo

# Or it's already included in our Nix shell!
nix develop  # skopeo is available here
```

**Verify installation:**

```bash
skopeo --version
```

**What it gives you:**
- Push/pull OCI images without Docker
- Inspect remote images
- Copy images between registries
- Works entirely with Nix-built image tar files

---

#### 4. Node.js & pnpm (Provided by Nix - No Manual Install Needed!)

**What they are:**
- **Node.js**: JavaScript runtime
- **pnpm**: Fast, disk-efficient package manager

**Why we DON'T manually install them:** Nix provides these automatically in our development shell. This ensures everyone uses the exact same versions.

**Verify (inside the project directory with direnv, or after `nix develop`):**

```bash
node --version   # Should show v22.x.x
pnpm --version   # Should show 9.x.x
```

---

## Core Concepts

### 1. Nix Flakes

**Location:** `flake.nix`

**What it is:** A Nix file that declares:
- External dependencies (inputs)
- Development shells with specific tools
- Build outputs (like OCI images)

**Key sections:**

```nix
inputs = {
  nixpkgs.url = "...";     # Where to get packages
  devenv.url = "...";       # Development environment framework
}

outputs = {
  devShells = { ... };      # Development environments
  packages = { ... };        # Build outputs (images)
}
```

**Why it matters:** This single file defines your entire reproducible environment and build process.

---

### 2. Turborepo

**Location:** `turbo.json`, root `package.json`

**What it is:** A monorepo build system that caches task outputs and runs only what changed.

**Key features:**
- **Caching:** Never rebuild something that hasn't changed
- **Parallel execution:** Run tasks across apps simultaneously
- **Dependency awareness:** Build packages in the right order

**Configuration example:**

```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],  // Build dependencies first
      "outputs": ["dist/**"]     // Cache these directories
    }
  }
}
```

**Why it matters:** In a monorepo with multiple apps, this saves massive amounts of time by building only what changed.

---

### 3. OCI Images (Docker-compatible, but no Docker needed!)

**What they are:** Standardized container images that can run anywhere (Docker, Kubernetes, ECS, etc.)

**How Nix builds them:**

```nix
pkgs.dockerTools.buildImage {
  name = "my-app";
  contents = [ node pkgs.bash ];  # What goes in the image
  config = {
    Cmd = [ "node" "index.js" ];  # What runs
  };
}
```

**Output:** A `.tar` file containing the complete OCI image.

**Why this is powerful:**
- No Docker daemon needed
- Reproducible: Same input = same output (bit-for-bit)
- Can be built in CI without Docker
- Can be pushed to any registry with skopeo

---

### 4. devenv

**What it is:** A framework (built on Nix) for creating development environments.

**Key features:**
- Clean separation of dev environments per app
- Automatic environment variable setup
- Welcome messages when entering shells
- State management (stores temporary files in `.devenv/`)

**Why we use it:** Makes it easy to have different dev shells for different apps (web vs API) while sharing common tools.

---

## Project Structure

```
.
├── .github/workflows/
│   └── ci.yml                    # GitHub Actions CI/CD pipeline
│
├── apps/
│   ├── web/                      # Next.js web application
│   │   ├── src/app/              # Next.js App Router pages
│   │   ├── package.json          # Web app dependencies
│   │   ├── .envrc                # Auto-loads dev-web shell
│   │   └── ...
│   │
│   └── api/                      # Express.js API
│       ├── src/index.ts          # API server code
│       ├── package.json          # API dependencies
│       ├── .envrc                # Auto-loads dev-api shell
│       └── ...
│
├── packages/
│   └── ui/                       # Shared React components
│       └── src/
│           ├── Button.tsx        # Example shared component
│           └── index.ts          # Package exports
│
├── scripts/
│   ├── push-image.sh             # Push images to registry (skopeo)
│   └── print-digest.sh           # Get image digest from registry
│
├── flake.nix                     # Nix configuration (dev shells + images)
├── .envrc                        # direnv config (auto-load default shell)
├── package.json                  # Root workspace configuration
├── turbo.json                    # Turborepo task configuration
└── LESSONS.md                    # This file!
```

---

## Local Development Workflow

### Step 1: Initial Setup

```bash
# Clone the repo
cd nix-sample

# If you have direnv:
direnv allow
# This automatically loads the Nix environment

# OR manually enter the Nix shell:
nix develop

# Install dependencies
pnpm install
```

**What happens:**
- Nix downloads and sets up Node.js 22, pnpm, git, jq, skopeo
- All tools are now available in your PATH
- Environment variables are set

---

### Step 2: Development

#### Option A: Run All Apps

```bash
# From the root:
pnpm dev
```

This starts:
- Web app on http://localhost:3000
- API on http://localhost:3001

#### Option B: Work on Individual Apps

```bash
# For web:
cd apps/web
# If you have direnv, it auto-loads the dev-web shell
pnpm dev

# For API:
cd apps/api
# If you have direnv, it auto-loads the dev-api shell
pnpm dev
```

---

### Step 3: Build & Test

```bash
# Build everything
pnpm build

# Build only changed apps (useful after git commits)
pnpm turbo build --filter="...[HEAD^1]"

# Run tests
pnpm test

# Lint
pnpm lint
```

**Key point:** Turborepo caches these results. If you run `pnpm build` again without changing anything, it completes instantly!

---

### Step 4: Clean Up

```bash
# Clean all node_modules and build outputs
pnpm clean

# Clean Nix build results
rm -rf result result-*
```

---

## Building OCI Images

### Local Image Build (No Registry Push)

#### Build with Nix

```bash
# Build web image
nix build .#image-web
# Output: ./result (symlink to OCI image tar)

# Build API image
nix build .#image-api
# Output: ./result

# Build both
nix build
```

**What you get:** A `result` symlink pointing to an OCI-compliant tar archive.

---

#### Inspect the Image (Without Docker!)

```bash
# View image contents
tar -tvf result | head -20

# Or use skopeo
skopeo inspect docker-archive:result
```

---

#### Load into Docker (Optional)

If you want to run the image locally with Docker:

```bash
docker load -i result
# Output: Loaded image: nix-sample-web:latest

docker run --rm -p 3000:3000 nix-sample-web:latest
```

---

### Push Images to a Registry (Docker-Free!)

#### Prerequisites

1. Have a container registry (GHCR, ECR, Docker Hub, GCR, etc.)
2. Registry credentials

#### Push with skopeo

```bash
# Build the image
nix build .#image-web

# Login to registry
echo $REGISTRY_TOKEN | skopeo login ghcr.io -u your-username --password-stdin

# Push image
skopeo copy \
  docker-archive:result \
  docker://ghcr.io/your-org/nix-sample-web:latest

# Get the digest
skopeo inspect docker://ghcr.io/your-org/nix-sample-web:latest | jq -r .Digest
```

#### Using the Helper Script

```bash
# Build the image first
nix build .#image-web

# Push using our script
REGISTRY=ghcr.io/your-org \
REGISTRY_USER=your-username \
REGISTRY_PASSWORD=$GITHUB_TOKEN \
./scripts/push-image.sh web

# Output: sha256:abc123... (the digest)
```

**Why use digests?** Deploying by digest (`image@sha256:...`) ensures you deploy the exact image, even if someone pushes a new `:latest` tag.

---

### Integration with Turborepo

Each app has an `image` script in its `package.json`:

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
# Builds the image and pushes it, saving digest to .image-digest
```

---

## CI/CD with GitHub Actions

### Overview

**Location:** `.github/workflows/ci.yml`

**What it does:**
1. Detects which apps changed (Turborepo + git)
2. Builds and tests only those apps
3. Builds OCI images with Nix
4. Pushes images to GitHub Container Registry (no Docker!)
5. Saves image digests for deployment

---

### Key Jobs

#### Job 1: Build & Test

```yaml
- name: Install Nix
  uses: DeterminateSystems/nix-installer-action@v13

- name: Install dependencies
  run: pnpm install --frozen-lockfile

- name: Build changed apps
  run: pnpm turbo build --filter="...[origin/main]"
```

**What happens:**
- Installs Nix in the CI runner
- Uses Turborepo to build only changed apps
- Builds OCI images with `nix build`

---

#### Job 2: Push Images

```yaml
- name: Install skopeo
  run: sudo apt-get install -y skopeo

- name: Login to GHCR
  run: echo "${{ secrets.GITHUB_TOKEN }}" | skopeo login ghcr.io ...

- name: Push images
  run: |
    skopeo copy \
      docker-archive:result-web \
      docker://ghcr.io/${{ github.repository }}/nix-sample-web:${{ github.sha }}
```

**What happens:**
- Installs skopeo (no Docker needed!)
- Authenticates with GitHub Container Registry
- Pushes images using skopeo
- Tags images with commit SHA for traceability

---

### Optimization: Caching

The workflow uses multiple caches:

1. **Nix binary cache:** Reuses Nix build outputs across runs
2. **Turborepo cache:** Reuses app build outputs
3. **GitHub Actions cache:** Stores `.turbo` directory

**Result:** After the first run, subsequent builds are much faster!

---

### Deployment Integration (Example)

The workflow saves image digests as artifacts. A deployment job could use them:

```yaml
deploy:
  needs: push
  runs-on: ubuntu-latest
  steps:
    - name: Download digests
      uses: actions/download-artifact@v4
      with:
        name: image-digests

    - name: Deploy to ECS
      run: |
        WEB_DIGEST=$(cat web.txt)
        # Deploy with: your-registry/nix-sample-web@$WEB_DIGEST
```

---

## Troubleshooting

### Issue: `direnv: error .envrc is blocked`

**Cause:** direnv requires explicit permission to load `.envrc` files.

**Solution:**

```bash
cd nix-sample
direnv allow
```

---

### Issue: `nix develop` fails with "PWD not set"

**Cause:** devenv needs access to the `$PWD` environment variable.

**Solution:**

```bash
# Use --impure flag
nix develop --impure

# Or update .envrc to include --impure
use flake . --impure
```

---

### Issue: `nix build .#image-web` fails with "apps/web does not exist"

**Cause:** Nix build happens in a pure environment without access to untracked files.

**Solution:**

```bash
# Make sure files are tracked by git
git add apps/web
git commit -m "Add web app"

# Then try again
nix build .#image-web
```

---

### Issue: Turborepo doesn't detect changes

**Cause:** Turborepo needs git history to detect changes.

**Solution:**

```bash
# Make sure you're comparing against the right branch
pnpm turbo build --filter="...[origin/main]"

# Or force rebuild everything
pnpm turbo build --force
```

---

### Issue: pnpm install fails with "Node version mismatch"

**Cause:** Using a different Node.js version outside the Nix shell.

**Solution:**

```bash
# Make sure you're in the Nix environment
nix develop --impure

# Or with direnv
direnv allow
cd .  # Reload environment
```

---

### Issue: `skopeo: command not found` in CI

**Cause:** skopeo not installed in the CI runner.

**Solution:**

Add installation step to `.github/workflows/ci.yml`:

```yaml
- name: Install skopeo
  run: sudo apt-get update && sudo apt-get install -y skopeo
```

---

### Issue: Image push fails with authentication error

**Cause:** Invalid or missing registry credentials.

**Solution:**

```bash
# For GHCR (GitHub Container Registry)
echo $GITHUB_TOKEN | skopeo login ghcr.io -u $GITHUB_USERNAME --password-stdin

# For other registries, use their specific credentials
```

In CI, ensure secrets are set:
- Settings → Secrets → Actions → Add secret

---

## Next Steps

### 1. Add More Apps

```bash
# Create a new app
mkdir -p apps/mobile
cd apps/mobile
pnpm init

# Add to turbo.json tasks
# Create .envrc for app-specific shell
```

---

### 2. Optimize Images for Production

Current images install dependencies at runtime. For production:

**Option A: Prebuild dependencies**

```nix
# In flake.nix, install node_modules during build:
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
  output: 'standalone',
}
```

Then copy only the standalone output into the image.

---

### 3. Add a Database Service

Add PostgreSQL to your dev environment:

```nix
# In flake.nix devShells:
services.postgres = {
  enable = true;
  package = pkgs.postgresql_16;
  initialDatabases = [{ name = "myapp"; }];
};
```

---

### 4. Set Up Deployment

Create a deployment workflow that uses the digests:

```yaml
# .github/workflows/deploy.yml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # Download digests from CI workflow
      # Deploy to ECS/K8s/Fly.io using exact digest
```

---

### 5. Add More Nix Packages

Need Redis, PostgreSQL client, or other tools?

```nix
# In flake.nix nodeTools:
nodeTools = [
  node
  pkgs.pnpm
  pkgs.redis      # Add this
  pkgs.postgresql # And this
];
```

---

### 6. Cross-Platform Builds

Build images for both amd64 and arm64:

```bash
# Build for specific architecture
nix build .#image-web --system x86_64-linux
nix build .#image-web --system aarch64-linux
```

---

### 7. Binary Caching

Set up your own Nix binary cache (e.g., with Cachix) to speed up CI:

```yaml
# In .github/workflows/ci.yml
- name: Setup Cachix
  uses: cachix/cachix-action@v14
  with:
    name: your-cache-name
    authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
```

---

## Summary

### What You Learned

1. **Nix** provides reproducible environments and builds
2. **direnv** automatically loads the environment when you enter the directory
3. **Turborepo** caches tasks and builds only what changed
4. **skopeo** lets you work with OCI images without Docker
5. **devenv** makes it easy to create dev environments with Nix
6. **GitHub Actions** can build and push images using Nix and skopeo

### Why This Setup is Powerful

- **Reproducible:** Same code + same flake.nix = same output (always)
- **Fast:** Caching at multiple levels (Nix, Turbo, GitHub Actions)
- **Docker-free:** Can build and push images without Docker daemon
- **Cross-platform:** Works on Linux and macOS
- **Monorepo-friendly:** Turborepo handles multiple apps efficiently
- **CI-ready:** GitHub Actions workflow included

### Key Files to Remember

- `flake.nix` - The source of truth for environments and builds
- `turbo.json` - Defines task dependencies and caching
- `.envrc` - Auto-loads Nix environment (requires direnv)
- `.github/workflows/ci.yml` - CI/CD pipeline

---

**Ready to build?**

```bash
nix develop --impure
pnpm install
pnpm dev
```

Happy coding!
