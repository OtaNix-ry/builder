{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
      devenv-test = self.devShells.${system}.default.config.test;

      default = pkgs.dockerTools.buildImage {
        fromImage = pkgs.dockerTools.pullImage {
          imageName = "lnl7/nix";
          imageDigest = "sha256:05618c7f8c1e6750dddd12f6c737a9c6043815474576dabeafc46e08d0be1c21";
          sha256 = "0sfrgv45fp1hksgf2yq7dh1ib1r3g98ddxq64f2pm8z74707kmr6";
          finalImageName = "lnl7/nix";
          finalImageTag = "ssh";
        };

        name = "ghcr.io/otanix-ry/builder";
        tag = "latest";
        created = "now";

        # FIXME: actually build this image from scratch
        config.Cmd = ["/nix/store/f772niv2vajba3fr7xhh3infynyxr7c7-openssh-8.3p1/bin/sshd" "-D" "-e" "-E" "/var/sshd_log"];

        copyToRoot = pkgs.buildEnv {
          name = "ssh-auth";
          paths = [
            (pkgs.writeTextFile
              {
                name = "authorized_keys";
                destination = "/root/.ssh/authorized_keys";
                text = builtins.readFile ./authorized_keys;
              })
          ];
          pathsToLink = ["/root"];
        };
      };
    });

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
            }
          ];
        };
      });
  };
}
