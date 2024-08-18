
# 向每个终端都发送一个指令，这里是判断当前是zsh还是bash，然后把对应的配置文件source进来

zsh_all () {
    tmux list-panes -s | cut -d: -f 1  | xargs -I{} tmux send-keys -t {} '[[ -z $BASH ]] && source ~/.zshrc' C-m
}

bash_all () {
    tmux list-panes -s | cut -d: -f 1  | xargs -I{} tmux send-keys -t {} '[[ -n $BASH ]] && source ~/.bashrc' C-m
}
