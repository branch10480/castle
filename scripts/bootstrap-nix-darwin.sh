#!/usr/bin/env bash
# nix-darwin の初回 switch を実行する。
# - flake は ~/.config/nix-darwin（castle/config/nix-darwin の symlink 先）を参照
# - hostname -s に一致する darwinConfiguration が無ければ `default` にフォールバック
set -euo pipefail

FLAKE_DIR="${HOME}/.config/nix-darwin"
HOST="$(hostname -s)"

if [[ ! -e "${FLAKE_DIR}/flake.nix" ]]; then
  echo "error: ${FLAKE_DIR}/flake.nix が見つかりません。homeshick link castle を実行してください。" >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "error: nix コマンドが見つかりません。先に Nix をインストールしてください。" >&2
  echo "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install" >&2
  exit 1
fi

# 既存ホスト名にマッチする設定があるか確認
# (`builtins.hasAttr` で attribute 存在のみを真偽評価する)
if nix eval --raw \
     --extra-experimental-features 'nix-command flakes' \
     --apply "cfgs: if builtins.hasAttr \"${HOST}\" cfgs then \"yes\" else \"no\"" \
     "${FLAKE_DIR}#darwinConfigurations" 2>/dev/null | grep -q '^yes$'; then
  TARGET="${HOST}"
else
  echo "warn: darwinConfigurations.${HOST} が未定義のため default を使用します。" >&2
  TARGET="default"
fi

echo "==> nix-darwin switch (target: ${TARGET})"
# nix-darwin は activation に root 権限を要求する。sudo でラップする。
if command -v darwin-rebuild >/dev/null 2>&1; then
  sudo darwin-rebuild switch --flake "${FLAKE_DIR}#${TARGET}"
else
  # 初回は darwin-rebuild が未配置なので nix run で起動
  sudo nix run --extra-experimental-features 'nix-command flakes' \
    nix-darwin -- switch --flake "${FLAKE_DIR}#${TARGET}"
fi
