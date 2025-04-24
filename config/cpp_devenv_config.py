#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
C++ 跨平台共享库开发环境配置工具
该脚本列出了C++开发跨平台共享库所需的各种工具和资源
"""

class CppDevEnvironment:
    def __init__(self):
        # 定义必要的开发工具
        self.compilers = [
            {
                "name": "GCC/G++",
                "description": "GNU Compiler Collection，主要用于Linux和Unix系统",
                "windows": "可通过MinGW或Cygwin安装",
                "macos": "可通过Homebrew安装: brew install gcc",
                "linux": "大多数发行版预装或通过包管理器安装: apt install build-essential"
            },
            {
                "name": "Clang/LLVM",
                "description": "优秀的跨平台编译器，C++标准支持好",
                "windows": "可通过LLVM官网或Visual Studio安装",
                "macos": "Xcode自带或通过Homebrew安装: brew install llvm",
                "linux": "通过包管理器安装: apt install clang"
            },
            {
                "name": "MSVC",
                "description": "微软Visual C++编译器，用于Windows平台",
                "windows": "通过Visual Studio安装",
                "macos": "不适用",
                "linux": "不适用"
            }
        ]
        
        self.build_tools = [
            {
                "name": "CMake",
                "description": "跨平台构建工具，适合管理大型项目",
                "windows": "通过官网安装包或vcpkg",
                "macos": "brew install cmake",
                "linux": "apt install cmake"
            },
            {
                "name": "Ninja",
                "description": "快速的构建系统，与CMake配合使用效果好",
                "windows": "通过官网或chocolatey安装",
                "macos": "brew install ninja",
                "linux": "apt install ninja-build"
            },
            {
                "name": "Make",
                "description": "传统的Unix构建工具",
                "windows": "通过MinGW或Cygwin安装",
                "macos": "Xcode命令行工具自带",
                "linux": "通常预装"
            }
        ]
        
        self.package_managers = [
            {
                "name": "vcpkg",
                "description": "微软开发的C++库管理器，跨平台支持好",
                "url": "https://github.com/microsoft/vcpkg"
            },
            {
                "name": "Conan",
                "description": "Python开发的C++包管理器",
                "url": "https://conan.io/"
            }
        ]
        
        self.version_control = [
            {
                "name": "Git",
                "description": "分布式版本控制系统，几乎是标准配置",
                "windows": "通过Git for Windows安装",
                "macos": "通过Homebrew安装或Xcode自带",
                "linux": "apt install git"
            }
        ]
        
        self.debugging_tools = [
            {
                "name": "GDB",
                "description": "GNU调试器，功能强大",
                "windows": "通过MinGW安装",
                "macos": "brew install gdb",
                "linux": "apt install gdb"
            },
            {
                "name": "LLDB",
                "description": "LLVM调试器，与Clang配合良好",
                "windows": "随LLVM安装",
                "macos": "Xcode自带",
                "linux": "apt install lldb"
            }
        ]
        
        self.static_analyzers = [
            {
                "name": "Clang-Tidy",
                "description": "基于Clang的静态代码分析工具",
                "windows": "随LLVM安装",
                "macos": "brew install llvm (包含clang-tidy)",
                "linux": "apt install clang-tidy"
            },
            {
                "name": "Cppcheck",
                "description": "专注于检测未定义行为和危险编码的静态分析工具",
                "windows": "通过官网安装包",
                "macos": "brew install cppcheck",
                "linux": "apt install cppcheck"
            }
        ]
        
        self.formatting_tools = [
            {
                "name": "Clang-Format",
                "description": "代码格式化工具，可定制化强",
                "windows": "随LLVM安装",
                "macos": "brew install clang-format",
                "linux": "apt install clang-format"
            }
        ]
        
        self.documentation_tools = [
            {
                "name": "Doxygen",
                "description": "从源代码生成文档的工具",
                "windows": "通过官网安装包",
                "macos": "brew install doxygen",
                "linux": "apt install doxygen"
            }
        ]
        
        self.testing_frameworks = [
            {
                "name": "Google Test",
                "description": "Google的C++测试框架",
                "url": "https://github.com/google/googletest"
            },
            {
                "name": "Catch2",
                "description": "轻量级的C++测试框架",
                "url": "https://github.com/catchorg/Catch2"
            }
        ]
        
        self.cross_platform_libraries = [
            {
                "name": "Boost",
                "description": "流行的C++库集合，提供许多通用功能",
                "url": "https://www.boost.org/"
            },
            {
                "name": "Qt",
                "description": "跨平台应用程序框架，特别适合GUI开发",
                "url": "https://www.qt.io/"
            },
            {
                "name": "spdlog",
                "description": "快速的C++日志库",
                "url": "https://github.com/gabime/spdlog"
            },
            {
                "name": "nlohmann/json",
                "description": "JSON处理库",
                "url": "https://github.com/nlohmann/json"
            }
        ]
        
        self.profiling_tools = [
            {
                "name": "Valgrind",
                "description": "内存泄漏检测和性能分析工具",
                "windows": "通过WSL使用",
                "macos": "brew install valgrind",
                "linux": "apt install valgrind"
            },
            {
                "name": "Perf",
                "description": "Linux性能分析工具",
                "windows": "不适用",
                "macos": "不适用",
                "linux": "apt install linux-tools-common linux-tools-generic"
            }
        ]
        
        self.ides = [
            {
                "name": "Visual Studio Code",
                "description": "轻量级但功能强大的编辑器，配合C++插件使用",
                "url": "https://code.visualstudio.com/",
                "extensions": ["ms-vscode.cpptools", "ms-vscode.cmake-tools", "twxs.cmake"]
            },
            {
                "name": "CLion",
                "description": "专业C++IDE，功能全面",
                "url": "https://www.jetbrains.com/clion/"
            },
            {
                "name": "Visual Studio",
                "description": "Windows平台专业IDE",
                "url": "https://visualstudio.microsoft.com/"
            }
        ]

    def print_environment_info(self):
        """打印所有开发环境信息"""
        print("=== C++ 跨平台共享库开发环境配置 ===\n")
        
        print("== 编译器 ==")
        for item in self.compilers:
            print(f"- {item['name']}: {item['description']}")
        print()
        
        print("== 构建工具 ==")
        for item in self.build_tools:
            print(f"- {item['name']}: {item['description']}")
        print()
        
        print("== 包管理器 ==")
        for item in self.package_managers:
            print(f"- {item['name']}: {item['description']}")
        print()
        
        # 继续打印其他类别...
        # 此处省略其他类别的打印代码，实际使用时可以按需添加

def main():
    env = CppDevEnvironment()
    env.print_environment_info()
    
    print("\n注意: 此脚本仅列出工具，需要根据具体平台和需求进行安装配置")
    print("对于跨平台共享库开发，推荐使用CMake构建系统和vcpkg包管理器")

if __name__ == "__main__":
    main()