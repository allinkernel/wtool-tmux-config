#! /bin/bash
set -e
set -x
mypath=$(dirname $(realpath $0))

if [[ -e ~/.tmux.conf ]]; then
    mv ~/.tmux.conf ~/.tmux.conf.bak
fi
cp $mypath/.tmux.conf ~/.tmux.conf
mkdir -p ~/.config/tmux
cp $mypath/*.sh ~/.config/tmux/
if [[ -e /tmp/tmux-1000/default ]]; then
    tmux source-file ~/.tmux.conf
fi
