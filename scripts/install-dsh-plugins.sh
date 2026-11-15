#!/usr/bin/env bash
# 为 DeepSeek Harness 的 web profile 自动安装插件。
#
# 背景：这台机器上 `dsh plugin add` 会踩到 pnpm 的 panic
#   "current dir is an absolute path with drive letter"（exit 9），
# 所以本脚本优先直连 npm 安装到 profile 目录，只有在 npm 失败时才回退到 dsh 命令。
#
# 用法：
#   ./scripts/install-dsh-plugins.sh                 # 安装默认插件清单
#   ./scripts/install-dsh-plugins.sh dshmarket foo   # 只装指定插件（可带 @version）
#   DSH_PROFILE=desktop ./scripts/install-dsh-plugins.sh
#
# 幂等：已安装且版本满足要求时跳过，不会重复拉包。

set -uo pipefail

DSH_PROFILE="${DSH_PROFILE:-web}"
PROFILE_DIR="$HOME/.dsh/profiles/$DSH_PROFILE"
DEFAULT_PLUGINS=(
    "dshmarket"            # 插件市场：可视化浏览/安装插件
    "dsh-prompt"           # 提示词管理
    "dsh-prompt-history"   # 提示词历史
    "dsh-mole"             # 代码调试辅助
)

if [ ! -d "$PROFILE_DIR" ]; then
    echo "错误：找不到 profile 目录 $PROFILE_DIR" >&2
    echo "先运行一次 dsh web（或 dsh --profile $DSH_PROFILE），让它生成 profile 再重试。" >&2
    exit 1
fi

if [ "$#" -gt 0 ]; then
    PLUGINS=("$@")
else
    PLUGINS=("${DEFAULT_PLUGINS[@]}")
fi

echo "Profile : $DSH_PROFILE ($PROFILE_DIR)"
echo "Plugins : ${PLUGINS[*]}"
echo

ok=0
fail=0
for spec in "${PLUGINS[@]}"; do
    name="${spec%@*}"
    printf '==> %-28s ' "$spec"

    # 已安装且版本一致 → 跳过
    if [ -f "$PROFILE_DIR/node_modules/$name/package.json" ]; then
        cur="$(node -p "require('$PROFILE_DIR/node_modules/$name/package.json').version" 2>/dev/null || echo unknown)"
        if [ -z "${spec#*@}" ] || [ "$spec" = "$name" ] || [ "$cur" = "${spec#*@}" ]; then
            echo "已安装 ($cur)，跳过"
            ok=$((ok + 1))
            continue
        fi
    fi

    # 主路径：npm 直装（--legacy-peer-deps 绕开 peer 依赖解析失败）
    if ( cd "$PROFILE_DIR" && npm install "$spec" --save --legacy-peer-deps --no-audit --no-fund >/tmp/losskill-dsh-install.log 2>&1 ); then
        ver="$(node -p "require('$PROFILE_DIR/node_modules/$name/package.json').version" 2>/dev/null || echo '?')"
        echo "OK ($ver)"
        ok=$((ok + 1))
        continue
    fi

    # 回退：官方 dsh 命令
    if dsh plugin --profile "$DSH_PROFILE" add "$spec" >/tmp/losskill-dsh-install.log 2>&1; then
        echo "OK (via dsh)"
        ok=$((ok + 1))
    else
        echo "失败（详见 /tmp/losskill-dsh-install.log）"
        tail -3 /tmp/losskill-dsh-install.log | sed 's/^/    /'
        fail=$((fail + 1))
    fi
done

echo
echo "完成：$ok 成功，$fail 失败。"
echo "让插件生效：重启 dsh web 进程（当前没有 --restart 参数），或刷新 http://127.0.0.1:3080"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
