# 脚本仓库

这个仓库包含了用于各种自动化任务和工具的脚本。

## 目录结构

- `README.md` - 说明文档
- `LICENSE` - 许可证
- `maintain/` - 维护脚本
    - `brew_manager.py` - Homebrew formulaes/casks 管理工具
- `setup/` - 安装配置脚本
    - `brew_casks.txt` - Homebrew Casks 列表
    - `brew_formulae.txt` - Homebrew Formulaes 列表
    - `ohmyzsh-setup.sh` - Oh My Zsh 配置工具，包括主题、插件等
    - `homebrew-setup.sh` - Homebrew 安装工具
    - `macos-setup.sh` - macOS 配置工具，包括homebrew镜像配置，formulae安装，软件安装等，已经配置对应的环境变量
    - `git_forge_ssh_setup.py` - Git托管服务（如GitHub） SSH Key 配置工具，具体用法建议使用pipx，eg： “pipx run --spec requests python git_forge_ssh_setup.py -d github.com -t personal”


## 使用方法

1. 克隆仓库到本地：
    ```bash
    git clone https://github.com/anzihenry/scripts.git
    ```
2. 进入相关脚本目录：
    ```bash
    cd maintain
    ```
3. 运行你需要的脚本，例如：
    ```bash
    python brew_manager.py
    ```
4. shell脚本在执行前需要增加执行权限：
    ```bash
    chmod +x ohmyzsh-setup.sh
    ```
    然后运行：
    ```bash
    ./ohmyzsh-setup.sh
    ```

## 贡献

欢迎提交 pull request 来改进这些脚本。如果你有任何问题或建议，请创建一个 issue。

## 许可证

这个项目使用 MIT 许可证。详情请参阅 `LICENSE` 文件。