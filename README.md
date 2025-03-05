# 个人脚本仓库

这个仓库包含了一些个人编写的脚本，用于各种自动化任务和工具。

## 目录结构

- `README.md` - 说明文档
- `brew_casks.txt` - Homebrew Casks 列表
- `brew_formulae.txt` - Homebrew Formulaes 列表
- `ohmyzsh-setup.sh` - Oh My Zsh 配置工具，包括主题、插件等
- `homebrew-setup.sh` - Homebrew 安装工具
- `macos-setup.sh` - macOS 配置工具，包括homebrew镜像配置，formulae安装，软件安装等，已经配置对应的环境变量
- `brew_manager.py` - Homebrew formulaes/casks 管理工具
- `git_setup.py` - Git SSH Key 配置工具，具体用法建议使用pipx，eg： “pipx run --spec requests python git_setup.py -d github.com -t personal”


## 使用方法

1. 克隆仓库到本地：
    ```bash
    git clone https://github.com/anzihenry/personal_scripts.git
    ```
2. 进入脚本目录：
    ```bash
    cd personal_scripts
    ```
3. 运行你需要的脚本，例如：
    ```bash
    python brew_manager.py
    ```

## 贡献

欢迎提交 pull request 来改进这些脚本。如果你有任何问题或建议，请创建一个 issue。

## 许可证

这个项目使用 MIT 许可证。详情请参阅 `LICENSE` 文件。