# 由 ~/.zshrc 里的 wtool 块 source。
#
# 加载器保证以下变量已存在，所以这里不需要任何 get_this_dir 之类的路径魔法：
#   WTOOL_PROJECT_ID    例如 terminal/tmux
#   WTOOL_PROJECT_DIR   $HOME/.wtool/links/terminal/tmux（稳定中转链接）
#   WTOOL_PROJECT_ROOT  仓库的真实路径

export WTOOL_TMUX_DIR="$WTOOL_PROJECT_DIR"

# 显式入口：强制使用本项目的配置（~/.tmux.conf 已由 link 指向同一份）
alias tmux-wtool='command tmux -f "$WTOOL_TMUX_DIR/tmux.conf"'
