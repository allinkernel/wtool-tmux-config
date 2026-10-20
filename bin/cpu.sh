#!/bin/sh
# cpu.sh —— tmux 状态栏：CPU 指示（POSIX sh，不依赖 zsh/bash）。
#
# 口径：[C:<1 分钟负载 / 在线 CPU 数 × 100>%]
#   /proc/loadavg 第一列是 1 分钟平均**可运行进程数**（load），不是百分比；
#   除以在线 CPU 数才是"每核负载"，乘 100 当占用率显示：
#     单核 load 0.45 → 45%；8 核 load 0.45 → 5%。
#   旧版直接把 load 当百分比（`[C:%s%%]`），在 32 核机器上永远显示 "0.x%"
#   —— 不是"CPU 很闲"，是口径错了。
#   不用 top：status-interval=1，每秒 fork 一次 top 太重；loadavg 是内核维护的，
#   读一个文件就够，而且 WSL1 / 容器里都有。
#
# 在线 CPU 数三级兜底：getconf _NPROCESSORS_ONLN → nproc → /proc/stat 的 cpuN 行。
# 可选参数：<loadavg 文件>（**测试用**；tmux 不传，默认 /proc/loadavg）。
# 可选环境变量：WTOOL_NCPU（**测试/兜底用**；正常机器不需要）。

loadavg=${1:-/proc/loadavg}
ncpu=${WTOOL_NCPU:-}
case $ncpu in
    ''|*[!0-9]*|0) ncpu= ;;
esac
if [ -z "$ncpu" ]; then
    ncpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null) || ncpu=
    case $ncpu in
        ''|*[!0-9]*|0) ncpu= ;;
    esac
fi
if [ -z "$ncpu" ]; then
    ncpu=$(nproc 2>/dev/null) || ncpu=
    case $ncpu in
        ''|*[!0-9]*|0) ncpu= ;;
    esac
fi
if [ -z "$ncpu" ]; then
    ncpu=$(awk -F: '/^cpu[0-9]+[[:space:]]/ { n++ } END { print n + 0 }' \
        /proc/stat 2>/dev/null) || ncpu=0
    case $ncpu in
        ''|*[!0-9]*|0) ncpu=1 ;;
    esac
fi

if [ ! -r "$loadavg" ]; then
    printf '[C:?]'
    exit 0
fi

# 上限 999%：状态栏只有 90 列，load 爆表时别把别的段挤掉。
# 末尾不换行 —— 三个脚本的输出会被 tmux 直接拼进 status-left。
LC_ALL=C awk -v n="$ncpu" '
    {
        p = $1 * 100 / n
        if (!(p >= 0)) p = 0
        if (p > 999) p = 999
        printf "[C:%d%%]", p
        seen = 1
        exit
    }
    END { if (!seen) printf "[C:?]" }
' "$loadavg"
