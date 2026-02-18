#! /usr/bin/zsh
msg=""
brief_msg=""
df -h | grep -P '^[C-Z]:\\|^/dev/sd[a-z][0-9]' | sort -r | while read line; do
    mount_point=$(echo $line |awk -F' ' '{printf "%s",$NF}')

    usage_info=$(df -h | grep -P "${mount_point}$" | awk -F' ' '{printf "%s/%s",$3,$2}')
    msg="${mount_point}:${usage_info} ${msg}"

    brief_usage_info=$(df -h | grep -P "${mount_point}$" | awk -F' ' '{printf "%s%s", $1, $4}')
    brief_msg="${brief_usage_info} ${brief_msg}"
done
if [[ $(echo -n "${msg}" | wc -c) -gt 40 ]]; then
    echo -n "[${brief_msg}]"
else
    echo -n "[${msg}]"
fi
