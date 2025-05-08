{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  git,
  gmp,
  cadical,
  pkg-config,
  libuv,
  perl,
  testers,
}:
# lean wants to grab a copy of mimalloc's source with git and compile it along with lean, we patch it to do nothing and put the mimalloc source where it would've been downloaded to
stdenv.mkDerivation (finalAttrs: {
  pname = "lean4";
  version = "4.19.0";

  mainSrc = fetchFromGitHub {
    name = "lean";
    owner = "leanprover";
    repo = "lean4";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Iw5JSamrty9l6aJ2WwslAolSHfi2q0UO8P8HI1gp+j8=";
  };

  # From CMakeLists.txt in mainSrc
  mimallocVersion = "2.2.3";

  mimallocSrc = fetchFromGitHub {
    name = "mimalloc";
    owner = "microsoft";
    repo = "mimalloc";
    tag = "v${finalAttrs.mimallocVersion}";
    hash = "sha256-B0gngv16WFLBtrtG5NqA2m5e95bYVcQraeITcOX9A74=";
  };

  srcs = [
    finalAttrs.mainSrc
    finalAttrs.mimallocSrc
  ];

  patches = [
    ./no-download.patch
  ];

  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'set(GIT_SHA1 "")' 'set(GIT_SHA1 "${finalAttrs.mainSrc.tag}")'

    # Remove tests that fails in sandbox.
    # It expects `sourceRoot` to be a git repository.
    rm -rf src/lake/examples/git/
  '';

  sourceRoot = ".";

  postUnpack = ''
    mkdir -p lean/build/mimalloc/src
    mv mimalloc lean/build/mimalloc/src
    cd lean
  '';

  preConfigure = ''
    patchShebangs stage0/src/bin/ src/bin/
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    gmp
    libuv
    cadical
  ];

  nativeCheckInputs = [
    git
    perl
  ];

  cmakeFlags = [
    "-DUSE_GITHASH=OFF"
    "-DINSTALL_LICENSE=OFF"
  ];

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      version = "v${finalAttrs.version}";
    };
  };

  meta = with lib; {
    description = "Automatic and interactive theorem prover";
    homepage = "https://leanprover.github.io/";
    changelog = "https://github.com/leanprover/lean4/blob/${finalAttrs.mainSrc.tag}/RELEASES.md";
    license = licenses.asl20;
    platforms = platforms.all;
    maintainers = with maintainers; [
      danielbritten
      jthulhu
    ];
    mainProgram = "lean";
  };
})
