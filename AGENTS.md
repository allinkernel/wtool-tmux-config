# AGENTS.md —— terminal/tmux

> 先读用户级 `~/.dsh/AGENTS.md`（工作区通用规则）和仓库根 `AGENTS.md`（多仓库工作区规则），
> 本文件只讲**这个项目**的事。

## 这个项目是什么

一份 tmux 配置 + 两个 shell 的 env 片段。**它是 wtool 的子项目**：装、卸都由 wtool
按 `wtool.xml` 的声明执行，仓库里**没有** `install.sh` / `uninstall.sh`。

| 文件 | 是干什么的 |
|---|---|
| `tmux.conf` | 配置本体，wtool 软链到 `~/.tmux.conf` |
| `env.zsh` / `env.bash` | 两个 shell 各一份、**内容必须等价**（有人机器上没有 zsh） |
| `bin/*.sh` | 状态栏脚本，被 `tmux.conf` 的 `#()` 按稳定地址调用 |
| `wtool.xml` | 清单：`~/.tmux.conf` 链接 + 两份 env |
| `tests/env_test.sh` | env 等价的测试 |

## 铁律

1. **代码 / 配置一有变化，必须在同一个提交里同步更新 `README.md`。**
   `README.md` 是**给用户的完整功能说明书**（不是开发笔记）。
   改了 `tmux.conf` 的键位/选项 → 必须改 README 的「快捷键功能」/「状态栏」/「选项设置」；
   改了 `env.*` → 必须改「shell 集成」；增删 `bin/` 脚本 → 必须改「文件」和状态栏那张表。
   **README 与代码不一致 = 缺陷**，不是"以后补"。

2. **README 里不写安装步骤。** 安装只有一句话（`wtool install terminal/tmux`）
   + 一个链接到全局唯一下载/安装入口（GitHub 上 `wtool-base/README.md`）。
   不要写 `./install.sh` 这种跑法 —— 本仓库没有那个脚本，装卸都由 wtool 调用。

3. **`env.zsh` 和 `env.bash` 必须同改。** 改名、改报错文字、改默认值，两边一起改，
   并且 `tests/env_test.sh` 用同一张用例表测两个 shell。只改一份 = 装了一半。

4. **快捷键那节要逐条对着 `tmux.conf` 核。** 用户明确要求"每个 key binding
   （`bind` / `bind-key` / `unbind`）逐条列出来，写清按什么键 → 干什么"。
   配置里没写解释的键位，**照配置原文写，不要编用途**（例：`unbind-key Escape`
   只照抄配置注释，并说明它在当前 tmux 版本上实测不改变行为）。

5. **`wtool.xml` 里的 `id` / 链接目标是契约**：`id` 同时出现在
   `~/.wtool/wtool-work-dir/links/<id>`、rc 的 wtool 块、`tmux.conf` 里引用 `bin/` 的
   绝对路径三处，改一处必须三处一起改。

## README 章节结构（改了对应内容就改对应章节）

| 章节 | 内容 | 对应代码 |
|---|---|---|
| （开头一段） | 这个配置提供什么 | `tmux.conf` 的选项 |
| `## 安装` | 一句话 + wtool-base 链接 | `wtool.xml` |
| `## 功能说明` → `### 文件` | 每个文件干什么 | `git ls-files` |
| `## 功能说明` → `### shell 集成` | `WTOOL_TMUX_DIR` / `tmux-wtool` / 兜底默认值 | `env.zsh`、`env.bash` |
| `## 功能说明` → `### 快捷键功能` | **逐条键位表**（前缀键、Alt 系列、`c`/`%`/`"`、两条解绑、自动分屏几何） | `tmux.conf` |
| `## 功能说明` → `### 状态栏` | `status-*` 选项 + 三个 `bin/*.sh` | `tmux.conf`、`bin/` |
| `## 功能说明` → `### 选项设置` | 改了 tmux 默认值的那些选项（含默认值对照） | `tmux.conf` |
| `## 已知问题` | 保持原样迁移的毛病 | `bin/*.sh` |
| `## 测试` | 怎么跑 | `tests/` |
| `## 迁移历史` | 与 mytool 版本的差异 | —— |

## 测试

```sh
cd terminal/tmux && bash tests/env_test.sh   # 5 条，应全绿
```

只读、不碰 `$HOME`、不联网。改完 `env.zsh` / `env.bash` 必须跑。

**改 `tmux.conf` 之后建议再做一次实测**（配置能不能被 tmux 解析、键位到底生效成什么），
这套命令不用真终端、用完自己清掉：

```sh
cd terminal/tmux
export TMUX_TMPDIR=$(mktemp -d)                     # 别碰用户自己的 tmux server
tmux -L probe -f "$PWD/tmux.conf" new-session -d -x 200 -y 50
tmux -L probe list-keys -T prefix > /tmp/conf.txt   # 和默认表对比：
tmux -L dflt  -f /dev/null new-session -d -x 200 -y 50
tmux -L dflt  list-keys -T prefix > /tmp/dflt.txt
diff /tmp/dflt.txt /tmp/conf.txt                    # 这份 diff 就是本配置改动的全部键位
tmux -L probe kill-server; tmux -L dflt kill-server
```

## 提交

改动只提交到 `ds_dev`（用户级规则见 `~/.dsh/AGENTS.md` §1）：`git add` 前先 `git diff`
看一遍、提交带 `-m`、**不 push、不动 `main`**。
