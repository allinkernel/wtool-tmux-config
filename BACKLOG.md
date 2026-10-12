# BACKLOG —— terminal/tmux

> 这个文件是这个项目"接下来做什么、做到哪了"的**唯一权威**。
> 引擎/跨项目的事在 `~/self/wtool/harness/BACKLOG.md`，别混。
>
> 状态：⬜ 待做 · 🔄 在做 · ✅ 做完（写清怎么做的、验证到什么程度）· ⏸ 待决定（要人来拍）

---

## ⏸ 待拍板

### 1. `ds_dev` 缺 `main` 的 `4d36585`（"新增快捷键"）—— 要不要先合 `main` 进 `ds_dev`

**现状**（2026-10-04 P2 核对时确认）：`ds_dev` 是从更早的提交拉出来的，
`git log --oneline ds_dev..main` 只有一条 `4d36585`（`prefix + c` 自动分屏、`%` / `"`
继承工作目录）。所以：

- `main` 的 `tmux.conf` 有 **17** 条键位声明，`ds_dev` 只有 **14** 条；
- README 的键位表是按**合并后**的样子写的（13 / 14 / 15 三行），并有一段显式的
  "分支提示"说明这三行在 `ds_dev` 上还不存在；
- 判据：`grep -cE '^(bind|bind-key|unbind|unbind-key)' tmux.conf` → 14（`ds_dev`）；
  `git show main:tmux.conf | grep -cE '^(bind|bind-key|unbind|unbind-key)'` → 17（`main`）。

**要人拍**：助手**不合并**（用户级 `~/.dsh/AGENTS.md` §1）。合并方向由用户定；
合完之后 README 里那段"分支提示"和 `AGENTS.md` 里对应的现状说明**一起删掉**即可
（那时表里的 17 条全都成立）。

### 2. `bin/net.sh` 留不留

`bin/net.sh` 硬编码网卡名 `ens33`，**`tmux.conf` 里没有任何地方引用它**（状态栏只挂了
mem / cpu / disk）。原 `readme.md` 的原话是"net.sh 用来计算网络速率的方法，在部分机器上
也不会生效，**所以我打算放弃**"。

要人拍：① 删掉；② 改成按 `ip route` 自动找网卡并接进状态栏；③ 保持原样（**当前就是**，
README「已知问题」里记着）。助手没动它。

---

## ✅ 做完的

- **2026-10-13 按 ADR-0045 新架构改造（① 类纯源码项目）** —— 提交见 `git log ds_dev`。

  **现象**：对 `terminal/tmux` 跑 `wtool install` 直接报错、rc=2、装不上：

  ```
  wtool: error: <link> 已经删掉（ADR-0045 / D3）：$HOME 里不再有 wtool 建的软链。
          ① 类（纯源码）：配置/脚本**直接读源码**，$WTOOL_HOME/wtool/<项目路径>/… 由 L1 解析…
  ```

  **根因**：`wtool.xml` 里还留着一条旧写法的 `<link home="~/.tmux.conf" …>`；引擎的
  `d06046d`（ADR-0045 第 3 块 / D3）**按设计删掉了 `<link>` 的解析、不留兼容期**，
  而 `tmux.conf` 的状态栏又指着已废弃的中转链
  `$HOME/.wtool/wtool-work-dir/links/terminal/tmux/bin/*.sh` —— 两处都是旧链接模型。

  **修法**（只动本仓库）：
  1. 删掉 `wtool.xml` 那条 `<link>`，清单只剩 `<zshrc>` / `<bashrc>` 两行
     （`kind` 缺省 = `source`，① 类**不写** `<export_*>` / `<generate>`，D46）；
  2. `tmux.conf` 状态栏改走 L1 路径
     `#(sh -c 'exec "$WTOOL_HOME/wtool/terminal/tmux/bin/mem.sh"')`（cpu / disk 同）；
  3. `env.zsh` / `env.bash` 加 `tmux()` **包装函数**（D10）＋ `WTOOL_HOME` **校验**（D48）；
  4. 新建 `architecture.md` 记现状，README / AGENTS 同提交更新。

  **验证到什么程度（都是实测，不是推断）**：
  - 引擎：`plan-install` 由 rc=2（上面那条报错）变成 rc=0；
    容器里 `docker run --rm` + 只读挂载 + `WTOOL_HOME`/`WTOOL_STATE` 全在 `/tmp`，
    `wtool install terminal/tmux --force` → **install 完成**，落盘 = L1 链
    `$WTOOL_HOME/wtool/terminal/tmux → 工作区` ＋ 两段 env 块，`$HOME` 里**没有** `~/.tmux.conf`；
  - Q11（`#()` 能不能看到 `WTOOL_HOME`）**实测能**：`tmux show-environment -g | grep WTOOL_HOME`
    有条目；`#(sh -c 'echo "$WTOOL_HOME"')` 输出非空；把客户端 `env -u WTOOL_HOME` 剥干净再
    attach 也照样能拿到（值来自 **server 启动时的环境**）——所以**不需要**退回"安装时渲染"；
  - 端到端：装出来的 conf 用真 tmux 3.4 起 server + pty 客户端截屏，状态栏是
    `[M:20G S:68G][C:0.75%][]`（mem / cpu 正常；disk 在容器里本来就空 —— `df` 没有
    `/dev/sd*`，不是坏了）；
  - `bash tests/env_test.sh` → **29 通过 / 0 失败**。

  **顺带记下的三条坑**（写进 README「已知问题」+ `architecture.md` §3 + AGENTS 铁律 6）：
  `tmux -f <文件不存在>` **不报错**（静默用默认配置）；conf 里 `${VAR:-默认}` 会让整行
  `set` 失效、`\$VAR` 会把反斜杠留给 `sh`（只有上面那一种写法可用）；老 server 看不到
  后来才 `export` 的 `WTOOL_HOME`，`tmux kill-server` 重起即恢复。

- **2026-10-04 P2 文档核对**（提交 `95a24b9`）：订正 `bin/disk.sh` 的 shell 结论
  （旧 README 说"赋值出不了管道子 shell、输出可能是 `[]`"是错的：脚本 shebang 是 zsh，
  zsh 让管道最后一段在当前 shell 里跑）；补容器装/测规矩；键位表标出 main/ds_dev 差异；
  补全 `status-right` 的 tmux 默认值；修正 `AGENTS.md` 里"改 `tmux.conf` 后实测"的配方
  （要 dump `prefix` **和** `root` 两张表，`-n` 的绑定落在 root 表）。
  测试：`bash tests/env_test.sh` → 5 通过 / 0 失败（当时；现在是 29 条）。
