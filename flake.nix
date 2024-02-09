{
  description = "Command line interface to Azimuth, the Urbit public key infrastructure";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  # The old revision of nixpkgs needed for solc is broken on many other systems
  inputs.systems.url = "github:nix-systems/x86_64-linux";
  inputs.flake-utils.inputs.systems.follows = "systems";

  outputs = { self, nixpkgs, flake-utils, systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        node2nixOutput = import ./default.nix { inherit pkgs system; };

        # Old revision of nixos-unstable to get a specific version (0.4.24)
        # of the Solidity compiler, required for building azimuth-solidity.
        #
        # This revision is too old to contain a flake.nix so it cannot go in the inputs
        oldNixpkgsForSolidity = import (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/0bcbb978795bab0f1a45accc211b8b0e349f1cdb.tar.gz";
          sha256 = "0c3mpc5z7ilgpgr9rhn42vmwhygza6n2yg7lyhgjf0yym4prnxn9";
        }) { inherit system; };

        node2nixOutputOverride = builtins.mapAttrs (name: value: value.override {
          buildInputs = [
            pkgs.nodePackages.node-gyp-build
            oldNixpkgsForSolidity.solc
          ];
          preRebuild = ''
            ## Fix paths in shebang lines ##
            find node_modules -path '*/node-gyp-build/bin.js' -exec sed -i -e "s|#!/usr/bin/env node|#! ${pkgs
      .nodejs}/bin/node|" '{}' '+'
            sed -i -e "s|#!/usr/bin/env node|#! ${pkgs.nodejs}/bin/node|" node_modules/truffle/build/cli.bundled.js

            ## Use the installed compiler rather than trying to download a binary ##
            sed -i -e 's/version: "0\.4\.24"/version: "native"/' node_modules/azimuth-solidity/truffle-config.js
          '';
        }) node2nixOutput;

        azimuth-cli = node2nixOutputOverride.package;
        app = flake-utils.lib.mkApp {
          drv = azimuth-cli;
          exePath = "/bin/azimuth-cli";
        };
        overlays = final: prev: { azimuth-cli = azimuth-cli; };
      in {
        packages.azimuth-cli = azimuth-cli;
        packages.default = azimuth-cli;
        apps.azimuth-cli = app;
        apps.default = app;
        nodeDependencies = node2nixOutputOverride.nodeDependencies;
        nodeShell = node2nixOutputOverride.shell;
        devShell = node2nixOutputOverride.shell;
        inherit overlays;
      }
  );
}
