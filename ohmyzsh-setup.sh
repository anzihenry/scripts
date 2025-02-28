#!/bin/zsh

# 启用错误中断和显示执行命令
set -e
set -o pipefail

# 配置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}
______________________________________________________________
  #####   ##   ##  ##   ##  ##  ##   #######   #####   ##   ##
 ##   ##  ##   ##  ### ###  ##  ##   #   ##   ##   ##  ##   ##
 ##   ##  ##   ##  #######  ##  ##      ##    #        ##   ##
 ##   ##  #######  #######   ####      ##      #####   #######
 ##   ##  ##   ##  ## # ##    ##      ##           ##  ##   ##
 ##   ##  ##   ##  ##   ##    ##     ##    #  ##   ##  ##   ##
  #####   ##   ##  ##   ##   ####    #######   #####   ##   ##
______________________________________________________________
${NC}"

# 1. 安装/配置 oh-my-zsh
OHMYZSH_DIR="${HOME}/.oh-my-zsh"
if [ ! -d "${OHMYZSH_DIR}" ]; then
    echo -e "${YELLOW}正在安装 oh-my-zsh...${NC}"
    
    # 优先尝试 GitHub 官方源
    if ! git clone https://github.com/ohmyzsh/ohmyzsh.git ${OHMYZSH_DIR} ; then
        echo -e "${YELLOW}GitHub 连接失败，改用 Gitee 镜像...${NC}"
        git clone https://gitee.com/mirrors/oh-my-zsh.git ${OHMYZSH_DIR}
    fi

    # 备份原有配置
    if [ -f "${HOME}/.zshrc" ]; then
        cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak"
        echo -e "${YELLOW}已备份原有配置：~/.zshrc.bak${NC}"
    fi

    # 应用基础配置模板
    [ ! -f "${HOME}/.zshrc" ] && \
    cp "${OHMYZSH_DIR}/templates/zshrc.zsh-template" "${HOME}/.zshrc"
    
    echo -e "${GREEN}✓ oh-my-zsh 安装完成${NC}"
else
    echo -e "${GREEN}✓ oh-my-zsh 已安装${NC}"
fi

# 2. 安装 powerlevel10k 主题
echo -e "${YELLOW}安装 powerlevel10k 主题...${NC}"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# 清理旧版本安装
[ -d "${P10K_DIR}" ] && rm -rf ${P10K_DIR}

# 使用镜像源安装
if ! git clone https://github.com/romkatv/powerlevel10k.git ${P10K_DIR} ; then
    echo -e "${YELLOW}GitHub 连接失败，改用 Gitee 镜像...${NC}"
    git clone https://gitee.com/romkatv/powerlevel10k.git ${P10K_DIR}
fi

echo -e "${GREEN}✓ powerlevel10k主题 已安装${NC}"

# 3. 安装核心插件
plugins=(
    git
    extract
    z
    colored-man-pages
    zsh-syntax-highlighting
    zsh-autosuggestions
)

echo -e "${YELLOW}配置常用插件...${NC}"

# 创建插件目录
ZSH_CUSTOM="${OHMYZSH_DIR}/custom"
mkdir -p "${ZSH_CUSTOM}/plugins"

# 安全安装插件函数
install_plugin() {
    local plugin=$1
    local github_repo=$2
    local gitee_repo=$3
    
    plugin_dir="${ZSH_CUSTOM}/plugins/${plugin}"
    if [ ! -d "${plugin_dir}" ]; then
        echo -e "${YELLOW}安装插件 ${plugin}...${NC}"
        if ! git clone --depth=1 "https://github.com/${github_repo}.git" ${plugin_dir} ; then
            echo -e "${YELLOW}GitHub 连接失败，改用 Gitee 镜像...${NC}"
            git clone --depth=1 "https://gitee.com/${gitee_repo}.git" ${plugin_dir}
        fi
    fi
}

install_plugin "zsh-syntax-highlighting" "zsh-users/zsh-syntax-highlighting" "mirrors/zsh-syntax-highlighting"
install_plugin "zsh-autosuggestions" "zsh-users/zsh-autosuggestions" "mirrors/zsh-autosuggestions"

echo -e "${GREEN}✓ 常用插件 已安装${NC}"

# 4. 安全配置更新
echo -e "${YELLOW}更新 zsh 配置...${NC}"

# 配置 powerlevel10k 主题
if grep -q "^ZSH_THEME=" ~/.zshrc; then
    # 替换现有主题配置
    sed -i '' 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
else
    # 新增主题配置
    if grep -q "# Set name of the theme to load" ~/.zshrc; then
        sed -i '' '/^# Set name of the theme to load/a\
ZSH_THEME="powerlevel10k\/powerlevel10k"' ~/.zshrc
    else
        echo "\n# Powerlevel10k Theme" >> ~/.zshrc
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
    fi
fi

# 插件配置（兼容处理）
if grep -q "^plugins=" ~/.zshrc; then
    existing_plugins=($(grep -oE 'plugins=\([^)]*\)' ~/.zshrc | sed 's/plugins=(//;s/)//' || true))
    
    # 修复数组操作语法
    combined_plugins=("${existing_plugins[@]}" "${plugins[@]}")
    combined_plugins=(${(u)combined_plugins})
    
    sed -i '' "s/^plugins=.*/plugins=(${combined_plugins})/" ~/.zshrc
else
    echo "\n# Custom plugins" >> ~/.zshrc
    echo "plugins=(${plugins[@]})" >> ~/.zshrc
fi

echo -e "${GREEN}✓ zsh配置 更新完成${NC}"

# 5. 安装必备字体和配置
echo -e "${YELLOW}配置终端字体...${NC}"

# 字体文件列表
declare -A fonts=(
    ["MesloLGS NF Regular.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    ["MesloLGS NF Bold.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    ["MesloLGS NF Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    ["MesloLGS NF Bold Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
)

# 创建字体目录
FONT_DIR="${HOME}/Library/Fonts"
mkdir -p ${FONT_DIR}

# 下载字体文件
for font in ${(k)fonts}; do
    if [ ! -f "${FONT_DIR}/${font}" ]; then
        echo -e "${YELLOW}下载字体: ${font}...${NC}"
        if ! curl -#L -o "${FONT_DIR}/${font}" "${fonts[$font]}" ; then
            echo -e "${YELLOW}GitHub 下载失败，改用 手动下载安装${NC}"
        fi
    fi
done

# 刷新字体缓存
sudo atsutil databases -remove &>/dev/null

echo -e "${GREEN}✓ 终端字体 配置完成${NC}"

# 6. 预置基础配置（可选）
echo -e "${YELLOW}应用推荐配置...${NC}"
cat >> ~/.zshrc <<-'EOF'

# Powerlevel10k 优化配置
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs status)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(time background_jobs)
POWERLEVEL9K_MODE='nerdfont-complete'
EOF

# 7. 应用配置
echo -e "${YELLOW}正在应用配置...${NC}"
source ~/.zshrc || true

echo -e "${GREEN}
____________________________________________________

           🎉 Powerlevel10k 配置完成！请执行：
           
1. 终端字体设置：
   - iTerm2: Preferences → Profiles → Text → Font → 选择 \"MesloLGS NF\"
   - VSCode: 设置中搜索 \"terminal font\" → 添加 \"MesloLGS NF\"
   
2. 主题配置向导：
   p10k configure
   （或使用预置配置，按 Enter 跳过）

3. 完全生效：
   exec zsh

4. 验证命令：
   - 查看主题：echo \$ZSH_THEME
   - 检查字体：ls ~/Library/Fonts | grep MesloLGS

____________________________________________________
${NC}"