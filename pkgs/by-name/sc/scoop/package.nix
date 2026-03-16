{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  certificate-ripper,
  yt-dlp,
  playwright-test,
  playwright-driver,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "scoop";
  version = "0.6.59";

  src = fetchFromGitHub {
    owner = "harvard-lil";
    repo = "scoop";
    tag = finalAttrs.version;
    hash = "sha256-KcoTl2ehla6ALLrpAyfOqDioP5s3CGVfVhsj3Fbq6/Y=";
  };

  npmDepsHash = "sha256-lx+MxV8JDArDMQ0OV4eDXOTzd7xRfvvpAGJp+jPQPgs=";

  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  dontNpmBuild = true;

  postInstall = ''
    scoop_npm_dir="$out/lib/node_modules/@harvard-lil/scoop"
    ln -s /tmp "$scoop_npm_dir"/tmp

    (
      cd $out/lib/node_modules/@harvard-lil/scoop/node_modules
      rm -rf playwright playwright-core
      ln -s ${playwright-test}/lib/node_modules/playwright
      ln -s ${playwright-test}/lib/node_modules/playwright-core
    )

    # reimplementing what scoop does in $src/postinstall.sh
    exe_dir="$scoop_npm_dir/executables"
    mkdir -p "$exe_dir"
    ln -s ${lib.escapeShellArg (lib.getExe yt-dlp)} "$exe_dir"/yt-dlp
    ln -s ${lib.escapeShellArg (lib.getExe certificate-ripper)} "$exe_dir"/crip
  '';

  makeWrapperArgs = [
    "--set"
    "PLAYWRIGHT_BROWSERS_PATH"
    playwright-driver.browsers
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "High fidelity, browser-based, web archiving capture engine for witnessing the web";
    homepage = "https://github.com/harvard-lil/scoop";
    changelog = "https://github.com/harvard-lil/scoop/releases/tag/${finalAttrs.version}";
    license = with lib.licenses; [
      # from `find . -name 'package.json' -print0 | xargs -0 jq '.license' -r | sort -u` in the source dir after npm install
      bsd0
      agpl3Plus
      asl20
      blueOak100
      bsd2
      bsd3
      isc
      mit
      zlib
      psfl
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      # we don't know whats in those npm deps without digging
      binaryBytecode
      binaryNativeCode
    ];
    maintainers = [ lib.maintainers.shelvacu ];
    mainProgram = "scoop";
    platforms = lib.platforms.all;
  };
})
