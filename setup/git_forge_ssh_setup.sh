#!/bin/bash
# filepath: setup/git_forge_ssh_setup.sh

set -euo pipefail

# 引入颜色库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

# ========== 工具函数 ==========
sanitize_domain() {
    local domain="$1"
    domain="${domain#*://}"
    domain="${domain#*@}"
    domain="${domain%%:*}"
    domain="${domain%%/*}"
    domain="$(echo "$domain" | tr '[:upper:]' '[:lower:]')"
    if [[ ! "$domain" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
        log_error "无效域名格式: $domain"
        exit 1
    fi
    echo "$domain"
}

generate_host_alias() {
    local domain="$1" usage_type="$2"
    local domain_part="${domain%%.*}"
    domain_part="${domain_part//[^a-z0-9]/}"
    echo "${domain_part}-${usage_type}"
}

get_git_email() {
    local email
    email="$(git config --global user.email 2>/dev/null || true)"
    while [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        read -p "$(highlight '请输入有效的Git全局邮箱地址: ')" email
        if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            git config --global user.email "$email" || log_error "设置Git邮箱失败"
        fi
    done
    echo "$email"
}

generate_ssh_key() {
    local domain="$1" usage_type="$2" force="$3"
    local ssh_dir="$HOME/.ssh"
    local domain_part="${domain%%.*}"
    local key_path="$ssh_dir/id_ed25519_${domain_part}_${usage_type}"
    local pub_key_path="${key_path}.pub"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ -f "$key_path" && "$force" != "true" ]]; then
        log_info "检测到现有密钥: $key_path"
        read -p "$(highlight '是否覆盖？(y/N): ')" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            cat "$pub_key_path"
            return 0
        fi
        rm -f "$key_path" "$pub_key_path"
    fi

    local email comment
    email="$(get_git_email)"
    comment="$email [$usage_type@$domain]"

    log_info "生成SSH密钥: $key_path"
    ssh-keygen -t ed25519 -C "$comment" -f "$key_path" -N "" -q || log_fatal "密钥生成失败"
    chmod 600 "$key_path"
    chmod 644 "$pub_key_path"
    cat "$pub_key_path"
}

backup_ssh_config() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 0
    local backup_file="${config_file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$config_file" "$backup_file" && log_info "创建配置备份: $backup_file"
}

update_ssh_config() {
    local domain="$1" usage_type="$2" key_path="$3"
    local ssh_dir="$HOME/.ssh"
    local config_file="$ssh_dir/config"
    local host_alias
    host_alias="$(generate_host_alias "$domain" "$usage_type")"

    backup_ssh_config "$config_file"

    # 过滤掉同名Host
    local tmp_file
    tmp_file="$(mktemp)"
    local in_block=0
    if [[ -f "$config_file" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^Host[[:space:]]+$host_alias ]]; then
                in_block=1
                continue
            fi
            [[ $in_block -eq 1 && "$line" =~ ^Host[[:space:]] ]] && in_block=0
            [[ $in_block -eq 0 ]] && echo "$line" >> "$tmp_file"
        done < "$config_file"
    fi

    # 新配置块
    {
        echo "# Auto-config: $(date +%Y-%m-%d)"
        echo "Host $host_alias"
        echo "    HostName $domain"
        echo "    User git"
        echo "    AddKeysToAgent yes"
        echo "    UseKeychain yes"
        echo "    PubkeyAuthentication yes"
        echo "    IdentityFile $key_path"
        echo
    } >> "$tmp_file"

    mv "$tmp_file" "$config_file"
    chmod 600 "$config_file"
    log_success "SSH配置已更新: $config_file"
    echo "$host_alias"
}

upload_github_key() {
    local pub_key="$1" title="$2" token="$3"
    log_info "上传公钥到GitHub..."
    local resp http_code
    resp=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token $token" \
        -d "{\"title\":\"$title\",\"key\":\"$pub_key\"}" \
        "https://api.github.com/user/keys")
    http_code="${resp##*$'\n'}"
    body="${resp%$'\n'*}"
    if [[ "$http_code" == "201" ]]; then
        log_success "公钥已成功上传到GitHub"
        return 0
    elif [[ "$http_code" == "422" && "$body" =~ "key is already in use" ]]; then
        log_warn "公钥已存在于GitHub"
        return 0
    else
        log_error "GitHub API错误 ($http_code): $body"
        return 1
    fi
}

test_ssh_connection() {
    local host_alias="$1"
    log_info "测试SSH连接: $host_alias"
    local result
    result=$(ssh -T -o ConnectTimeout=15 -o StrictHostKeyChecking=no "git@$host_alias" 2>&1 || true)
    if echo "$result" | grep -qi "successfully authenticated"; then
        log_success "SSH连接验证成功"
        return 0
    else
        log_error "SSH连接测试失败"
        log_error "输出: $result"
        return 1
    fi
}

print_usage_instructions() {
    local host_alias="$1"
    print_header "配置完成"
    echo -e "$(highlight '使用方法：')"
    echo -e "1. 克隆新仓库："
    echo -e "   $(highlight "git clone git@$host_alias:username/repo.git")"
    echo -e "2. 更新现有仓库远程地址："
    echo -e "   $(highlight "git remote set-url origin git@$host_alias:username/repo.git")"
    echo -e "3. 验证连接："
    echo -e "   $(highlight "ssh -T git@$host_alias")"
}

# ========== 主流程 ==========
usage() {
    cat <<EOF
用法: $0 [-d domain] [-t personal|work] [--force] [--skip-upload] [--debug]
  -d, --domain      Git平台域名（默认：github.com）
  -t, --type        密钥用途类型（personal|work，默认：personal）
  --force           强制覆盖现有密钥
  --skip-upload     跳过GitHub公钥上传
  --debug           显示调试信息
  -h, --help        显示帮助
EOF
}

# 默认参数
domain="github.com"
usage_type="personal"
force="false"
skip_upload="false"
debug="false"

# 参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain) domain="$2"; shift 2 ;;
        -t|--type) usage_type="$2"; shift 2 ;;
        --force) force="true"; shift ;;
        --skip-upload) skip_upload="true"; shift ;;
        --debug) debug="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "未知参数: $1"; usage; exit 1 ;;
    esac
done

if [[ "$debug" == "true" ]]; then
    set -x
fi

domain="$(sanitize_domain "$domain")"
host_alias="$(generate_host_alias "$domain" "$usage_type")"

print_header "SSH密钥管理及Git平台自动配置工具"

# 1. 生成密钥对
pub_key="$(generate_ssh_key "$domain" "$usage_type" "$force")"

# 2. 更新SSH配置
host_alias="$(update_ssh_config "$domain" "$usage_type" "$HOME/.ssh/id_ed25519_${domain%%.*}_${usage_type}")"

# 3. GitHub公钥上传
if [[ "$skip_upload" != "true" && "$domain" == "github.com" ]]; then
    print_header "GitHub公钥上传"
    read -s -p "$(highlight 'GitHub访问令牌（需admin:public_key权限）: ')" token
    echo
    title="$(hostname) [$usage_type] $(date +%Y-%m-%d)"
    upload_github_key "$pub_key" "$title" "$token" || log_warn "GitHub配置未完成，但SSH配置已更新"
fi

# 4. 连接测试
print_header "SSH连接测试"
test_ssh_connection "$host_alias" || {
    log_error "请检查："
    log_error "1. 公钥是否已添加到Git平台"
    log_error "2. 防火墙或网络设置"
    log_error "3. SSH配置是否正确"
    exit 1
}

# 5. 输出使用说明
print_usage_instructions "$host_alias"