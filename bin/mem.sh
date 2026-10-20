#!/bin/sh
# mem.sh —— tmux 状态栏：可用内存 / 可用 swap。
#
# POSIX sh（dash / bash / busybox ash 都行）。tmux 的 #() 环境很干净
# （`env -i PATH=/usr/bin:/bin` 就是典型），所以不能依赖 zsh/bash。
#
# ── 旧版在 Ubuntu 上为什么打出负数（根因）────────────────────────────────
# 旧版这一行：
#     free --si -h | grep '^Mem:' | awk -F' ' '{printf "%sG",$2 - $3}'
# `free --si -h` 给的是**带单位后缀的人类可读数**：内存大时是 "4.1G"，
# 用得少时是 "604M"。awk 把 $2 - $3 当数字算，**后缀不参与单位换算**：
#     4.1 - 604 = -599.9  →  printf "%sG"  →  "-599.9G"
# WSL 上 total/used 恰好都落在 G 档（26G - 6.5G = 19.5），所以看不出来；
# 一台 4 GB 的 Ubuntu 虚拟机 used 是 604M，就立刻变成负数。
# 错的不是 shell，是**拿人类可读字符串做减法**。
#
# ── 新版口径 ─────────────────────────────────────────────────────────────
#   · 一律读 /proc/meminfo 的 kB 整数，最后一步才换算成人类可读；
#   · 可用内存优先 MemAvailable（内核 3.14+，和 free 的 available 同源）；
#     没有它才退到 MemFree + Buffers + Cached（老 free 的口径）；
#   · 可用 swap = SwapFree；
#   · 所有输入先校验成非负整数、再夹到 MemTotal / SwapTotal 以内，
#     **绝不输出负数**；真算不出来就输出 ?（不拿 0 冒充）。
#
# 输出：[M:<可用> S:<可用swap>]，SI 单位（和旧版 free --si 一致）。
#       ⚠️ /proc/meminfo 的 "kB" 是 **KiB（1024 字节）**，所以换算先乘 1024
#       变成字节、再按 10^9 / 10^6 分档，否则会比 free --si 小 2.4%
#       （67108864 kB 是 68.7G，不是 67.1G）。
#       例：[M:19.3G S:68.7G]；0 是 0B；读不到 meminfo 是 [M:? S:?]。
#
# 可选参数：<meminfo 文件>（**测试用**；tmux 不传，默认 /proc/meminfo）。

meminfo=${1:-/proc/meminfo}

if [ ! -r "$meminfo" ]; then
    printf '[M:? S:?]'
    exit 0
fi

# 只接受 1..12 位十进制数字：12 位 kB ≈ 999 TB，超过它肯定不是真实内存，
# 当"不可信"处理（也避免 64 位算术在边界上的实现差异）。负数/带单位/空 → 不合法。
num_ok() {
    case ${1:-} in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "${#1}" -le 12 ]
}

# meminfo 的 kB（KiB）→ 人类可读的 SI 单位。只接受非负整数，负数不会走到这里。
# 先换算成字节：1 kB(meminfo) = 1024 B，然后 1G = 10^9 B（--si 口径）。
human_si() {
    _kb=$1
    case $_kb in
        ''|*[!0-9]*) printf '?'; return 0 ;;
    esac
    if [ "$_kb" -eq 0 ]; then
        printf '0B'
        return 0
    fi
    _b=$((_kb * 1024))
    if [ "$_b" -ge 1000000000000 ]; then
        _v=$((_b / 1000000000000)); _d=$(((_b % 1000000000000) / 100000000000))
        if [ "$_d" -eq 0 ]; then printf '%sT' "$_v"; else printf '%s.%sT' "$_v" "$_d"; fi
    elif [ "$_b" -ge 1000000000 ]; then
        _v=$((_b / 1000000000)); _d=$(((_b % 1000000000) / 100000000))
        if [ "$_d" -eq 0 ]; then printf '%sG' "$_v"; else printf '%s.%sG' "$_v" "$_d"; fi
    elif [ "$_b" -ge 1000000 ]; then
        _v=$((_b / 1000000)); _d=$(((_b % 1000000) / 100000))
        if [ "$_d" -eq 0 ]; then printf '%sM' "$_v"; else printf '%s.%sM' "$_v" "$_d"; fi
    elif [ "$_b" -ge 1000 ]; then
        printf '%sK' "$((_b / 1000))"
    else
        printf '%sB' "$_b"
    fi
}

mem_total=0   have_total=0
mem_avail=0   have_avail=0
mem_free=0    have_free=0
buffers=0
cached=0
swap_total=0
swap_free=0   have_swap=0

while read -r key val _rest; do
    case $key in
        MemTotal:)     mem_total=$val;   have_total=1 ;;
        MemAvailable:) mem_avail=$val;   have_avail=1 ;;
        MemFree:)      mem_free=$val;    have_free=1 ;;
        Buffers:)      buffers=$val ;;
        Cached:)       cached=$val ;;
        SwapTotal:)    swap_total=$val ;;
        SwapFree:)     swap_free=$val;   have_swap=1 ;;
    esac
done < "$meminfo"

# 任何一项不合法就丢掉它（绝不把 "-5" / "1.2G" 这类东西带进算术）
if ! num_ok "$mem_total";  then mem_total=0;  have_total=0;  fi
if ! num_ok "$mem_avail";  then mem_avail=0;  have_avail=0;  fi
if ! num_ok "$mem_free";   then mem_free=0;   have_free=0;   fi
if ! num_ok "$buffers";    then buffers=0;                   fi
if ! num_ok "$cached";     then cached=0;                    fi
if ! num_ok "$swap_total"; then swap_total=0;                fi
if ! num_ok "$swap_free";  then swap_free=0;  have_swap=0;   fi

avail_kb=''
if [ "$have_avail" -eq 1 ]; then
    avail_kb=$mem_avail
elif [ "$have_free" -eq 1 ]; then
    avail_kb=$((mem_free + buffers + cached))
fi

# 夹到 MemTotal 以内：MemAvailable 偶尔会比 MemTotal 大（内核/虚拟化口径差异），
# 兜底那三项相加也可能超过 MemTotal —— 显示"比总内存还多"比负数更误导。
if [ -n "$avail_kb" ] && [ "$have_total" -eq 1 ] && [ "$mem_total" -gt 0 ] \
        && [ "$avail_kb" -gt "$mem_total" ]; then
    avail_kb=$mem_total
fi
# 兜底相加最多 3×12 位；再长就不可信了，显示 ? 而不是一个荒唐的大数
if [ -n "$avail_kb" ] && [ "${#avail_kb}" -gt 12 ]; then
    avail_kb=''
fi

if [ -n "$avail_kb" ]; then
    mem_out=$(human_si "$avail_kb")
else
    mem_out='?'
fi

if [ "$have_swap" -eq 1 ]; then
    if [ "$swap_total" -gt 0 ] && [ "$swap_free" -gt "$swap_total" ]; then
        swap_free=$swap_total
    fi
    swap_out=$(human_si "$swap_free")
elif [ "$have_total" -eq 1 ] && [ "$swap_total" -eq 0 ]; then
    # meminfo 里没有 Swap* 行 = 这台机器没有 swap；确认 meminfo 可读才这样判
    swap_out='0B'
else
    swap_out='?'
fi

printf '[M:%s S:%s]' "$mem_out" "$swap_out"
