#!/usr/bin/env bash
# terminal/tmux 的测试：
#   ① 清单/配置形状：wtool.xml 与 tmux.conf 符合 ADR-0045 的新链接模型
#      （① 类纯源码项目：没有 <link>、没有 <export_*>、配置直接读源码路径）；
#   ② env.zsh 和 env.bash 必须给出同样的变量、同样的 tmux() 行为
#      —— **同一张用例表跑两个 shell**（有人机器上没有 zsh）。
#
#   bash tests/env_test.sh
#
# 只读、不碰真 $HOME（WTOOL_HOME 指向临时目录，PATH 前面挂一个 tmux 桩）、不联网。
# 没装 zsh 就只测 bash（bash 版存在的意义就是"没有 zsh 的机器"）。
set -u

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
proj=$(cd -- "$here/.." && pwd)

pass=0; fail=0
ok ()  { pass=$((pass + 1)); printf '  ok   %s\n' "$*"; }
bad () { fail=$((fail + 1)); printf '  FAIL %s\n' "$*"; }
chk () { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$3] 实际 [$2]）"; fi; }

# 环境里已经存在的 WTOOL_* 全部清掉再跑用例：外面那套（今天还指着老的
# wtool-work-dir/links）会盖住被测文件的默认值，让断言测到别的东西。
# 判据写法见用户级 ~/.dsh/AGENTS.md：env | sed -n 's/^\(WTOOL[A-Z_]*\)=.*/-u \1/p'
unset_args=()
while IFS= read -r v; do
    [ -n "$v" ] && unset_args+=(-u "$v")
done < <(env | sed -n 's/^\(WTOOL[A-Z_]*\)=.*/\1/p')

# 全程在临时目录里：WTOOL_HOME 指向它，绝不读写真的 ~/.wtool
T=$(mktemp -d "${TMPDIR:-/tmp}/tmux-env-test.XXXXXX") || exit 1
trap 'rm -rf -- "$T"' EXIT INT TERM
wh="$T/wh"; mkdir -p "$wh"
# tmux() 包装函数指向的那份配置文件（测的是"传了哪些参数"，文件本身只要在）
conf="$wh/wtool/terminal/tmux/tmux.conf"
mkdir -p "$(dirname -- "$conf")"; : > "$conf"
# tmux 桩：把收到的参数一行打一个 —— 用来观察包装函数到底怎么调 tmux
stub="$T/bin"; mkdir -p "$stub"
cat > "$stub/tmux" <<'EOF'
#!/bin/sh
for a in "$@"; do printf '%s\n' "$a"; done
EOF
chmod +x "$stub/tmux"

printf '== 清单与配置（ADR-0045 新模型）==\n'

[ -r "$proj/tmux.conf" ] && ok "tmux.conf 在（包装函数指向它）" || bad "tmux.conf 不在"

# <link> 的解析已被引擎删掉（D3，不留兼容期）：留着它 `wtool install` 直接报错
# （只认**行首**的元素；注释里提到 <link> 不算）
if grep -qE '^[[:space:]]*<link([[:space:]>]|$)' "$proj/wtool.xml"; then
    bad "wtool.xml 里还有 <link>（D3 已删掉解析，install 会报错）"
else
    ok "wtool.xml 没有 <link>（D3）"
fi

# 两个 shell 各一份 env，都要声明（只声明一份 = 另一个 shell 的用户 command not found）
if grep -q 'src="env.zsh"' "$proj/wtool.xml" && grep -q 'src="env.bash"' "$proj/wtool.xml"; then
    ok "wtool.xml 两份 env 都声明了（zshrc / bashrc）"
else
    bad "wtool.xml 没把 env.zsh / env.bash 都声明上"
fi

# ① 类不写 <export_*> / <generate>：源码即产物，不渲染、不生成（D46）
if grep -qE '^[[:space:]]*<(export_bin|export_usr|muslbin|generate)([[:space:]>]|$)' "$proj/wtool.xml"; then
    bad "wtool.xml 里有 ②③ 类才用的标签（① 类不写 <export_*>，D46）"
else
    ok "wtool.xml 里没有 <export_*> / <generate>（① 类，D46）"
fi

# 老的中转链接目录已废弃（ADR-0045：L1 链取代 wtool-work-dir/links）
if grep -q 'wtool-work-dir/links' "$proj/tmux.conf"; then
    bad "tmux.conf 里还有废弃的 wtool-work-dir/links 路径"
else
    ok "tmux.conf 不再引用 wtool-work-dir/links"
fi
if grep -q 'wtool-work-dir/links' "$proj/env.zsh" "$proj/env.bash"; then
    bad "env.zsh / env.bash 里还有废弃的 wtool-work-dir/links 路径"
else
    ok "env.zsh / env.bash 不再引用 wtool-work-dir/links"
fi

# 状态栏三个脚本要走 L1 路径 $WTOOL_HOME/wtool/terminal/tmux/bin/（ADR-0045 §3.6）
missing=""
for s in mem cpu disk; do
    grep -q "\$WTOOL_HOME/wtool/terminal/tmux/bin/$s.sh" "$proj/tmux.conf" || missing="$missing $s.sh"
done
if [ -z "$missing" ]; then
    ok "tmux.conf 状态栏走 \$WTOOL_HOME/wtool/terminal/tmux/bin/{mem,cpu,disk}.sh"
else
    bad "tmux.conf 状态栏缺这几个脚本的 L1 路径：$missing"
fi

# ---------------------------------------------------------------------------
# 两个 shell：同一张表
# ---------------------------------------------------------------------------
for sh in bash zsh; do
    if ! command -v "$sh" >/dev/null 2>&1; then
        echo "== env.$sh：跳过（没装 $sh）=="
        continue
    fi
    echo "== env.$sh =="

    sh_eval () {   # <片段>：在干净环境里 source 一份 env 再跑片段
        env "${unset_args[@]}" WTOOL_HOME="$wh" WTOOL_PROJECT_DIR="$proj" PATH="$stub:$PATH" \
            "$sh" -c "set -u; source \"$proj/env.$sh\"; $1" 2>&1
    }

    chk "$sh：WTOOL_TMUX_DIR 指到项目目录" \
        "$(sh_eval 'printf "%s\n" "$WTOOL_TMUX_DIR"')" "$proj"

    out=$(sh_eval 'alias tmux-wtool')
    case $out in
        *"-f"*"tmux.conf"*) ok "$sh：tmux-wtool 用本项目的配置" ;;
        *) bad "$sh：tmux-wtool 别名不对 [$out]" ;;
    esac

    # tmux() 包装函数（D10）：一张表跑两个 shell，期望 = 传给 tmux 的参数（一行一个）
    while IFS= read -r row; do
        case $row in ''|'#'*) continue ;; esac
        IFS='|' read -r -a parts <<< "$row"
        frag=${parts[0]}
        exp=""
        for p in "${parts[@]:1}"; do
            p=${p//<CONF>/$conf}
            exp="${exp}${exp:+
}${p}"
        done
        chk "$sh：$frag" "$(sh_eval "$frag")" "$exp"
    done <<'TABLE'
tmux|-f|<CONF>
tmux -V|-f|<CONF>|-V
tmux new -s work|-f|<CONF>|new|-s|work
tmux -S "sock name"|-f|<CONF>|-S|sock name
command tmux -V|-V
TABLE

    # WTOOL_HOME 校验（D48）：未设置 / 空串 / 目录不在 → 非 0 退出 + 点名 rc 里那两行
    for spec in 未设置 空串 目录不在; do
        case $spec in
            未设置)   vout=$(env "${unset_args[@]}" "$sh" "$proj/env.$sh" 2>&1); vrc=$? ;;
            空串)     vout=$(env "${unset_args[@]}" WTOOL_HOME= "$sh" "$proj/env.$sh" 2>&1); vrc=$? ;;
            目录不在) vout=$(env "${unset_args[@]}" WTOOL_HOME="$T/no-such-home" "$sh" "$proj/env.$sh" 2>&1); vrc=$? ;;
        esac
        vmess="WTOOL_HOME"
        case $vout in
            *"WTOOL_HOME 未设置或不存在"*) ;;
            *) vmess="错误文字" ;;
        esac
        case $vout in
            *'export WTOOL_HOME=~/.wtool'*'source ${WTOOL_HOME}/env.'"$sh"*) ;;
            *) vmess="$vmess + 两行提示" ;;
        esac
        if [ "$vrc" -ne 0 ] && [ "$vmess" = "WTOOL_HOME" ]; then
            ok "$sh：WTOOL_HOME $spec → 报错退出（rc=$vrc）+ 提示两行"
        else
            bad "$sh：WTOOL_HOME $spec 的校验不对（rc=$vrc，缺 $vmess）：$vout"
        fi
    done

    # 校验不过时**不许**再往下装：WTOOL_TMUX_DIR 必须没有定义
    out=$(env "${unset_args[@]}" "$sh" -c \
        "source \"$proj/env.$sh\"; printf '[%s]\n' \"\${WTOOL_TMUX_DIR:-UNSET}\"" 2>/dev/null)
    chk "$sh：校验不过就不往下装（WTOOL_TMUX_DIR 未设置）" "$out" "[UNSET]"

    # 刻意**不**断言"不设 WTOOL_PROJECT_DIR 也能 source"：env 文件是 wtool install
    # 的块 source 的，装上了这个变量一定在；没它项目本来就装不上
    # （用户 2026-10-04 拍板，删掉了原来那条断言）。
done

# ---------------------------------------------------------------------------
# 状态栏脚本（2026-10-20）：POSIX sh，VMware Ubuntu / WSL / docker overlay 三种环境
#
# 为什么测这些：tmux 的 #() 环境很干净（`env -i PATH=/usr/bin:/bin`），
# 而旧版三个脚本一个没有 shebang、两个是 `#!/usr/bin/zsh` —— 装了 wtool 版 zsh
# 的机器上 `/usr/bin/zsh` 不存在，`#()` 直接 rc=127；mem.sh 还会打出负数
# （free --si -h 的 G/M 后缀被 awk 当纯数字相减）。这里把这三类回归钉住。
# ---------------------------------------------------------------------------
printf '== 状态栏脚本（POSIX sh / 三种环境）==\n'
bin="$proj/bin"
sb_scripts='cpu.sh mem.sh disk.sh'

# ① shebang 与 zsh 依赖
for s in $sb_scripts; do
    chk "$s 的 shebang 是 #!/bin/sh" "$(sed -n '1p' "$bin/$s")" '#!/bin/sh'
done
if grep -REn '^#!.*zsh' "$bin" >/dev/null 2>&1; then
    bad "bin/ 里还有 zsh 的 shebang：$(grep -REn '^#!.*zsh' "$bin" | tr '\n' ' ')"
else
    ok "bin/ 里没有任何 #!...zsh（tmux 的 #() 不保证有 /usr/bin/zsh）"
fi

# ② 语法：sh -n + dash -n（dash 没装就跳过，和上面 zsh 那条一样）
for s in $sb_scripts; do
    if sh -n "$bin/$s" 2>/dev/null; then ok "$s 过 sh -n"; else bad "$s 过不了 sh -n"; fi
    if command -v dash >/dev/null 2>&1; then
        if dash -n "$bin/$s" 2>/dev/null; then ok "$s 过 dash -n"; else bad "$s 过不了 dash -n"; fi
    else
        echo "  skip $s 的 dash -n（没装 dash）"
    fi
done

# ③ tmux 的 #() 环境：直接 exec（走 shebang），rc=0 且输出非空
for s in $sb_scripts; do
    out=$(env -i PATH=/usr/bin:/bin "$bin/$s" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
        ok "$s 在 env -i 下 rc=0 且有输出（$out）"
    else
        bad "$s 在 env -i 下 rc=$rc，输出 [$out]"
    fi
done

# 用 dash 真跑一遍（sh -n 过 ≠ dash 跑得起来）
if command -v dash >/dev/null 2>&1; then
    for s in $sb_scripts; do
        out=$(env -i PATH=/usr/bin:/bin dash "$bin/$s" 2>&1); rc=$?
        if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
            ok "$s 在 dash 下真跑 rc=0（$out）"
        else
            bad "$s 在 dash 下真跑 rc=$rc，输出 [$out]"
        fi
    done
fi

# ④ mem.sh：合成 /proc/meminfo。**任何一条都不许出现负号。**
mid="$T/meminfo"; mkdir -p "$mid"
cat > "$mid/normal" <<'EOF'
MemTotal:       16384000 kB
MemFree:         2000000 kB
MemAvailable:    8192000 kB
Buffers:          100000 kB
Cached:          1000000 kB
SwapTotal:       2097152 kB
SwapFree:        2097152 kB
EOF
cat > "$mid/noavail" <<'EOF'
MemTotal:        8000000 kB
MemFree:         3000000 kB
Buffers:          100000 kB
Cached:           900000 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/tiny" <<'EOF'
MemTotal:          204800 kB
MemAvailable:       20480 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/clamp" <<'EOF'
MemTotal:         1000000 kB
MemAvailable:     2000000 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/zero" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:          0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/hugebad" <<'EOF'
MemTotal:       16384000 kB
MemAvailable: 999999999999999 kB
MemFree:         1048576 kB
Buffers:               0 kB
Cached:                0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/hugevalid" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:  999999999999 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
cat > "$mid/negfield" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:         -5 kB
MemFree:         1048576 kB
Buffers:               0 kB
Cached:                0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF

mem_case() {   # <标签> <meminfo 文件> <期望输出>
    out=$(env -i PATH=/usr/bin:/bin sh "$bin/mem.sh" "$2" 2>&1)
    case $out in
        *-*) bad "mem.sh[$1] 输出里有负号：$out" ;;
        *)   ok "mem.sh[$1] 没有负数" ;;
    esac
    chk "mem.sh[$1]" "$out" "$3"
}
mem_case normal    "$mid/normal"    '[M:8.3G S:2.1G]'
mem_case noavail   "$mid/noavail"   '[M:4G S:0B]'
mem_case tiny      "$mid/tiny"      '[M:20.9M S:0B]'
mem_case clamp     "$mid/clamp"     '[M:1G S:0B]'
mem_case zero      "$mid/zero"      '[M:0B S:0B]'
mem_case hugebad   "$mid/hugebad"   '[M:1G S:0B]'
mem_case hugevalid "$mid/hugevalid" '[M:16.7G S:0B]'
mem_case negfield  "$mid/negfield"  '[M:1G S:0B]'
chk "mem.sh 读不到 meminfo → [M:? S:?]" \
    "$(env -i PATH=/usr/bin:/bin sh "$bin/mem.sh" "$mid/no-such-file" 2>&1)" '[M:? S:?]'

# ⑤ disk.sh：合成 df（**不是**合成 /proc）。df 桩从 $DF_FIXTURE 读那份输出。
dff="$T/dfbin"; mkdir -p "$dff" "$T/df"
cat > "$dff/df" <<'EOF'
#!/bin/sh
cat "${DF_FIXTURE:?}"
EOF
chmod +x "$dff/df"
disk_case() { env -i PATH="$dff:/usr/bin:/bin" DF_FIXTURE="$1" sh "$bin/disk.sh"; }

cat > "$T/df/vm" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sda1 1048576 524288 524288 50% /boot
/dev/nvme0n1p2 20971520 10485760 10485760 50% /
/dev/vda1 5242880 1048576 4194304 20% /data
/dev/mmcblk0p1 1048576 1048576 0 100% /mnt/sd
/dev/dm-0 10485760 5242880 5242880 50% /var
/dev/xvda1 2097152 1048576 1048576 50% /x
/dev/mapper/vg-root 4194304 1048576 3145728 25% /srv
overlay 1000000 500000 500000 50% /var/lib/docker/overlay2/abc
tmpfs 65536 0 65536 0% /run
udev 65536 0 65536 0% /dev
squashfs 128 128 0 100% /snap/foo
/dev/loop0 65536 65536 0 100% /snap/loop
EOF
cat > "$T/df/overlay" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted on
overlay 1055762868 687716444 314342952 69% /
tmpfs 65536 0 65536 0% /run
udev 65536 0 65536 0% /dev
squashfs 128 128 0 100% /snap/foo
/dev/loop0 65536 65536 0 100% /snap/loop
EOF
cat > "$T/df/tmpfs" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted on
tmpfs 65536 0 65536 0% /
udev 65536 0 65536 0% /dev
EOF
cat > "$T/df/wsl" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted on
none 12818488 0 12818488 0% /usr/lib/modules/x
drivers 243104764 223649032 19455732 92% /usr/lib/wsl/drivers
/dev/sdd 1055762868 687705952 314353444 69% /
C:\ 243104764 223649032 19455732 92% /mnt/c
D:\ 1073741820 798426480 275315340 75% /mnt/d
tmpfs 12818488 0 12818488 0% /run/qemu
EOF
cat > "$T/df/filebind" <<'EOF'
Filesystem 1024-blocks Used Available Capacity Mounted on
overlay 1055762868 687716444 314342952 69% /
/dev/sdd 1055762868 687705952 314353444 69% /etc/hosts
/dev/sdd 1055762868 687705952 314353444 69% /etc/hostname
tmpfs 65536 0 65536 0% /dev/shm
EOF
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n' > "$T/df/empty"

out=$(disk_case "$T/df/vm"); rc=$?
chk "disk.sh VM 白名单 rc" "$rc" 0
for want in /dev/sda1 /dev/nvme0n1p2 /dev/vda1 /dev/mmcblk0p1 /dev/dm-0 /dev/xvda1 /dev/mapper/vg-root; do
    case $out in
        *"$want"*) ok "disk.sh 收录 $want" ;;
        *)         bad "disk.sh 漏了 $want（$out）" ;;
    esac
done
for no in overlay tmpfs udev squashfs loop0 snap; do
    case $out in
        *"$no"*) bad "disk.sh 误报 $no（$out）" ;;
        *)       ok "disk.sh 不误报 $no" ;;
    esac
done

out=$(disk_case "$T/df/overlay"); rc=$?
chk "disk.sh docker overlay 根 → 根分区可用量" "$out" '[/:299.7G]'
chk "disk.sh docker overlay rc" "$rc" 0
case $out in
    *overlay*|*tmpfs*|*udev*|*squashfs*|*loop0*)
        bad "disk.sh 把 overlay 的伪设备当磁盘了（$out）" ;;
    *) ok "disk.sh overlay 兜底里没有伪设备名字" ;;
esac

chk "disk.sh 根是 tmpfs → []（不冒充磁盘）" "$(disk_case "$T/df/tmpfs")" '[]'
chk "disk.sh 只有表头 → []" "$(disk_case "$T/df/empty")" '[]'

out=$(disk_case "$T/df/wsl")
for want in '/dev/sdd' 'C:\' 'D:\'; do
    case $out in
        *"$want"*) ok "disk.sh WSL 收录 $want" ;;
        *)         bad "disk.sh WSL 漏了 $want（$out）" ;;
    esac
done
for no in none drivers; do
    case $out in
        *"$no"*) bad "disk.sh WSL 误报 $no（$out）" ;;
        *)       ok "disk.sh WSL 不误报 $no" ;;
    esac
done

chk "disk.sh 跳过单文件 bind（/etc/hosts）→ overlay 根" \
    "$(disk_case "$T/df/filebind")" '[/:299.7G]'

# ⑥ cpu.sh：1 核 / 8 核 / 2 核各一条，外加真实 /proc/loadavg 与文件不存在
la="$T/loadavg"
printf '0.50 0.40 0.30 1/100 1234\n' > "$la"
chk "cpu.sh 单核 load 0.50 → 50%" \
    "$(env -i PATH=/usr/bin:/bin WTOOL_NCPU=1 sh "$bin/cpu.sh" "$la")" '[C:50%]'
chk "cpu.sh 8 核 load 0.50 → 6%" \
    "$(env -i PATH=/usr/bin:/bin WTOOL_NCPU=8 sh "$bin/cpu.sh" "$la")" '[C:6%]'
printf '3.00 2.00 1.00 1/100 1234\n' > "$T/loadavg3"
chk "cpu.sh 2 核 load 3.00 → 150%" \
    "$(env -i PATH=/usr/bin:/bin WTOOL_NCPU=2 sh "$bin/cpu.sh" "$T/loadavg3")" '[C:150%]'
out=$(env -i PATH=/usr/bin:/bin sh "$bin/cpu.sh")
case $out in
    \[C:*%\]) ok "cpu.sh 真实 /proc/loadavg → $out" ;;
    *)        bad "cpu.sh 真实 /proc/loadavg 输出不对（$out）" ;;
esac
chk "cpu.sh loadavg 不存在 → [C:?]" \
    "$(env -i PATH=/usr/bin:/bin sh "$bin/cpu.sh" "$T/no-such-loadavg" 2>&1)" '[C:?]'

printf '\n%d 通过, %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
