#!/usr/bin/env bash
# Windows Git Bash 版工具链入口（env.sh 的 PATH 用 E:/... 带冒号路径会被 MSYS 拆坏，这里用 /e/... 形式）。
# 用法：source scripts/env-win.sh
if [ -z "${DEVECO_HOME:-}" ]; then
  export DEVECO_HOME="E:/programapp/devcostudio/DevEco Studio"
fi
DEVECO_HOME_MSYS=$(cygpath -u "$DEVECO_HOME" 2>/dev/null || echo "$DEVECO_HOME")
export NODE_HOME="$DEVECO_HOME_MSYS/tools/node"
export OHPM_HOME="$DEVECO_HOME_MSYS/tools/ohpm"
export HARMONYOS_SDK_HOME="$DEVECO_HOME_MSYS/sdk"
export DEVECO_SDK_HOME="$DEVECO_HOME/sdk"
export HVIGOR_USER_HOME="${HVIGOR_USER_HOME:-$HOME/.hvigor}"
export PATH="$NODE_HOME:$OHPM_HOME/bin:$DEVECO_HOME_MSYS/tools/hvigor/bin:$HARMONYOS_SDK_HOME/default/openharmony/toolchains:$PATH"
echo "[env-win] node=$(node -v 2>/dev/null) ohpm=$(ohpm -v 2>/dev/null | tail -1) hvigorw=$(hvigorw --version 2>/dev/null | tail -1)"
