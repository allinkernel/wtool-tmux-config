#! /usr/bin/zsh
msg=""
mount | grep -P 'ext[2-4]|f2fs|exfat|ntfs|drvfs|vfat' | while read line; do
    mount_point=$(echo $line |awk -F' ' '{printf "%s",$3}')
    usage_info=$(df -h | grep -P "${mount_point}$" | awk -F' ' '{printf "%s/%s",$3,$2}')
    msg="${msg} ${mount_point}:${usage_info}"
done
/bin/echo -n "${msg}"
