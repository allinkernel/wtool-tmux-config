/bin/echo -n "Mem: $(free --si -h | grep '^Mem:'  | awk -F' ' '{printf "%s/%s",$3,$2}')"
/bin/echo -n " "
/bin/echo -n "Swap: $(free --si -h | grep '^Swap:' | awk -F' ' '{printf "%s/%s",$3,$2}')"
