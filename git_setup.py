#!/usr/bin/env python3
import os
import re
import sys
import argparse
import subprocess
import getpass
import shutil
import logging
from pathlib import Path
from tempfile import NamedTemporaryFile
import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime
from typing import Optional

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

class SSHConfigManager:
    def __init__(self, domain: str, usage_type: str, key_path: Path):
        self.ssh_dir = Path.home() / ".ssh"
        self.config_path = self.ssh_dir / "config"
        self.domain = self._sanitize_domain(domain)
        self.usage_type = usage_type
        self.key_path = key_path
        self.host_alias = self._generate_host_alias()
        
    def _sanitize_domain(self, domain: str) -> str:
        """规范化域名并验证格式"""
        domain = re.sub(r"(https?://|git@|:|\/.*)", "", domain)
        domain = domain.split("@")[-1].lower().strip()
        
        if not re.match(r"^[a-z0-9.-]+\.[a-z]{2,}$", domain):
            raise ValueError(f"无效域名格式: {domain}")
        return domain

    def _generate_host_alias(self) -> str:
        """生成唯一Host别名"""
        domain_part = re.sub(r"\W+", "", self.domain.split(".")[0])
        return f"{domain_part}-{self.usage_type}"

    def _generate_config_block(self) -> str:
        """生成SSH配置块"""
        return f"""# Auto-config: {datetime.now().strftime('%Y-%m-%d')}
Host {self.host_alias}
    HostName {self.domain}
    User git
    AddKeysToAgent yes
    UseKeychain yes
    PubkeyAuthentication yes
    IdentityFile {self.key_path}
"""

    def _backup_config(self) -> Optional[Path]:
        """创建带时间戳的备份"""
        if not self.config_path.exists():
            return None
        backup_path = self.config_path.with_name(
            f"config.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}")
        try:
            shutil.copy(self.config_path, backup_path)
            logger.info(f"创建配置文件备份: {backup_path}")
            return backup_path
        except Exception as e:
            raise RuntimeError(f"备份失败: {str(e)}") from e

    def _validate_config_safety(self):
        """验证配置文件安全性"""
        if self.config_path.exists():
            try:
                stat = self.config_path.stat()
                if stat.st_mode & 0o777 != 0o600:
                    logger.warning("配置文件权限不安全，自动修正...")
                    self.config_path.chmod(0o600)
            except PermissionError as e:
                raise RuntimeError(f"权限不足: {str(e)}") from e

    def update_config(self) -> bool:
        """安全更新SSH配置"""
        backup_file = None
        try:
            # 创建.ssh目录
            self.ssh_dir.mkdir(exist_ok=True, mode=0o700)
            
            # 备份配置
            backup_file = self._backup_config()
            
            # 读取现有配置
            existing_lines = []
            if self.config_path.exists():
                with open(self.config_path, "r") as f:
                    existing_lines = f.readlines()

            # 过滤现有相同Host配置
            new_lines = []
            current_host = None
            for line in existing_lines:
                line = line.strip()
                if line.startswith("Host "):
                    current_host = line.split()[1].strip()
                if current_host != self.host_alias:
                    new_lines.append(line + "\n")

            # 添加新配置
            new_config = self._generate_config_block()
            new_lines.append(new_config)

            # 原子写入
            with NamedTemporaryFile("w", dir=self.ssh_dir, delete=False) as tmp_file:
                tmp_path = Path(tmp_file.name)
                tmp_file.writelines(new_lines)
            
            # 替换文件并设置权限
            tmp_path.replace(self.config_path)
            self.config_path.chmod(0o600)
            self._validate_config_safety()
            
            logger.info("SSH配置更新成功")
            return True
        except Exception as e:
            logger.error(f"配置更新失败: {str(e)}")
            if backup_file and backup_file.exists():
                logger.info("尝试恢复备份...")
                try:
                    shutil.copy(backup_file, self.config_path)
                    logger.info("配置已从备份恢复")
                except Exception as restore_error:
                    logger.error(f"恢复备份失败: {str(restore_error)}")
            return False

class GitHubManager:
    def __init__(self, pub_key: str, key_title: str):
        self.pub_key = pub_key
        self.key_title = key_title
        
    def upload_key(self, token: str) -> bool:
        """通过GitHub API上传公钥"""
        try:
            response = requests.post(
                "https://api.github.com/user/keys",
                auth=HTTPBasicAuth("token", token),
                headers={
                    "Accept": "application/vnd.github+json"
                },
                json={"title": self.key_title, "key": self.pub_key},
                timeout=20
            )
            response.raise_for_status()
            logger.info("公钥已成功上传至GitHub")
            return True
        except requests.HTTPError as e:
            if e.response.status_code == 422:
                logger.warning("公钥已存在于GitHub")
                return True
            logger.error(f"API错误 ({e.response.status_code}): {e.response.text}")
            return False
        except requests.RequestException as e:
            logger.error(f"网络错误: {str(e)}")
            return False

class SSHKeyGenerator:
    def __init__(self, domain: str, usage_type: str):
        self.domain = domain
        self.usage_type = usage_type
        self.ssh_dir = Path.home() / ".ssh"
        self.key_path = self._generate_key_path()
        self.pub_key: Optional[str] = None
        
    def _generate_key_path(self) -> Path:
        """生成密钥文件路径"""
        domain_part = re.sub(r"\W+", "", self.domain.split(".")[0])
        return self.ssh_dir / f"id_ed25519_{domain_part}_{self.usage_type}"

    def _validate_git_email(self) -> str:
        """获取并验证Git邮箱"""
        try:
            result = subprocess.run(
                ["git", "config", "--global", "user.email"],
                capture_output=True, text=True, check=True
            )
            email = result.stdout.strip()
        except subprocess.CalledProcessError:
            email = ""
            
        while not re.match(r"^[\w\.-]+@[\w-]+\.[\w\.-]+$", email):
            email = input("请输入有效的Git全局邮箱地址: ").strip()
            try:
                subprocess.run(
                    ["git", "config", "--global", "user.email", email],
                    check=True
                )
            except subprocess.CalledProcessError as e:
                logger.error(f"Git配置失败: {str(e)}")
                continue
        return email

    def generate_key_pair(self, force: bool = False) -> bool:
        """生成SSH密钥对"""
        if self.key_path.exists():
            if not force:
                logger.info(f"检测到现有密钥: {self.key_path}")
                choice = input("是否覆盖？(y/N): ").lower()
                if choice != 'y':
                    self.pub_key = self.key_path.with_suffix(".pub").read_text()
                    return True
                
            # 删除旧密钥
            try:
                self.key_path.unlink(missing_ok=True)
                self.key_path.with_suffix(".pub").unlink(missing_ok=True)
            except OSError as e:
                logger.error(f"删除旧密钥失败: {str(e)}")
                return False

        comment = f"{self._validate_git_email()} [{self.usage_type}@{self.domain}]"
        
        try:
            result = subprocess.run(
                ["ssh-keygen", "-t", "ed25519", "-C", comment, "-f", str(self.key_path), "-N", "", "-q"],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                logger.error(f"密钥生成失败: {result.stderr.strip()}")
                return False
            
            # 设置权限
            self.key_path.chmod(0o600)
            self.key_path.with_suffix(".pub").chmod(0o644)
            
            self.pub_key = self.key_path.with_suffix(".pub").read_text()
            logger.info(f"已生成新密钥: {self.key_path}")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"密钥生成命令执行失败: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"未知错误: {str(e)}")
            return False

def test_ssh_connection(host_alias: str) -> bool:
    """测试SSH连接"""
    try:
        result = subprocess.run(
            ["ssh", "-T", f"git@{host_alias}"],
            capture_output=True, text=True, timeout=15
        )
        if "successfully authenticated" in result.stderr:
            logger.info("SSH连接验证成功")
            return True
        else:
            logger.error(f"连接失败: {result.stderr.strip()}")
            return False
    except subprocess.TimeoutExpired:
        logger.error("连接超时，请检查网络")
        return False
    except Exception as e:
        logger.error(f"连接测试异常: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="SSH密钥管理及Git平台自动配置工具",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("-d", "--domain",
                      default="github.com",
                      help="Git平台域名（默认：github.com）")
    parser.add_argument("-t", "--type",
                      choices=["personal", "work"],
                      default="personal",
                      help="密钥用途类型（默认：personal）")
    parser.add_argument("--force",
                      action="store_true",
                      help="强制覆盖现有密钥")
    parser.add_argument("--skip-upload",
                      action="store_true",
                      help="跳过GitHub公钥上传")
    parser.add_argument("--debug",
                      action="store_true",
                      help="启用调试输出")
    args = parser.parse_args()

    if args.debug:
        logger.setLevel(logging.DEBUG)
        requests_log = logging.getLogger("urllib3")
        requests_log.setLevel(logging.DEBUG)

    try:
        # 1. 生成密钥对
        key_gen = SSHKeyGenerator(args.domain, args.type)
        if not key_gen.generate_key_pair(args.force):
            sys.exit(1)
        
        if not key_gen.pub_key:
            logger.error("未获取到有效的公钥")
            sys.exit(1)

        # 2. 更新SSH配置
        config_mgr = SSHConfigManager(args.domain, args.type, key_gen.key_path)
        if not config_mgr.update_config():
            sys.exit(1)

        # 3. GitHub配置
        if not args.skip_upload and "github.com" in args.domain:
            logger.info("\n=== GitHub配置 ===")
            token = getpass.getpass("GitHub访问令牌（需admin:public_key权限）: ")
            title = f"{os.uname().nodename} [{args.type}] {datetime.now().strftime('%Y-%m-%d')}"
            
            github_mgr = GitHubManager(key_gen.pub_key, title)
            if not github_mgr.upload_key(token):
                logger.warning("GitHub配置未完成，但SSH配置已更新")

        # 4. 连接测试
        logger.info("\n=== 连接测试 ===")
        if not test_ssh_connection(config_mgr.host_alias):
            logger.error("SSH连接测试失败，请检查以下内容：")
            logger.error("1. 确保公钥已正确添加到Git平台")
            logger.error("2. 检查防火墙或网络设置")
            logger.error("3. 验证SSH配置是否正确")
            sys.exit(1)

        # 5. 输出使用说明
        logger.info("\n=== 配置完成 ===")
        print(f"\n使用方法：")
        print(f"1. 克隆新仓库：")
        print(f"   git clone git@{config_mgr.host_alias}:username/repo.git")
        print(f"\n2. 更新现有仓库远程地址：")
        print(f"   git remote set-url origin git@{config_mgr.host_alias}:username/repo.git")
        print(f"\n3. 验证连接：")
        print(f"   ssh -T git@{config_mgr.host_alias}")

    except KeyboardInterrupt:
        logger.info("\n操作已取消")
        sys.exit(1)
    except Exception as e:
        logger.error(f"致命错误: {str(e)}", exc_info=args.debug)
        sys.exit(1)

if __name__ == "__main__":
    main()