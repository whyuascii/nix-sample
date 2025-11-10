{
  description = "devenv shell (no services yet)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url      = "github:cachix/devenv";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, devenv, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = devenv.lib.mkShell {
          inherit inputs pkgs;

          modules = [
            ({ pkgs, ... }: {
              # Make devenv write .devenv into your real checkout, not /nix/store
              devenv.root = let pwd = builtins.getEnv "PWD"; in if pwd == "" then "." else pwd;

              languages.ruby.enable = true;
              languages.ruby.package = pkgs.ruby_3_3;

              packages = with pkgs; [
                bundler git jq curl wget nodejs_22 yarn imagemagick vips postgresql redis
              ];

              services.postgres = {
                enable = true;
                package = pkgs.postgresql_16;
                initialDatabases = [ { name = "photoquest_development"; } ];
                listen_addresses = "127.0.0.1";
                # settings.port = 5433;  # uncomment if 5432 is busy
              };

              services.redis.enable = true;

              env = {
                RAILS_ENV = "development";
                DATABASE_URL = "postgres://localhost/photoquest_development"; # add :5433 if you change port
                REDIS_URL = "redis://127.0.0.1:6379";
              };

              enterShell = ''
                echo "[step7] ruby: $(ruby -v)"
                echo "[step7] DB:   $DATABASE_URL"
                echo "[step7] Redis:$REDIS_URL"
              '';
            })
          ];

        };
      }
    );
}
