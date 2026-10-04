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

- **2026-10-04 P2 文档核对**（提交 `95a24b9`）：订正 `bin/disk.sh` 的 shell 结论
  （旧 README 说"赋值出不了管道子 shell、输出可能是 `[]`"是错的：脚本 shebang 是 zsh，
  zsh 让管道最后一段在当前 shell 里跑）；补容器装/测规矩；键位表标出 main/ds_dev 差异；
  补全 `status-right` 的 tmux 默认值；修正 `AGENTS.md` 里"改 `tmux.conf` 后实测"的配方
  （要 dump `prefix` **和** `root` 两张表，`-n` 的绑定落在 root 表）。
  测试：`bash tests/env_test.sh` → 5 通过 / 0 失败。
