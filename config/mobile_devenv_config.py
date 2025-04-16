#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""iOS开发环境配置"""

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

# CocoaPods配置
COCOAPODS_PATH = "/usr/local/bin/pod"

# 证书和配置文件路径
PROVISIONING_PROFILES_PATH = "~/Library/MobileDevice/Provisioning Profiles"
KEYCHAINS_PATH = "~/Library/Keychains"

# 模拟器配置
SIMULATOR_PATH = f"{XCODE_PATH}/Contents/Developer/Applications/Simulator.app"

def get_xcode_version():
    """获取Xcode版本"""
    import subprocess
    try:
        result = subprocess.run([XCODEBUILD_PATH, '-version'], 
                              capture_output=True, 
                              text=True)
        return result.stdout.split('\n')[0].split(' ')[1]
    except:
        return None

def get_ios_sdk_version():
    """获取iOS SDK版本"""
    import os
    try:
        sdks = os.listdir(f"{XCODE_DEVELOPER_PATH}/Platforms/iPhoneOS.platform/Developer/SDKs/")
        versions = [sdk.replace('iPhoneOS', '').replace('.sdk', '') 
                   for sdk in sdks if sdk.startswith('iPhoneOS')]
        return max(versions) if versions else None
    except:
        return None

def validate_environment():
    """验证iOS开发环境配置"""
    import os
    
    # 检查Xcode是否安装
    if not os.path.exists(XCODE_PATH):
        print("错误: 未找到Xcode，请确保Xcode已正确安装")
        return False
        
    # 检查iOS SDK是否存在
    if not os.path.exists(IOS_SDK_PATH):
        print("错误: 未找到iOS SDK")
        return False
        
    # 检查编译工具是否存在
    if not os.path.exists(CLANG_PATH):
        print("错误: 未找到Clang编译器")
        return False
        
    # 检查xcodebuild工具
    if not os.path.exists(XCODEBUILD_PATH):
        print("错误: 未找到xcodebuild工具")
        return False
        
    print("iOS开发环境检查通过")
    print(f"Xcode版本: {get_xcode_version()}")
    print(f"iOS SDK版本: {get_ios_sdk_version()}")
    return True

if __name__ == "__main__":
    validate_environment()