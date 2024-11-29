{
  lib,
  stdenv,
  fetchFromGitHub,

  juice,
  curl,
}:
stdenv.mkDerivation {
  name = "coopnet";
  version = "unstable-2024-11-19";

  src = fetchFromGitHub {
    owner = "Isaac0-dev";
    repo = "coopnet";
    rev = "1801e043c0087e7fc01974abfbe162b280495fd7";
    hash = "sha256-uXUfBoN/2o82lq+7s+tcK3Lw2ibQEJ+5RkJQX9VYLgQ=";
  };

  patches = [ ./fix-libs.patch ];

  buildInputs = [ juice curl ];

  # env.NIX_DEBUG = "4";

  makeFlags = [
    "LIBS=-ljuice"
    "OSX_BUILD=${if stdenv.targetPlatform.isDarwin then "1" else "0"}"
  ];

  makeTarget = "dynlib";

  preBuild = ''
    # remove pre-built/vendored dependencies
    rm -r lib
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{lib,include}
    cp bin/libcoopnet.so $out/lib
    cp common/libcoopnet.h $out/include

    runHook postInstall
  '';

  meta = {
    description = "library for sm64coopdx to connect to other players";
  };
}
