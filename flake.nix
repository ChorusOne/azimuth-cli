{
  description = "Command line interface to Azimuth, the Urbit public key infrastructure";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.nixpkgs2505.url = "nixpkgs/nixos-25.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, nixpkgs2505, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgs2505 = import nixpkgs2505 { inherit system; };
        node2nixOutput = import ./default.nix { inherit pkgs system; };

        # The Azimuth smart contracts in package azimuth-solidity need a specific version
        # of the solidity compiler (0.4.24). By default the build tries to download a binary
        # from the internet, but that is blocked by the Nix sandbox. Instead we install the
        # compiler as a system package and patch the config to use the system compiler.
        #
        # The solc 0.4.24 derivation is taken from an old revision of nixpkgs and modified
        # to allow it to build with more recent versions of the C compiler and Boost library.
        # https://github.com/NixOS/nixpkgs/tree/5095e9e32eacfcc794227bfe4fd45d5e60285f73/pkgs/development/compilers/solc
        solc_0_4_24 = pkgs.callPackage ./solc_0_4_24 {
          boost = pkgs.boost177;
          cmake = pkgs2505.cmake;
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
