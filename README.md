# Nix + Turborepo Sample Project

A production-ready TypeScript monorepo demonstrating:
- Reproducible development with **Nix**
- Fast monorepo builds with **Turborepo**
- **Docker-free** OCI image building
- CI/CD with **GitHub Actions**

## Quick Start

```bash
# 1. Install Nix (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Enter the development environment
nix develop --impure

# 3. Install dependencies
pnpm install

# 4. Start development servers
pnpm dev
```

**Web app:** http://localhost:3000
**API:** http://localhost:3001

## What's Included

### Applications

- **apps/web** - Next.js 14 web application (App Router)
- **apps/api** - Express.js REST API

### Packages

- **packages/ui** - Shared React component library

### Infrastructure

- **flake.nix** - Nix configuration for dev shells & OCI images
- **turbo.json** - Turborepo task orchestration
- **scripts/** - Helper scripts for image operations
- **.github/workflows/** - CI/CD pipeline

## Key Features

### 1. Reproducible Development Environment

Nix ensures everyone has the exact same tools:
- Node.js 22
- pnpm 9.x
- git, jq, skopeo
- All other dependencies

```bash
# Automatic activation with direnv (optional)
brew install direnv
echo 'eval "$(direnv hook bash)"' >> ~/.zshrc
direnv allow

# Now just cd into any app directory and your environment is ready!
```

### 2. Fast Monorepo Builds

Turborepo caches task outputs and runs only what changed:

```bash
# Build everything
pnpm build

# Build only changed apps (since last commit)
pnpm turbo build --filter="...[HEAD^1]"

# Build only the web app and its dependencies
pnpm turbo build --filter=web...
```

### 3. Docker-Free OCI Images

Build standard OCI images using Nix (no Docker daemon required!):

```bash
# Build images
nix build .#image-web   # Web app image
nix build .#image-api   # API image

# Inspect without Docker
skopeo inspect docker-archive:result

# Push to registry (no Docker needed!)
echo $TOKEN | skopeo login ghcr.io -u username --password-stdin
skopeo copy docker-archive:result docker://ghcr.io/your-org/app:latest
```

Or use the helper script:

```bash
nix build .#image-web
REGISTRY=ghcr.io/your-org ./scripts/push-image.sh web
```

### 4. GitHub Actions CI/CD

The included workflow (`.github/workflows/ci.yml`):
- Builds only changed apps
- Creates OCI images with Nix
- Pushes to GitHub Container Registry
- Saves image digests for deployment

No Docker required in CI!

## Project Structure

```
.
├── apps/
│   ├── web/              # Next.js app
│   └── api/              # Express API
├── packages/
│   └── ui/               # Shared components
├── scripts/
│   ├── push-image.sh     # Push images to registry
│   └── print-digest.sh   # Get image digest
├── .github/workflows/
│   └── ci.yml            # CI/CD pipeline
├── flake.nix             # Nix configuration
├── turbo.json            # Turborepo config
└── LESSONS.md            # Detailed documentation
```

## Common Commands

### Development

```bash
pnpm dev          # Start all dev servers
pnpm build        # Build all apps
pnpm test         # Run all tests
pnpm lint         # Lint all apps
pnpm clean        # Clean all build outputs
```

### Per-App Commands

```bash
cd apps/web
pnpm dev          # Start Next.js dev server
pnpm build        # Build for production
pnpm image        # Build & push OCI image
```

### Image Operations

```bash
# Build images
nix build .#image-web
nix build .#image-api

# Load into Docker (optional)
docker load -i result

# Push to registry (no Docker needed!)
./scripts/push-image.sh web

# Get remote image digest
./scripts/print-digest.sh ghcr.io/your-org/nix-sample-web:latest
```

## Documentation

For comprehensive documentation including:
- Prerequisites & installation
- Core concepts explained
- Step-by-step workflows
- CI/CD setup
- Troubleshooting
- Next steps

See **[LESSONS.md](./LESSONS.md)**

## Why This Stack?

### Nix
- **Reproducible:** Same input = same output (always)
- **Cross-platform:** Works on Linux & macOS
- **Declarative:** One file defines everything
- **Cacheable:** Binary caching speeds up builds

### Turborepo
- **Fast:** Only builds what changed
- **Cached:** Never rebuild the same thing twice
- **Parallel:** Runs tasks concurrently
- **Simple:** JSON configuration

### skopeo (Docker-free!)
- **Lightweight:** No daemon, just a CLI tool
- **Fast:** Direct tar-to-registry copies
- **Secure:** No privileged operations needed
- **Flexible:** Works with any OCI registry

## Deployment

The CI workflow generates image digests. Use them for deterministic deployments:

```bash
# Get digest from CI artifacts
WEB_DIGEST=$(cat digests/web.txt)

# Deploy to ECS (example)
aws ecs update-service \
  --cluster my-cluster \
  --service web \
  --force-new-deployment \
  --task-definition my-task:$WEB_DIGEST

# Deploy to Kubernetes (example)
kubectl set image deployment/web \
  web=ghcr.io/your-org/nix-sample-web@$WEB_DIGEST
```

## Customization

### Add a New App

```bash
mkdir -p apps/new-app
cd apps/new-app
pnpm init

# Add to root package.json workspaces
# Add to turbo.json tasks
# Create .envrc for auto-loading environment
```

### Change Node Version

Edit `flake.nix`:

```nix
node = pkgs.nodejs_20;  # Change to any available version
```

### Add Nix Packages

Edit `flake.nix`:

```nix
nodeTools = [
  node
  pkgs.pnpm
  pkgs.redis       # Add Redis
  pkgs.postgresql  # Add PostgreSQL
];
```

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run `pnpm build && pnpm test && pnpm lint`
5. Open a pull request

## License

MIT

## Learn More

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Turborepo Docs](https://turbo.build/repo/docs)
- [skopeo Documentation](https://github.com/containers/skopeo)
- [devenv Guide](https://devenv.sh/)

---

Built with Nix, Turborepo, and TypeScript.
