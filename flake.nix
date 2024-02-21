{
  description = "Command line interface to Azimuth, the Urbit public key infrastructure";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  # Old revision of nixos-unstable to get a specific version (0.4.24)
  # of the Solidity compiler, required for building azimuth-solidity.
  inputs.oldNixpkgs.url = "nixpkgs/0bffda19b8af722f8069d09d8b6a24594c80b352";

  # The old revision of nixpkgs needed for solc is broken on many other systems
  inputs.systems.url = "github:nix-systems/x86_64-linux";
  inputs.flake-utils.inputs.systems.follows = "systems";

  outputs = { self, nixpkgs, oldNixpkgs, flake-utils, systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        oldPkgs = import oldNixpkgs { inherit system; };
        node2nixOutput = import ./default.nix { inherit pkgs system; };

        solc_0_4_24 = oldPkgs.callPackage ./solc_0_4_24 {
          boost = oldPkgs.boost177;
        };

        node2nixOutputOverride = builtins.mapAttrs (name: value: value.override {
          buildInputs = [
            pkgs.nodePackages.node-gyp-build
            solc_0_4_24
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
