{ stdenvNoCC, fetchurl, nodejs, lib }:

# ccusage を nix で配布する小さな derivation。
#
# ryoppippi/ccusage は pnpm monorepo で nixpkgs 未収載のため、npm registry
# が publish する tarball (`dist/cli.js` 単一バンドル) を fetchurl で取得し、
# nodejs 絶対パス指定のシェルラッパーを書き出すだけの軽量パッケージ。
#
# 設計メモ:
# - shebang は upstream のまま `#!/usr/bin/env node` だが、本ラッパーで
#   `${nodejs}/bin/node` を直接呼ぶため PATH 上の別 node を拾わない。
# - PATH に `bun` があれば ccusage 自身が `dist/main.bun.js` 経路で
#   自己 re-exec する (README: "CCUSAGE_BUN_AUTO_RUN=0 で無効化")。
#   castle は home.packages に `bun` を持つので warm 起動が自動で乗る。
# - 更新手順: 新 version の sha256 は
#     nix-prefetch-url --type sha256 \
#       https://registry.npmjs.org/ccusage/-/ccusage-<ver>.tgz
#   で取得して下の `version` / `hash` を差し替える。
# - engines.node >= 22 が要求されるが、castle の `nodejs` は v24 LTS。

stdenvNoCC.mkDerivation rec {
  pname = "ccusage";
  version = "19.0.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
    hash = "sha256-FBMdx4DEymkE79f4zZNfbnm8C1nulTz9i/9d3x07bIQ=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/ccusage $out/bin
    cp -R . $out/lib/ccusage/

    cat > $out/bin/ccusage <<EOF
    #!/bin/sh
    exec ${nodejs}/bin/node $out/lib/ccusage/dist/cli.js "\$@"
    EOF
    chmod +x $out/bin/ccusage

    runHook postInstall
  '';

  meta = with lib; {
    description = "Analyze coding (agent) CLI token usage and costs from local data";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "ccusage";
  };
}
