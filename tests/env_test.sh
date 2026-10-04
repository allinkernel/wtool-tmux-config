#!/usr/bin/env bash
# terminal/tmux 的 env 测试：env.zsh 和 env.bash 必须给出同样的变量和别名。
#
#   bash tests/env_test.sh
#
# 没装 zsh 就只测 bash（bash 版存在的意义就是"没有 zsh 的机器"）。
set -u

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
proj=$(cd -- "$here/.." && pwd)

pass=0; fail=0
ok ()  { pass=$((pass + 1)); printf '  ok   %s\n' "$*"; }
bad () { fail=$((fail + 1)); printf '  FAIL %s\n' "$*"; }
chk () { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$3] 实际 [$2]）"; fi; }

[ -r "$proj/tmux.conf" ] && ok "tmux.conf 在（别名指向它）" || bad "tmux.conf 不在"

for sh in bash zsh; do
    if ! command -v "$sh" >/dev/null 2>&1; then
        echo "== env.$sh：跳过（没装 $sh）=="
        continue
    fi
    echo "== env.$sh =="
    sh_eval () {   # <片段>
        WTOOL_PROJECT_DIR="$proj" "$sh" -c "set -u; source \"$proj/env.$sh\"; $1" 2>&1
    }
    chk "$sh：WTOOL_TMUX_DIR 指到项目目录" \
        "$(sh_eval 'printf "%s\n" "$WTOOL_TMUX_DIR"')" "$proj"
    out=$(sh_eval 'alias tmux-wtool')
    case $out in
        *"-f"*"tmux.conf"*) ok "$sh：tmux-wtool 用本项目的配置" ;;
        *) bad "$sh：tmux-wtool 别名不对 [$out]" ;;
    esac
    # 刻意**不**断言"不设 WTOOL_PROJECT_DIR 也能 source"：env 文件是 wtool install
    # 的块 source 的，装上了这个变量一定在；没它项目本来就装不上
    # （用户 2026-10-04 拍板，删掉了原来那条断言）。
done

printf '\n%d 通过, %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
