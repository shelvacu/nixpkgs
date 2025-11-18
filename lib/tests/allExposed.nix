let
  lib = import ./..;

  expectExposed = [
    "trivial"
    "fixedPoints"

    "attrsets"
    "lists"
    "strings"
    "stringsWithDeps"

    "customisation"
    "derivations"
    # "generators"
    "meta"
    "filesystem"
    "sources"
    "modules"
    "options"
    "asserts"
    "debug"
    "misc"
  ];
in
lib.runTests {
  testLibFunctionsExposed = {
    expr = lib.flip lib.concatMap expectExposed (
      moduleName:
      let
        module = lib.${moduleName};
        remainingAttrs = lib.removeAttrs module (lib.attrNames lib);
      in
      lib.flip map (lib.attrNames remainingAttrs) (libFuncName:
        "lib.${moduleName}.${libFuncName} but no lib.${libFuncName}"
      )
    );
    expected = [ ];
  };
}
