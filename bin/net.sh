interface_name="ens33"
before="$(cat /proc/net/dev | grep $interface_name | awk -F' ' '{printf "%s %s %s",$1,$2,$10}')"
sleep 1
after="$(cat /proc/net/dev | grep $interface_name | awk -F' ' '{printf "%s %s %s",$1,$2,$10}')"

speed=$(( ($(echo $after | cut -d' ' -f 2) - $(echo $before | cut -d' ' -f 2)) ))
if [[ $speed -ge $(( 1024 * 1024 )) ]]; then
    echo "[$interface_name $(( $speed / 1024 / 1024 ))MB/s]"
elif [[ $speed -ge $(( 1024 )) ]]; then
    echo "[$interface_name $(( $speed / 1024 ))KB/s]"
else
    echo "[$interface_name $(( $speed))B/s]"
fi

