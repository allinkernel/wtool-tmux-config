# architecture —— terminal/tmux（现状）

> 只写**现在长什么样**：为什么这么定看 `harness/docs/adr/0045-wtool-redesign/`，
> 接下来做什么看 `BACKLOG.md`。用户说明书是 `README.md`。

---

## 1. 这个项目是什么

**① 类纯源码项目**（`wtool.xml` 里 `kind` 缺省 = `source`，ADR-0045 §1.4）：

* 内容是**两份 env 片段 + 它自己的源码文件** —— `env.zsh` / `env.bash`、
  `tmux.conf`、`bin/{cpu,mem,disk,net}.sh`；
* **没有** `usr/`、`__output/`、`__release/`、`<export_*>`、`<generate>` ——
  「源码即产物」，**不渲染、不生成**（**D46**）；
* `<link>` 的解析已被引擎删掉（**D3**，不留兼容期）→ 本项目的 `wtool.xml`
  **只有两行声明**（`<zshrc>` / `<bashrc>`）。

判据（`tests/env_test.sh` 里跑的就是这几条）：

```sh
grep -nE '^[[:space:]]*<link([[:space:]>]|$)'  wtool.xml   # 无输出
grep -nE '^[[:space:]]*<(export_bin|export_usr|muslbin|generate)' wtool.xml   # 无输出
grep -n 'wtool-work-dir/links' tmux.conf env.zsh env.bash   # 无输出
```

## 2. 装完之后磁盘上是什么样

```
工作区（repo / bundle）                          $WTOOL_HOME（今天 = ~/.wtool）
~/self/wtool/terminal/tmux/                      ├── wtool/terminal/tmux ──L1──► 工作区那份目录
├── tmux.conf                                    │     （tmux.conf、bin/*.sh 就是从这里被读）
├── bin/*.sh                                     ├── env.zsh / env.bash
├── env.zsh / env.bash                           │     └── 里面一节 "# >>> wtool:terminal/tmux"，
└── wtool.xml（kind 缺省 = source）              │          source $WTOOL_PROJECT_DIR/env.{zsh,bash}
                                                 └── var/（账本：L1 链 + 两个 env 块）
$HOME 里：**什么都没有**（没有 ~/.tmux.conf；rc 里只有那两行 export/source）
```

* **L1 链**：`$WTOOL_HOME/wtool/terminal/tmux` → 工作区里的这个目录，**绝对路径**、按项目惰性建
  （D5/D11）。开发机上"改工作区的 `tmux.conf` = 改 `.wtool` 里那份"（同一条链）。
* **env 块**由引擎整份重算：按 `(priority, 路径)` 升序拼进 `$WTOOL_HOME/env.{zsh,bash}`
  （本项目 `priority=50`）。块里给三个变量：`WTOOL_PROJECT_ID`、`WTOOL_PROJECT_DIR`（= L1）、
  `WTOOL_PROJECT_ROOT`（L1 `readlink -f` 之后 = 工作区真实路径）。
* **没有 L2**：本项目不导出任何东西到 `$WTOOL_HOME/usr/…`（D46）——这是 ① 类与 ②③ 类的分界。

## 3. 运行时读哪儿

| 谁 | 读什么 | 怎么找到 |
|---|---|---|
| 敲 `tmux` | `$WTOOL_HOME/wtool/terminal/tmux/tmux.conf` | `env.*` 里的包装函数 `tmux() { command tmux -f "$WTOOL_HOME/wtool/terminal/tmux/tmux.conf" "$@"; }`（**D10**） |
| `tmux.conf` 的状态栏 | 同目录 `bin/{mem,cpu,disk}.sh` | `#(sh -c 'exec "$WTOOL_HOME/wtool/terminal/tmux/bin/mem.sh"')` 这类写法 |

`$WTOOL_HOME` 的来路（**2026-10-13 在 `ubuntu:24.04` + tmux 3.4 容器里实测**，
装了之后把整屏截下来看到 `[M:20G S:68G][C:0.75%][]`）：

1. tmux **读 conf 时**就把 `$WTOOL_HOME` 展开存进选项 ——
   `tmux show-options -g status-left` 看到的是绝对路径；
2. `#()` 由 **tmux server** fork 出来跑，环境 = server **启动那一刻**的环境；
   把客户端用 `env -u WTOOL_HOME` 剥干净再 attach，`#()` 里读到的仍是 server 那份。

⇒ **两条都吃 server 启动时的环境**：老 server（`export WTOOL_HOME` 之前起的）读不到，
`tmux kill-server` 重起即恢复；**改完 conf 本来也要重起 server 才生效**。
⇒ conf 里只认 `#(sh -c 'exec "$WTOOL_HOME/…"')` 这一种写法：实测 `${WTOOL_HOME:-默认}`
会让整行 `set` 失效（退回 tmux 默认 `status-left`），`\$WTOOL_HOME` 会把反斜杠留给 `sh`。
⇒ `tmux -f <文件不存在>` **不报错**，静默用默认配置（实测）——所以 `WTOOL_HOME` 指错
表现成"命令能跑、配置没在"。挡它的就是 env 里那段校验。

## 4. 两个 shell 的约定

`env.zsh` 与 `env.bash` **必须同改**，且只差三处（把两处 shell 名换成同一个词之后逐字节相同）：

```sh
diff <(sed 's/zsh/SH/g; s/bash/SH/g' env.zsh) <(sed 's/zsh/SH/g; s/bash/SH/g' env.bash)   # 无输出
```

两份都做这几件事（顺序有意义）：

1. **校验 `WTOOL_HOME`**（D48）：`[ -z "${WTOOL_HOME:-}" ] || [ ! -d "$WTOOL_HOME" ]` →
   打印"请在你的 `~/.zshrc`/`~/.bashrc` 最后加上这两行"+ `return 1 2>/dev/null || exit 1`。
   **这是本项目唯一会"半装"的地方，所以放最前面**：校验不过就什么都不定义。
2. `WTOOL_PROJECT_DIR` 兜底（单独 source 时）：没设就取 `$WTOOL_HOME/wtool/terminal/tmux`。
3. `export WTOOL_TMUX_DIR="$WTOOL_PROJECT_DIR"`（历史名字，保留）。
4. **`tmux()` 包装函数**（D10）—— 装完"敲 `tmux` 就是这份配置"靠它。
5. `alias tmux-wtool=…`（历史遗留；有了包装函数之后与直接敲 `tmux` 等价）。

`WTOOL_HOME` **不是** env 文件自己算的（D48 取消了自定位）：它由 rc 里
`export WTOOL_HOME=~/.wtool` 声明，env 只校验；换目录只改 rc 那一行。

## 5. 与今天的引擎的过渡状态（2026-10-13）

* 引擎里今天的 `WTOOL_HOME` 是**「被管理的家目录」**（默认 `$HOME`）—— 与新口径
  「`.wtool` 根目录」**同名不同义**（D47）。今天引擎写的 env 块是
  `WTOOL_PROJECT_DIR="$HOME/.wtool/wtool/terminal/tmux"`（旧口径），而本项目的包装函数
  用 `$WTOOL_HOME/wtool/terminal/tmux/tmux.conf`；只要 `WTOOL_HOME=~/.wtool`，
  两者就是**同一条物理路径** —— 改名那一轮引擎把它换成 `$WTOOL_HOME/…` 即可。
* 今天的 rc 里还没有 D48 那两行（老 wtool 块），所以**在改名/切换完成之前**，
  env 文件会照设计打印"请加这两行"的错并停下 —— 这是有意的：**绝不静默半装**。
* 装 / 测一律在容器里（D61）：`docker run --rm`，工作区只读挂进去，
  `WTOOL_HOME` / `WTOOL_STATE` 全指向临时目录。

## 6. 测试

```sh
bash tests/env_test.sh     # 29 条（2026-10-13 实测）：§1 的三条形状判据 + 两个 shell
                           # 同一张表（tmux() 传参、WTOOL_HOME 三种坏值的校验、别名、变量）
```

只读、不碰真 `$HOME`：`WTOOL_HOME` 指向 `mktemp -d`，`PATH` 前面挂一个 tmux 桩，
并先把环境里已有的 `WTOOL_*` 全清掉（外面那套会盖住被测文件的默认值）。
