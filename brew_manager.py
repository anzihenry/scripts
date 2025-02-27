#!/usr/bin/env python3
import subprocess
import re
from datetime import datetime

# ---------------------- 配置区域 ----------------------
EXCLUDED_CASKS = [
    r"notion",                # 支持正则表达式
    r"zoom",
    r"microsoft-.*",
    r"adobe-.*",
    r"android-studio",
    r"docker",
    r"visual-studio-code",
    r"iterm2",
    r"epic-games",
    r"google-chrome",
    r"obsidian"
]

# -------------------- 功能实现 --------------------
class BrewManager:
    def __init__(self):
        self.colors = {
            'green': '\033[32m',
            'blue': '\033[34m',
            'yellow': '\033[33m',
            'red': '\033[31m',
            'reset': '\033[0m'
        }
        self.exclude_pattern = re.compile(r'^(' + '|'.join(EXCLUDED_CASKS) + r')$')

    def _print(self, color, message):
        print(f"{self.colors[color]}{message}{self.colors['reset']}")

    def _run_cmd(self, cmd, check=True):
        try:
            result = subprocess.run(
                cmd, 
                shell=True, 
                check=check,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            self._print('red', f"命令执行失败: {e.cmd}\n错误信息: {e.stdout}")
            return None

    def update_brew(self):
        self._print('green', "\n🔧 正在更新Homebrew...")
        self._run_cmd("brew update")

    def update_formulae(self):
        self._print('green', "\n📦 正在更新常规软件包...")
        self._run_cmd("brew upgrade")

    def _get_outdated_casks(self):
        output = self._run_cmd("brew outdated --cask --greedy", check=False)
        if not output:
            return []
            
        casks = []
        for line in output.split('\n'):
            # 使用正则提取纯Cask名称
            match = re.match(r'^([a-zA-Z0-9-]+)\b', line)
            if match:
                casks.append(match.group(1).lower())  # 统一转为小写
        return list(set(casks))  # 去重

    def update_casks(self):
        self._print('green', "\n🖥️ 正在检测可更新的Cask应用...")
        outdated_casks = self._get_outdated_casks()
        
        if not outdated_casks:
            self._print('yellow', "\n⏳ 没有检测到需要更新的Cask应用")
            return

        total = len(outdated_casks)
        filtered = [cask for cask in outdated_casks 
                   if not self.exclude_pattern.match(cask)]
        filtered_count = len(filtered)
        
        self._print('yellow', 
            f"\n⏳ 发现 {total} 个可更新应用，已排除 {total - filtered_count} 个")

        for idx, cask in enumerate(filtered, 1):
            self._print('blue', f"\n🔍 正在处理 ({idx}/{filtered_count}): {cask}")
            
            # 前置校验
            if not self._cask_exists(cask):
                self._print('red', f"❌ Cask '{cask}' 不存在或已失效")
                continue
                
            result = self._run_cmd(f"brew upgrade --cask {cask}", check=False)
            if not result or "Error" in result:
                self._log_error(cask)

    def _cask_exists(self, cask):
        return self._run_cmd(f"brew info --cask {cask}") is not None

    def _log_error(self, cask):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open("brew_update_errors.log", "a") as f:
            f.write(f"{timestamp} 更新失败: {cask}\n")
        self._print('red', f"❌ 更新失败: {cask} (已记录到日志)")

    def perform_cleanup(self):
        self._print('green', "\n🗑️ 正在清理系统...")
        self._run_cmd("brew cleanup")

# ---------------------- 主程序 ----------------------
if __name__ == "__main__":
    print("\033c", end="")  # 清屏
    print("🚀 开始执行Homebrew智能维护")
    
    manager = BrewManager()
    manager.update_brew()
    manager.update_formulae()
    manager.update_casks()
    manager.perform_cleanup()
    
    manager._print('green', "\n✅ 所有操作已完成！建议重启终端使变更生效")