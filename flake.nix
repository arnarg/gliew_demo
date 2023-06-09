{
  description = "A gliew demo website";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-gleam.url = "github:arnarg/nix-gleam";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-gleam,
  }: (
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-gleam.overlays.default
        ];
      };
    in {
      packages = rec {
        # Packaged applicatio
        default = pkgs.buildGleamApplication {
          src = ./.;
        };
        # Docker image
        image = pkgs.dockerTools.buildLayeredImage {
          name = "gliew_demo";
          tag = default.version;

          contents = with pkgs; [dockerTools.binSh coreutils procps];
          config = {
            Entrypoint = ["${default}/bin/gliew_demo"];
            Env = ["PATH=/bin"];
          };
        };
      };
    })
  );
}
