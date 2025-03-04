#!/usr/bin/env python3
import os
import platform
import re
import sys
import argparse
import subprocess
import getpass
from pathlib import Path
from tempfile import NamedTemporaryFile
import requests
from requests.auth import HTTPBasicAuth

class SSHConfigurator:
    def __init__(self):
        self.config = {
            'default_key_type': 'ed25519',
            'default_domain': 'github.com',
            'default_usage': 'personal',
            'ssh_dir': Path.home() / '.ssh',
            'known_hosts': ['github.com', 'gitlab.com', 'bitbucket.org']
        }
        self.args = self.parse_arguments()
        self.validate_arguments()
        self.key_file = self.generate_key_filename()
        self.pub_key = None

    def parse_arguments(self):
        parser = argparse.ArgumentParser(
            description='SSH密钥管理与Git平台自动配置工具',
            formatter_class=argparse.RawTextHelpFormatter
        )
        parser.add_argument('-d', '--domain', 
                          help='目标Git平台域名 (如: github.com)')
        parser.add_argument('-t', '--usage-type', choices=['personal', 'work'],
                          help='密钥用途类型')
        parser.add_argument('--skip-api', action='store_true',
                          help='跳过GitHub API配置步骤')
        return parser.parse_args()

    def validate_arguments(self):
        """参数有效性验证"""
        if self.args.domain and not self.validate_domain(self.args.domain):
            raise ValueError(f"无效域名格式: {self.args.domain}")
            
        if self.args.usage_type and self.args.usage_type not in ['personal', 'work']:
            raise ValueError("用途类型必须为 personal 或 work")

    @staticmethod
    def validate_domain(domain: str) -> bool:
        """域名格式验证"""
        pattern = r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
        return re.match(pattern, domain) is not None

    def generate_key_filename(self) -> Path:
        """生成符合命名规范的密钥文件名"""
        domain = self.args.domain or self.config['default_domain']
        usage_type = self.args.usage_type or self.config['default_usage']
        
        # 域名规范化处理
        domain_part = re.sub(r'[^a-zA-Z0-9]', '_', domain.split('.')[0])
        return self.config['ssh_dir'] / f"id_{self.config['default_key_type']}_{domain_part}_{usage_type}"

    def setup_ssh_directory(self):
        """创建并配置SSH目录"""
        try:
            self.config['ssh_dir'].mkdir(exist_ok=True)
            self.config['ssh_dir'].chmod(0o700)
        except PermissionError as e:
            raise RuntimeError(f"无法创建SSH目录: {e}") from e

    def handle_existing_keys(self) -> bool:
        """处理现有密钥文件"""
        if not self.key_file.exists():
            return True

        print(f"检测到现有密钥: {self.key_file}")
        choice = input("是否备份并生成新密钥？(y/N) ").lower()
        if choice != 'y':
            self.pub_key = self.key_file.with_suffix('.pub').read_text()
            return False

        backup = self.key_file.with_name(f"{self.key_file.name}.bak")
        try:
            self.key_file.rename(backup)
            self.key_file.with_suffix('.pub').rename(backup.with_suffix('.pub'))
            print(f"原密钥已备份至: {backup}")
        except OSError as e:
            raise RuntimeError(f"密钥备份失败: {e}") from e
        return True

    def generate_ssh_key(self):
        """生成新的SSH密钥对"""
        if not self.handle_existing_keys():
            return

        print(f"生成新的 {self.config['default_key_type'].upper()} 密钥...")
        try:
            subprocess.run([
                'ssh-keygen', '-t', self.config['default_key_type'],
                '-C', self.get_key_comment(),
                '-f', str(self.key_file),
                '-N', ''
            ], check=True)
        except subprocess.CalledProcessError as e:
            raise RuntimeError("密钥生成失败") from e

        self.key_file.chmod(0o600)
        self.key_file.with_suffix('.pub').chmod(0o644)
        self.pub_key = self.key_file.with_suffix('.pub').read_text()

    def get_key_comment(self) -> str:
        """生成密钥注释信息"""
        email = self.get_git_email()
        domain = self.args.domain or self.config['default_domain']
        usage = self.args.usage_type or self.config['default_usage']
        return f"{email} [{usage}@{domain}]"

    @staticmethod
    def get_git_email() -> str:
        """获取并验证Git邮箱"""
        email = subprocess.run(
            ['git', 'config', '--global', 'user.email'],
            capture_output=True, text=True
        ).stdout.strip()

        while not re.match(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$', email):
            email = input("请输入有效的Git全局邮箱地址: ").strip()
            subprocess.run(['git', 'config', '--global', 'user.email', email], check=True)
        
        return email

    def update_known_hosts(self):
        """更新known_hosts文件"""
        known_hosts = self.config['ssh_dir'] / 'known_hosts'
        try:
            known_hosts.touch()
            known_hosts.chmod(0o644)
            
            current_hosts = known_hosts.read_text()
            for host in self.config['known_hosts']:
                if host not in current_hosts:
                    print(f"添加 {host} 到 known_hosts...")
                    result = subprocess.run(
                        ['ssh-keyscan', '-H', host],
                        capture_output=True, text=True
                    )
                    known_hosts.write_text(current_hosts + result.stdout)
        except IOError as e:
            print(f"更新known_hosts失败: {e}")

    def configure_github(self):
        """通过GitHub API配置公钥"""
        if self.args.skip_api:
            return

        domain = self.args.domain or self.config['default_domain']
        if 'github' not in domain:
            return

        print("\n=== GitHub配置 ===")
        username = input("GitHub用户名: ")
        token = getpass.getpass("GitHub访问令牌（需admin:public_key权限）: ")

        headers = {'Accept': 'application/vnd.github+json'}
        data = {
            'title': self.generate_key_title(),
            'key': self.pub_key
        }

        print(f"token is {token}")

        try:
            response = requests.post(
                'https://api.github.com/user/keys',
                auth=HTTPBasicAuth(username, token),
                headers=headers,
                json=data,
                timeout=10
            )
            self.handle_api_response(response)
        except requests.exceptions.RequestException as e:
            print(f"API请求失败: {e}")

    def generate_key_title(self) -> str:
        """生成密钥标题"""
        hostname = platform.node()
        return f"{hostname} [{self.args.usage_type}] {self.key_file.name}"

    @staticmethod
    def handle_api_response(response: requests.Response):
        """处理API响应"""
        if response.status_code == 201:
            print("✓ 公钥已成功添加到GitHub")
        elif response.status_code == 422:
            print("⚠ 公钥已存在")
        elif response.status_code in (401, 403):
            print("✗ 认证失败，请检查令牌权限")
        else:
            print(f"✗ 添加公钥失败 (HTTP {response.status_code})")
            print("响应详情:", response.text)

    def test_connection(self):
        """测试SSH连接"""
        domain = self.args.domain or self.config['default_domain']
        print(f"\n测试连接到 {domain}...")
        try:
            result = subprocess.run(
                ['ssh', '-T', f'git@{domain}'],
                capture_output=True, text=True
            )
            if 'successfully authenticated' in result.stderr:
                print("✓ SSH连接验证成功")
            else:
                print("连接验证异常:", result.stderr.strip())
        except subprocess.CalledProcessError as e:
            print(f"连接测试失败: {e}")

    def print_key_info(self):
        """显示密钥信息"""
        print("\n=== 密钥信息 ===")
        print("私钥路径:", self.key_file)
        print("公钥路径:", self.key_file.with_suffix('.pub'))
        
        try:
            result = subprocess.run(
                ['ssh-keygen', '-lv', '-f', str(self.key_file)],
                capture_output=True, text=True
            )
            print("\n密钥指纹:")
            print(result.stdout.strip())
        except subprocess.CalledProcessError:
            print("无法获取密钥指纹")

    def run(self):
        """主执行流程"""
        try:
            self.setup_ssh_directory()
            self.generate_ssh_key()
            self.update_known_hosts()
            self.configure_github()
            self.test_connection()
            self.print_key_info()
            print("\n✓ 配置完成")
        except Exception as e:
            print(f"\n✗ 发生错误: {e}")
            sys.exit(1)

if __name__ == '__main__':
    configurator = SSHConfigurator()
    configurator.run()