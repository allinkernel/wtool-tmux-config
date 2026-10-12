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

printf '\n%d 通过, %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
