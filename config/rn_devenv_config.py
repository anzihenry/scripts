#!/usr/bin/env python3
import os
import subprocess
import sys
import platform

# 颜色常量用于控制台输出
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
RESET = "\033[0m"
BOLD = "\033[1m"

def print_status(message, status_type="info"):
    """格式化状态消息打印"""
    if status_type == "success":
        print(f"{GREEN}✓ {message}{RESET}")
    elif status_type == "warning":
        print(f"{YELLOW}⚠ {message}{RESET}")
    elif status_type == "error":
        print(f"{RED}✗ {message}{RESET}")
    elif status_type == "header":
        print(f"\n{BOLD}{message}{RESET}")
    else:
        print(f"  {message}")

def run_command(command, check_output=False):
    """执行命令并返回结果"""
    try:
        if check_output:
            result = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT, text=True)
            return result.strip()
        else:
            subprocess.run(command, shell=True, check=True)
            return True
    except subprocess.CalledProcessError as e:
        return False

def check_homebrew():
    """检查是否安装了Homebrew"""
    print_status("检查 Homebrew...", "header")
    if run_command("which brew", check_output=True):
        print_status("Homebrew 已安装", "success")
        return True
    else:
        print_status("未检测到 Homebrew", "error")
        print_status("请通过以下命令安装 Homebrew:")
        print_status('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
        return False

def check_and_install_node():
    """检查并安装 Node.js"""
    print_status("检查 Node.js...", "header")
    if run_command("which node", check_output=True):
        node_version = run_command("node -v", check_output=True)
        print_status(f"Node.js {node_version} 已安装", "success")
    else:
        print_status("安装 Node.js...", "info")
        if run_command("brew install node"):
            print_status("Node.js 安装成功", "success")
        else:
            print_status("Node.js 安装失败", "error")
            return False
    
    # 检查 npm
    if run_command("which npm", check_output=True):
        npm_version = run_command("npm -v", check_output=True)
        print_status(f"npm {npm_version} 已安装", "success")
    else:
        print_status("npm 未安装，可能是 Node.js 安装不完整", "error")
        return False
    
    return True

def check_and_install_watchman():
    """检查并安装 Watchman"""
    print_status("检查 Watchman...", "header")
    if run_command("which watchman", check_output=True):
        watchman_version = run_command("watchman --version", check_output=True)
        print_status(f"Watchman {watchman_version} 已安装", "success")
    else:
        print_status("安装 Watchman...", "info")
        if run_command("brew install watchman"):
            print_status("Watchman 安装成功", "success")
        else:
            print_status("Watchman 安装失败", "error")
            return False
    return True

def check_and_install_jdk():
    """检查并安装 JDK"""
    print_status("检查 JDK...", "header")
    if run_command("javac -version", check_output=True):
        java_version = run_command("javac -version", check_output=True)
        print_status(f"JDK {java_version} 已安装", "success")
    else:
        print_status("安装 JDK...", "info")
        if run_command("brew install --cask adoptopenjdk/openjdk/adoptopenjdk11"):
            print_status("JDK 安装成功", "success")
        else:
            print_status("JDK 安装失败", "error")
            print_status("请手动安装 JDK 11 或更高版本", "warning")
            return False
    return True

def check_xcode():
    """检查 Xcode"""
    print_status("检查 Xcode...", "header")
    if run_command("xcode-select -p", check_output=True):
        print_status("Xcode 命令行工具已安装", "success")
    else:
        print_status("安装 Xcode 命令行工具...", "info")
        print_status("运行: xcode-select --install")
        run_command("xcode-select --install")
        input("按 Enter 键继续安装过程...")
    return True

def check_and_install_cocoapods():
    """检查并安装 CocoaPods"""
    print_status("检查 CocoaPods...", "header")
    if run_command("which pod", check_output=True):
        pod_version = run_command("pod --version", check_output=True)
        print_status(f"CocoaPods {pod_version} 已安装", "success")
    else:
        print_status("安装 CocoaPods...", "info")
        if run_command("sudo gem install cocoapods"):
            print_status("CocoaPods 安装成功", "success")
        else:
            print_status("尝试通过 Homebrew 安装 CocoaPods...", "info")
            if run_command("brew install cocoapods"):
                print_status("CocoaPods 安装成功", "success")
            else:
                print_status("CocoaPods 安装失败", "error")
                return False
    return True

def check_android_studio():
    """检查 Android Studio"""
    print_status("检查 Android Studio...", "header")
    android_studio_path = "/Applications/Android Studio.app"
    
    if os.path.exists(android_studio_path):
        print_status("Android Studio 已安装", "success")
    else:
        print_status("未检测到 Android Studio", "warning")
        print_status("请从以下网址下载并安装 Android Studio:", "info")
        print_status("https://developer.android.com/studio")
    
    # 检查 ANDROID_HOME 环境变量
    android_home = os.environ.get("ANDROID_HOME")
    if android_home:
        print_status(f"ANDROID_HOME 已设置: {android_home}", "success")
    else:
        default_android_home = os.path.expanduser("~/Library/Android/sdk")
        print_status("未设置 ANDROID_HOME 环境变量", "warning")
        print_status(f"建议添加以下内容到 ~/.zshrc 或 ~/.bash_profile:", "info")
        print_status(f'export ANDROID_HOME="{default_android_home}"')
        print_status(f'export PATH="$PATH:$ANDROID_HOME/emulator"')
        print_status(f'export PATH="$PATH:$ANDROID_HOME/tools"')
        print_status(f'export PATH="$PATH:$ANDROID_HOME/tools/bin"')
        print_status(f'export PATH="$PATH:$ANDROID_HOME/platform-tools"')
    
    return True

def check_and_install_react_native_cli():
    """检查并安装 React Native CLI"""
    print_status("检查 React Native CLI...", "header")
    if run_command("which react-native", check_output=True):
        rn_version = run_command("react-native --version", check_output=True)
        print_status(f"React Native CLI {rn_version} 已安装", "success")
    else:
        print_status("安装 React Native CLI...", "info")
        if run_command("npm install -g react-native-cli"):
            print_status("React Native CLI 安装成功", "success")
        else:
            print_status("React Native CLI 安装失败", "error")
            return False
    return True

def main():
    """主函数"""
    print_status("开始配置 React Native 开发环境", "header")
    
    # 检查系统
    if platform.system() != "Darwin":
        print_status("此脚本仅支持 macOS 系统", "error")
        sys.exit(1)
    
    # 执行安装流程
    homebrew_ok = check_homebrew()
    if not homebrew_ok:
        print_status("请先安装 Homebrew，然后重新运行此脚本", "error")
        sys.exit(1)
    
    node_ok = check_and_install_node()
    watchman_ok = check_and_install_watchman()
    
    # iOS 开发环境
    xcode_ok = check_xcode()
    cocoapods_ok = check_and_install_cocoapods()
    
    # Android 开发环境
    jdk_ok = check_and_install_jdk()
    android_studio_ok = check_android_studio()
    
    # React Native CLI
    rn_cli_ok = check_and_install_react_native_cli()
    
    # 总结
    print_status("\n========== React Native 开发环境配置摘要 ==========", "header")
    print_status(f"Node.js: {'✓' if node_ok else '✗'}")
    print_status(f"Watchman: {'✓' if watchman_ok else '✗'}")
    print_status(f"Xcode CLI: {'✓' if xcode_ok else '✗'}")
    print_status(f"CocoaPods: {'✓' if cocoapods_ok else '✗'}")
    print_status(f"JDK: {'✓' if jdk_ok else '✗'}")
    print_status(f"Android Studio: {'检查过' if android_studio_ok else '✗'}")
    print_status(f"React Native CLI: {'✓' if rn_cli_ok else '✗'}")
    
    print_status("\n接下来，您可以通过以下命令创建新的 React Native 项目:", "header")
    print_status("npx react-native init MyApp")
    print_status("cd MyApp")
    print_status("npx react-native run-ios  # 运行 iOS 版本")
    print_status("npx react-native run-android  # 运行 Android 版本")

if __name__ == "__main__":
    main()