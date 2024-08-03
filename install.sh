#! /bin/bash
set -x
mypath=$(dirname $(realpath $0))

if [[ -e ~/.tmux.conf ]]; then
	mv ~/.tmux.conf ~/.tmux.conf.bak
fi
cp $mypath/.tmux.conf ~/.tmux.conf
mkdir -p ~/code/.config/tmux/mytools
cp $mypath/*.sh ~/.config/tmux/
tmux source-file ~/.tmux.conf
