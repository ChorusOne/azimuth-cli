{ stdenv, lib, fetchzip, fetchFromGitHub, boost, cmake, z3 }:

let
  version = "0.4.24";
  rev = "e67f0147998a9e3835ed3ce8bf6a0a0c634216c5";
  sha256 = "1gy2miv6ia1z98zy6w4y03balwfr964bnvwzyg8v7pn2mayqnaap";
  jsoncppURL = "https://github.com/open-source-parsers/jsoncpp/archive/1.9.3.tar.gz";
  jsoncpp = fetchzip {
    url = jsoncppURL;
    hash = "sha256-mBLBwuIYPonclPyEdFywi7W70WpOqnKEy4q/PECJcO0=";
  };
in
stdenv.mkDerivation {
  name = "solc-${version}";

  src = fetchFromGitHub {
    owner = "ethereum";
    repo = "solidity";
    inherit rev sha256;
  };

  patches = [
    ./patches/shared-libs-install.patch
    ./patches/gcc8.patch
    ./patches/gcc11.patch
    ./patches/boost169.patch
    ./patches/boost177.patch
    ./patches/disable-Werror.patch
    ./patches/jsoncpp-macos.patch
  ];

  postPatch = ''
    touch prerelease.txt
    echo >commit_hash.txt "${rev}"
    substituteInPlace cmake/jsoncpp.cmake --replace "${jsoncppURL}" ${jsoncpp}
  '';

  cmakeFlags = [
    "-DBoost_USE_STATIC_LIBS=OFF"
    "-DBUILD_SHARED_LIBS=ON"
    "-DINSTALL_LLLC=ON"
  ];

  doCheck = stdenv.hostPlatform.isLinux && stdenv.hostPlatform == stdenv.buildPlatform;
  checkPhase = "LD_LIBRARY_PATH=./libsolc:./libsolidity:./liblll:./libevmasm:./libdevcore:$LD_LIBRARY_PATH " +
               "./test/soltest --show-progress=true -- --no-ipc --no-smt --testpath ../test";

  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost z3 ];

  outputs = [ "out" "dev" ];

  meta = with lib; {
    description = "Compiler for Ethereum smart contract language Solidity";
    longDescription = "This package also includes `lllc', the LLL compiler.";
    homepage = https://github.com/ethereum/solidity;
    license = licenses.gpl3;
    platforms = with platforms; linux ++ darwin;
    maintainers = with maintainers; [ dbrock akru ];
    inherit version;
  };
}
