{ pkgs ? import <nixpkgs> {}
, system ? builtins.currentSystem
}:

let
  node2nixOutput = import ./default.nix {
    inherit pkgs system;
  };

  # Old revision of nixos-unstable to get a specific version (0.4.24)
  # of the Solidity compiler, required for building azimuth-solidity.
  oldNixpkgsForSolidity = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0bcbb978795bab0f1a45accc211b8b0e349f1cdb.tar.gz";
    sha256 = "0c3mpc5z7ilgpgr9rhn42vmwhygza6n2yg7lyhgjf0yym4prnxn9";
  }) { inherit system; };

  overriddenOutput = builtins.mapAttrs (name: value: value.override {
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
in
overriddenOutput // {}
