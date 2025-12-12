import os
import requests
import re
import subprocess
import sys
import tempfile
import json
from pathlib import Path

MAJOR_VERSION = 140


def get_tags() -> list[str]:
    token = os.environ.get("GITHUB_TOKEN")
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    response = requests.get(
        "https://api.github.com/repos/Betterbird/thunderbird-patches/tags",
        headers=headers,
    )
    if response.status_code != 200:
        raise RuntimeError(f"Failed to fetch release info: {response.status_code} ({response.json().get('message')})")
    tag_data = response.json()
    return [x["name"] for x in tag_data]


def run(*cmd: str | Path, **kwargs) -> str:
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=None,
        stdin=subprocess.DEVNULL,
        text=True,
        **kwargs,
    )
    (stdout_data, _) = proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(f"Failed to run command: {cmd!r} exited with code {proc.returncode}")
    return stdout_data.strip()


def convert_hash_to_sri(base32: str) -> str:
    return run("nix-hash", "--to-sri", "--type", "sha256", base32)


def main() -> int:
    self_path = Path(sys.argv[1]).absolute()
    nixpkgs_path = self_path.parent.parent.parent.parent

    print(f"{self_path=} {nixpkgs_path=}", file=sys.stderr)

    def nix_eval(attrpath: str) -> str:
        return run("nix-instantiate", "--eval", "--raw", "--attr", attrpath, nixpkgs_path)

    tags = get_tags()
    valid_tags = [tag for tag in tags if re.match(f"^{MAJOR_VERSION}\\..*-bb[0-9]+$", tag)]
    old_rev = nix_eval("betterbird-unwrapped.betterbird-patches.rev")
    if old_rev not in valid_tags:
        raise RuntimeError(f"Don't know how to update, current rev {old_rev!r} not in {valid_tags!r}")

    if valid_tags[-1] == old_rev:
        # nothing to do
        return 0

    new_rev = valid_tags[-1]

    old_url = nix_eval("betterbird-unwrapped.betterbird-patches.url")
    new_url = old_url.replace(old_rev, new_rev)

    new_hash = run("nix-prefetch-url", "--type", "sha256", new_url)
    new_sri = convert_hash_to_sri(new_hash)

    old_sri = nix_eval("betterbird-unwrapped.betterbird-patches.hash")

    package_nix = self_path / "package.nix"

    package_nix.write_text(package_nix.read_text().replace(old_rev, new_rev).replace(old_sri, new_sri))

    patchdata_fn = self_path / "patchdata.json"

    old_patchdata = json.loads(patchdata_fn.read_text())

    with tempfile.TemporaryDirectory() as tempdir_str:
        tempdir = Path(tempdir_str)
        result = tempdir / "result"
        run("nix-build", "--expr", "let pkgs = import <nixpkgs> { }; in pkgs.srcOnly { inherit (pkgs.betterbird-unwrapped) name version stdenv; src = pkgs.betterbird-unwrapped.betterbird-patches; }", "--out-link", result, env={"NIX_PATH": f"nixpkgs={nixpkgs_path}"})

        conf_fn = result / f"{MAJOR_VERSION}/{MAJOR_VERSION}.sh"
        conf = {}
        for line in conf_fn.read_text().split("\n"):
            line = line.strip()
            if line == "" or line[0] == "#":
                continue
            name, val = line.split("=", 1)
            conf[name] = val

        def update_src(conf_name: str, attr_path: str):
            old_rev = nix_eval(f"{attr_path}.rev")
            new_rev = conf[f"{conf_name}_REV"]
            hg_url = nix_eval(f"{attr_path}.url")

            old_sri = nix_eval(f"{attr_path}.hash")
            new_hash = run("nix-prefetch-hg", hg_url, new_rev)
            new_sri = convert_hash_to_sri(new_hash)
            package_nix.write_text(
                package_nix.read_text()
                .replace(old_rev, new_rev)
                .replace(old_sri, new_sri)
            )

        update_src("MOZILLA", "betterbird-unwrapped.src")
        update_src("COMM", "betterbird-unwrapped.comm-source")

        series_files = [
            result / f"{MAJOR_VERSION}/series",
            result / f"{MAJOR_VERSION}/series-moz",
        ]

        new_patchdata = []
        # for series file parsing see https://github.com/Betterbird/thunderbird-patches/blob/35d8ff09a760059eb115809c74e201c8d222c977/build/build.sh#L183
        for series_file in series_files:
            for line in series_file.read_text().split("\n"):
                line = line.split("##")[0]
                line = line.strip()
                if line == "" or line.startswith("#"):
                    continue
                if " # " not in line:
                    continue

                patch_name, url = [x.strip() for x in line.split(" # ", 1)]
                url = url.replace("/rev/", "/raw-rev/")

                known_patches = [d for d in old_patchdata if d["url"] == url and d["name"] == patch_name]
                if known_patches:
                    known_patch = known_patches[0]
                    new_patchdata.append(known_patch)
                else:
                    patch_hash = run("nix-prefetch-url", "--type", "sha256", url)
                    patch_sri = convert_hash_to_sri(patch_hash)
                    new_patchdata.append({
                        "name": patch_name,
                        "url": url,
                        "hash": patch_sri,
                    })

        patchdata_fn.write_text(json.dumps(new_patchdata))

    return 0


if __name__ == "__main__":
    sys.exit(main())
