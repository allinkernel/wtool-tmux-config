cat /proc/loadavg | awk -F' ' '{printf "CPU:%s%%",$1}'
