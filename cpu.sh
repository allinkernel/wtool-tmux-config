cat /proc/loadavg | awk -F' ' '{printf "[C:%s%%]",$1}'
