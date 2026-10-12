# 由 $WTOOL_HOME/env.zsh 里的 wtool 块 source。与 env.bash 等价（bash 版见 env.bash）。
#
# 加载器保证以下变量已存在，所以这里不需要任何 get_this_dir 之类的路径魔法：
#   WTOOL_HOME          .wtool 根目录（**由 rc 里那行 export 声明**，ADR-0045 / D48）
#   WTOOL_PROJECT_ID    例如 terminal/tmux
#   WTOOL_PROJECT_DIR   $WTOOL_HOME/wtool/terminal/tmux（L1 链，ADR-0045 §1.3）
#   WTOOL_PROJECT_ROOT  仓库的真实路径
#
# WTOOL_HOME 不再自定位，所以这里只**校验**：空 / 目录不在 → 打印"请加哪两行"并报错，
# 绝不静默半装（D48 的判据；措辞与 pre_architecture.md §10.4 一致）。
if [ -z "${WTOOL_HOME:-}" ] || [ ! -d "$WTOOL_HOME" ]; then
    echo "wtool: WTOOL_HOME 未设置或不存在（当前值：'${WTOOL_HOME:-}'）。" >&2
    echo "       请在你的 ~/.zshrc 最后加上这两行（bash 用 env.bash）：" >&2
    echo "         export WTOOL_HOME=~/.wtool" >&2
    echo "         source \${WTOOL_HOME}/env.zsh" >&2
    return 1 2>/dev/null || exit 1
fi

# 单独 source（不经 wtool 块）时的兜底：L1 路径就是项目在 $WTOOL_HOME 里的稳定地址
[ -n "${WTOOL_PROJECT_DIR:-}" ] || WTOOL_PROJECT_DIR="$WTOOL_HOME/wtool/terminal/tmux"

export WTOOL_TMUX_DIR="$WTOOL_PROJECT_DIR"

# tmux 的入口（包装函数，ADR-0045 / D10）：**总是**用本项目这份 tmux.conf。
# 新模型里 $HOME 不再有 wtool 建的软链（原先那条 `~/.tmux.conf` 的 <link> 已删，D3）
# —— 装完"敲 tmux 就是这份配置"靠的就是这个函数。
# ⚠️ 只活在 source 过本文件的 shell 里：cron / systemd / `sh -c` 拿不到。
tmux() { command tmux -f "$WTOOL_HOME/wtool/terminal/tmux/tmux.conf" "$@"; }

# 历史遗留的显式名字；tmux() 出现后它与 `tmux` 完全等价（保留给老习惯/老脚本）
alias tmux-wtool='command tmux -f "$WTOOL_TMUX_DIR/tmux.conf"'
