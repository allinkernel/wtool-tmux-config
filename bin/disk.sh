#!/bin/sh
# disk.sh —— tmux 状态栏：磁盘。POSIX sh。
#
# 数据源：`df -P -k`（POSIX 格式：一行一个文件系统；-k = 1024 字节块）。
#   **不解析 `df -h` 的人类可读列** —— 那正是 mem.sh 旧版负数的同一个坑
#   （G/M 单位混在一起做减法/比较）。这里全程 kB 整数，最后才换算。
#
# 只认这些（设备名 = df 第一列）：
#   /dev/sd*  /dev/nvme*  /dev/vd*  /dev/mmcblk*  /dev/dm-*  /dev/xvd*
#   /dev/mapper/*      ← LVM；df 常报 /dev/mapper/vg-lv（dm-* 的符号链接）
#   [A-Za-z]:\         ← **WSL 的 DrvFs**（df 里 C:\ → /mnt/c）。旧版就显示
#                         C:/D:/E:，删掉会让 WSL 用户凭空少看这几块盘；
#                         只认"盘符 + 冒号"的整卷，不认 drivers/none。
# 其余一律不认：overlay / tmpfs / udev / devtmpfs / squashfs / rootfs / none /
#   /dev/loop* / snapfuse … 连白名单都进不来 —— **不靠"排除名单"**
#   （排除名单永远会漏掉下一个伪文件系统）。
#
# 没有匹配到任何设备 → 输出 []（**不是错误**，rc=0）。
# Docker 的根是 overlay（不是块设备，按设备列不出来），这时 [] 什么信息都没有；
#   判据：**一个白名单设备都没有**（单文件的 bind mount 已被排除，见循环里那段），
#   且 `df` 里挂载点是 "/" 的那一行，filesystem **恰好是 overlay / overlayfs**
#   → 输出 `[/:<可用>]`（例如 `[/:300G]`）。只对 overlay 这么做：
#   tmpfs/udev/squashfs 即使挂在 / 也不冒充磁盘，输出仍然是 []。
#
# 有设备时：`挂载点:已用/总量`，多项空格分隔；总长 > 40 字节时改用简写
#   `设备:可用`（旧版"太长只印简写"的行为，status-left 只有 90 列）。
#   磁盘单位用 1024 进制（和 `df -h` 一致；mem.sh 用 SI 是因为旧版走 free --si）。

# kB（整数）→ 人类可读的 1024 进制单位。只接受非负整数。
human_kb() {
    _kb=$1
    case $_kb in
        ''|*[!0-9]*) printf '?'; return 0 ;;
    esac
    if [ "$_kb" -eq 0 ]; then
        printf '0B'
        return 0
    fi
    if [ "$_kb" -ge 1073741824 ]; then
        _v=$((_kb / 1073741824)); _d=$(((_kb % 1073741824) / 107374182))
        if [ "$_d" -eq 0 ]; then printf '%sT' "$_v"; else printf '%s.%sT' "$_v" "$_d"; fi
    elif [ "$_kb" -ge 1048576 ]; then
        _v=$((_kb / 1048576)); _d=$(((_kb % 1048576) / 104857))
        if [ "$_d" -eq 0 ]; then printf '%sG' "$_v"; else printf '%s.%sG' "$_v" "$_d"; fi
    elif [ "$_kb" -ge 1024 ]; then
        printf '%sM' "$((_kb / 1024))"
    else
        printf '%sK' "$_kb"
    fi
}

# 先把 df 抓下来：用 here-doc 喂 while，循环体在当前 shell 里跑
# （`df | while` 的循环在子 shell 里，msg 会丢 —— 旧版靠 zsh 的"管道最后一段
#   在当前 shell"才没暴露，换 dash 就变成 []）。
df_out=$(df -P -k 2>/dev/null) || df_out=

long=''
short=''
root_dev=''
root_avail=''

while IFS=' ' read -r dev blocks used avail cap mnt; do
    [ -n "${dev:-}" ] || continue
    [ -n "${mnt:-}" ] || continue
    # 表头 / 异常行：块数不是纯数字就跳过（"1024-blocks"、"Used" 都在这里被挡掉）
    case $blocks in ''|*[!0-9]*) continue ;; esac
    case $used   in ''|*[!0-9]*) continue ;; esac
    case $avail  in ''|*[!0-9]*) continue ;; esac

    if [ "$mnt" = "/" ]; then
        root_dev=$dev
        root_avail=$avail
    fi

    # 单文件的 bind mount 不是"磁盘"：Docker 默认把 /etc/hosts、/etc/hostname、
    # /etc/resolv.conf 从宿主 bind 进来，df 里它们指向宿主根盘（/dev/sdd 之类）。
    # 不跳过的话，容器里永远显示宿主那块盘的可用量，overlay 根的兜底反而走不到。
    if [ -f "$mnt" ]; then
        continue
    fi

    case $dev in
        /dev/sd*|/dev/nvme*|/dev/vd*|/dev/mmcblk*|/dev/dm-*|/dev/xvd*|/dev/mapper/*)
            ;;
        [A-Za-z]:\\*)   # WSL DrvFs：C:\ / D:\ …
            ;;
        *)
            continue
            ;;
    esac

    _u=$(human_kb "$used")
    _t=$(human_kb "$blocks")
    _a=$(human_kb "$avail")
    long="$long ${mnt}:${_u}/${_t}"
    case $dev in
        [A-Za-z]:\\*) short="$short ${dev}${_a}" ;;   # 旧版 WSL 的写法：C:\18G
        *)            short="$short ${dev}:${_a}" ;;
    esac
done <<EOF
$df_out
EOF

long=${long# }
short=${short# }

if [ -n "$long" ]; then
    if [ "${#long}" -gt 40 ]; then
        printf '[%s]' "$short"
    else
        printf '[%s]' "$long"
    fi
    exit 0
fi

# 没有白名单设备：只有 Docker 的 overlay 根给一个"根分区可用量"兜底
case $root_dev in
    overlay|overlayfs) printf '[/:%s]' "$(human_kb "$root_avail")" ;;
    *)                 printf '[]' ;;
esac
