# 重新定义tmux，强制其使用我的配置
export WSW_TMUX_CONF_DIR="$(get_this_dir)"
echo "WSW_TMUX_CONF_DIR is ${WSW_TMUX_CONF_DIR}"
tmux() {
    command tmux -f "${WSW_TMUX_CONF_DIR}/wsw.tmux.conf" "$@"
}
