# 说明
wsw的tmux配置

process.sh用来计算cpu占用率的方法，在wsl1上不会生效

net.sh 用来计算网络速率的方法，在部分机器上也不会生效，所以我打算放弃

## shell 集成

`env.zsh`（zsh）和 `env.bash`（bash）**内容等价**：导出 `WTOOL_TMUX_DIR`、
定义 `tmux-wtool` 别名（强制用本项目的 `tmux.conf`）。分别由 `~/.zshrc` /
`~/.bashrc` 里的 wtool 块 source —— 受众里有人机器上没有 zsh。

```sh
bash tests/env_test.sh     # 7 条；没装 zsh 就只测 bash
```
