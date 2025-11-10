{
  description = "Turborepo TypeScript monorepo with Nix: reproducible dev shells + OCI images";

  # Inputs are external dependencies for this flake
  inputs = {
    # nixpkgs: The main Nix package repository (using unstable for latest packages)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # flake-utils: Helper for generating outputs for multiple systems (linux, darwin, etc.)
    flake-utils.url = "github:numtide/flake-utils";

    # devenv: Framework for creating reproducible development environments
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, flake-utils, devenv, ... }@inputs:
    # Generate outputs for all default systems (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import nixpkgs for the current system
        pkgs = import nixpkgs { inherit system; };
        lib = nixpkgs.lib;

        # Pin Node.js version across the entire monorepo for consistency
        node = pkgs.nodejs_22;

        # Common tools needed for Node.js development
        nodeTools = [
          node                 # Node.js runtime
          pkgs.corepack        # Package manager manager (enables pnpm)
          pkgs.pnpm            # pnpm package manager (fast, space-efficient)
          pkgs.jq              # JSON processor (useful for CI scripts)
          pkgs.git             # Version control
          pkgs.skopeo          # OCI image manipulation tool (no Docker needed)
        ];

        # Get the absolute path to the repo root for devenv state management
        # This ensures devenv writes its state inside the checkout, not in /tmp
        repoRoot = let pwd = builtins.getEnv "PWD"; in
          if (pwd != "" && lib.hasPrefix "/" pwd) then pwd
          else builtins.throw "Run with --impure or via direnv: `use flake . --impure`";

        # --- Source Preparation ---
        # Copy app sources into Nix store for image building
        # This creates a clean, reproducible source tree
        srcWeb = pkgs.runCommand "src-web" {} ''
          mkdir -p $out
          cp -R ${self}/apps/web/* $out/
        '';

        srcApi = pkgs.runCommand "src-api" {} ''
          mkdir -p $out
          cp -R ${self}/apps/api/* $out/
        '';

        # --- OCI Image Builders (Docker-free) ---
        # These images are built entirely by Nix using dockerTools
        # No Docker daemon required - outputs are OCI-compliant tar archives

        imageWeb = pkgs.dockerTools.buildImage {
          name = "nix-sample-web";
          tag = "latest";

          # Include Node.js in the image
          contents = [ node pkgs.bash pkgs.corepack ];

          # Commands to run during image creation (NOT at runtime)
          # This sets up the filesystem structure
          extraCommands = ''
            mkdir -p app
            cp -R ${srcWeb}/* app/
          '';

          # Runtime configuration
          config = {
            WorkingDir = "/app";
            # Use bash as entrypoint for flexibility
            Entrypoint = [ "bash" "-lc" ];
            # Install deps and start the app at runtime
            # For production: prebuild node_modules or use Next.js standalone mode
            Cmd = [ "corepack enable && pnpm install --frozen-lockfile && pnpm start" ];
            Env = [ "NODE_ENV=production" ];
            ExposedPorts = { "3000/tcp" = {}; };
          };
        };

        imageApi = pkgs.dockerTools.buildImage {
          name = "nix-sample-api";
          tag = "latest";
          contents = [ node pkgs.bash pkgs.corepack ];
          extraCommands = ''
            mkdir -p app
            cp -R ${srcApi}/* app/
          '';
          config = {
            WorkingDir = "/app";
            Entrypoint = [ "bash" "-lc" ];
            Cmd = [ "corepack enable && pnpm install --frozen-lockfile && node dist/index.js" ];
            Env = [ "NODE_ENV=production" ];
            ExposedPorts = { "3001/tcp" = {}; };
          };
        };

      in {
        # --- Development Shells ---
        # These provide isolated, reproducible dev environments per app
        # Enter with: nix develop .#dev-web or via direnv

        devShells.dev-web = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({ pkgs, config, lib, ... }: {
              # Configure devenv to use our repo root for state
              devenv.root = repoRoot;

              # Install all Node.js tools
              packages = nodeTools;

              # Set environment variables for this shell
              env = {
                NODE_ENV = "development";
              };

              # Message printed when entering the shell
              enterShell = ''
                echo "🚀 Web App Dev Environment"
                echo "Node: $(node -v) | pnpm: $(pnpm -v)"
                echo ""
                echo "Quick start:"
                echo "  cd apps/web && pnpm install && pnpm dev"
              '';
            })
          ];
        };

        devShells.dev-api = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({ pkgs, config, lib, ... }: {
              devenv.root = repoRoot;
              packages = nodeTools;
              env = {
                NODE_ENV = "development";
              };
              enterShell = ''
                echo "🚀 API Dev Environment"
                echo "Node: $(node -v) | pnpm: $(pnpm -v)"
                echo ""
                echo "Quick start:"
                echo "  cd apps/api && pnpm install && pnpm dev"
              '';
            })
          ];
        };

        # Default shell (for general monorepo work)
        devShells.default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({ pkgs, config, lib, ... }: {
              devenv.root = repoRoot;
              packages = nodeTools;
              env = {
                NODE_ENV = "development";
              };
              enterShell = ''
                echo "🚀 Nix + Turborepo Monorepo"
                echo "Node: $(node -v) | pnpm: $(pnpm -v)"
                echo ""
                echo "Available commands:"
                echo "  pnpm dev    - Start all dev servers"
                echo "  pnpm build  - Build all apps"
                echo "  pnpm test   - Run all tests"
                echo "  pnpm image  - Build OCI images with Nix"
                echo ""
                echo "App-specific shells:"
                echo "  nix develop .#dev-web"
                echo "  nix develop .#dev-api"
              '';
            })
          ];
        };

        # --- Build Outputs ---
        # These are the artifacts that can be built with: nix build .#<name>
        packages = {
          # OCI images (output: result -> tar archive)
          image-web = imageWeb;
          image-api = imageApi;

          # Default: build both images
          default = pkgs.symlinkJoin {
            name = "all-images";
            paths = [ imageWeb imageApi ];
          };
        };
      }
    );
}
