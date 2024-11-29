{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "juice";
  version = "1.5.7";
  src = fetchFromGitHub {
    owner = "paullouisageneau";
    repo = "libjuice";
    rev = "v${finalAttrs.version}";
    hash = "sha256-niMzFimcb+6FJq9ks7FJ2yrwJ7NnSEfj/bxLaPhdMDk=";
  };

  nativeBuildInputs = [ cmake ];

  meta = {
    dscription = "JUICE is a UDP Interactive Connectivity Establishment library";
    # license = lib.licenses.mpl;
    maintainers = [ lib.maintainers.shelvacu ];
    homepage = "https://github.com/paullouisageneau/libjuice?tab=readme-ov-file";
  };
})
