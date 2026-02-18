#! /usr/bin/zsh
echo -n "["
echo -n "M:$(free --si -h | grep '^Mem:'  | awk -F' ' '{printf "%sG",$2 - $3}')"
echo -n " "
echo -n "S:$(free --si -h | grep '^Swap:' | awk -F' ' '{printf "%sG",$2 - $3}')"
echo -n "]"

