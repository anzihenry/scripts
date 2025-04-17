#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""iOS开发环境配置与验证工具"""

import os
import subprocess
import sys

# Xcode路径配置
XCODE_PATH = "/Applications/Xcode.app"
XCODE_DEVELOPER_PATH = f"{XCODE_PATH}/Contents/Developer"

# iOS SDK配置
IOS_SDK_PATH = f"{XCODE_DEVELOPER_PATH}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
IOS_SIMULATOR_SDK_PATH = f"{XCODE_DEVELOPER_PATH}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"

# 工具链配置
TOOLCHAIN_PATH = f"{XCODE_DEVELOPER_PATH}/Toolchains/XcodeDefault.xctoolchain"
CLANG_PATH = f"{TOOLCHAIN_PATH}/usr/bin/clang"
CLANGPP_PATH = f"{TOOLCHAIN_PATH}/usr/bin/clang++"

# 构建工具配置
XCODEBUILD_PATH = f"{XCODE_DEVELOPER_PATH}/usr/bin/xcodebuild"
XCRUN_PATH = f"{XCODE_DEVELOPER_PATH}/usr/bin/xcrun"

# 包管理工具配置
COCOAPODS_PATH = "/usr/local/bin/pod"
FASTLANE_PATH = "/usr/local/bin/fastlane"

# 证书和配置文件路径
PROVISIONING_PROFILES_PATH = "~/Library/MobileDevice/Provisioning Profiles"
KEYCHAINS_PATH = "~/Library/Keychains"

# 模拟器配置
SIMULATOR_PATH = f"{XCODE_PATH}/Contents/Developer/Applications/Simulator.app"

# Ruby与Gem配置（Fastlane依赖）
RUBY_PATH = "/usr/bin/ruby"
GEM_PATH = "/usr/bin/gem"

def run_command(command, silent=False):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(command, 
                                capture_output=True, 
                                text=True,
                                check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if not silent:
            print(f"执行命令失败: {' '.join(command)}")
            print(f"错误: {e.stderr}")
        return None

def get_xcode_version():
    """获取Xcode版本"""
    try:
        result = run_command([XCODEBUILD_PATH, '-version'])
        if result:
            return result.split('\n')[0].split(' ')[1]
        return None
    except:
        return None

def get_ios_sdk_version():
    """获取iOS SDK版本"""
    try:
        sdks = os.listdir(f"{XCODE_DEVELOPER_PATH}/Platforms/iPhoneOS.platform/Developer/SDKs/")
        versions = [sdk.replace('iPhoneOS', '').replace('.sdk', '') 
                   for sdk in sdks if sdk.startswith('iPhoneOS')]
        return max(versions) if versions else None
    except:
        return None

def get_cocoapods_version():
    """获取CocoaPods版本"""
    return run_command(['pod', '--version'], silent=True)

def get_fastlane_version():
    """获取Fastlane版本"""
    return run_command(['fastlane', '--version'], silent=True)

def get_ruby_version():
    """获取Ruby版本"""
    result = run_command(['ruby', '-v'], silent=True)
    if result:
        return result.split()[1]
    return None

def validate_environment(full_check=True):
    """验证iOS开发环境配置"""
    print("开始验证iOS开发环境...")
    issues_found = False
    
    # 检查Xcode是否安装
    if not os.path.exists(XCODE_PATH):
        print("❌ 错误: 未找到Xcode，请确保Xcode已正确安装")
        issues_found = True
    else:
        xcode_version = get_xcode_version()
        print(f"✅ Xcode已安装: 版本 {xcode_version}")
        
        # 检查iOS SDK是否存在
        if not os.path.exists(IOS_SDK_PATH):
            print("❌ 错误: 未找到iOS SDK")
            issues_found = True
        else:
            ios_sdk_version = get_ios_sdk_version()
            print(f"✅ iOS SDK已安装: 版本 {ios_sdk_version}")
        
        # 检查编译工具是否存在
        if not os.path.exists(CLANG_PATH):
            print("❌ 错误: 未找到Clang编译器")
            issues_found = True
        else:
            print("✅ Clang编译器已安装")
        
        # 检查xcodebuild工具
        if not os.path.exists(XCODEBUILD_PATH):
            print("❌ 错误: 未找到xcodebuild工具")
            issues_found = True
        else:
            print("✅ xcodebuild工具已安装")
    
    # 检查CocoaPods
    cocoapods_version = get_cocoapods_version()
    if not cocoapods_version:
        print("❌ 警告: CocoaPods未安装或不在PATH中")
        if full_check:
            print("  提示: 可以通过运行 'sudo gem install cocoapods' 安装CocoaPods")
        issues_found = True
    else:
        print(f"✅ CocoaPods已安装: 版本 {cocoapods_version}")
    
    # 检查Fastlane
    fastlane_version = get_fastlane_version()
    if not fastlane_version:
        print("❌ 警告: Fastlane未安装或不在PATH中")
        if full_check:
            print("  提示: 可以通过运行 'sudo gem install fastlane' 安装Fastlane")
        issues_found = True
    else:
        print(f"✅ Fastlane已安装: 版本 {fastlane_version}")
    
    # 检查Ruby（Fastlane依赖）
    ruby_version = get_ruby_version()
    if not ruby_version:
        print("❌ 警告: 未找到Ruby，这可能会影响Fastlane和CocoaPods的运行")
        issues_found = True
    else:
        print(f"✅ Ruby已安装: 版本 {ruby_version}")
    
    # 总结
    if issues_found:
        print("\n⚠️ 发现一些问题，请解决上述问题以确保iOS开发环境正常工作")
        return False
    else:
        print("\n✅ iOS开发环境检查通过，所有必要工具已正确安装")
        return True

def setup_fastlane(project_path=None):
    """配置Fastlane"""
    if not get_fastlane_version():
        print("Fastlane未安装，正在尝试安装...")
        result = run_command(['sudo', 'gem', 'install', 'fastlane'])
        if not result:
            print("❌ Fastlane安装失败")
            return False
        print("✅ Fastlane安装成功")
    
    if not project_path:
        project_path = input("请输入iOS项目路径: ").strip()
    
    if not os.path.exists(project_path):
        print(f"❌ 错误: 项目路径 '{project_path}' 不存在")
        return False
    
    # 切换到项目目录
    original_dir = os.getcwd()
    os.chdir(project_path)
    
    try:
        # 初始化Fastlane
        print(f"在 {project_path} 中初始化Fastlane...")
        result = run_command(['fastlane', 'init'])
    finally:
        # 返回原目录
        os.chdir(original_dir)
    
    if not result:
        print("❌ Fastlane初始化失败")
        return False
    
    print("✅ Fastlane初始化成功")
    print("  请检查项目中的fastlane目录，根据需要编辑Fastfile和Appfile")
    return True

def show_environment_info():
    """显示环境信息"""
    print("\n=== iOS开发环境信息 ===")
    print(f"Xcode版本: {get_xcode_version() or '未安装'}")
    print(f"iOS SDK版本: {get_ios_sdk_version() or '未找到'}")
    print(f"CocoaPods版本: {get_cocoapods_version() or '未安装'}")
    print(f"Fastlane版本: {get_fastlane_version() or '未安装'}")
    print(f"Ruby版本: {get_ruby_version() or '未安装'}")
    print(f"Xcode路径: {XCODE_PATH if os.path.exists(XCODE_PATH) else '不存在'}")
    print("=======================\n")

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="iOS开发环境配置工具")
    parser.add_argument("--validate", action="store_true", help="验证iOS开发环境")
    parser.add_argument("--info", action="store_true", help="显示环境信息")
    parser.add_argument("--setup-fastlane", action="store_true", help="配置Fastlane")
    parser.add_argument("--project-path", help="iOS项目路径，用于Fastlane配置")
    
    args = parser.parse_args()
    
    if args.info or (not args.validate and not args.setup_fastlane):
        show_environment_info()
    
    if args.validate:
        validate_environment()
    
    if args.setup_fastlane:
        setup_fastlane(args.project_path)

if __name__ == "__main__":
    main()