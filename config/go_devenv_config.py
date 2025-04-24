import os
import subprocess
import platform
import sys
from typing import Dict, List, Tuple

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Go Development Environment Configuration

This script provides configuration and setup for a comprehensive Go development
environment, focusing on server applications and command-line programs.
"""


class GoDevEnv:
    def __init__(self):
        self.system = platform.system()
        self.essential_tools = {
            "go": {
                "description": "Go programming language compiler and tools",
                "install_command": self._get_go_install_command(),
                "check_command": "go version",
            },
            "git": {
                "description": "Version control system",
                "install_command": self._get_git_install_command(),
                "check_command": "git --version",
            }
        }
        
        self.server_dev_tools = {
            "gin": {
                "description": "HTTP web framework",
                "install_command": "go get -u github.com/gin-gonic/gin",
            },
            "echo": {
                "description": "High performance web framework",
                "install_command": "go get github.com/labstack/echo/v4",
            },
            "fiber": {
                "description": "Express-inspired web framework",
                "install_command": "go get github.com/gofiber/fiber/v2",
            },
            "gorm": {
                "description": "ORM library for Go",
                "install_command": "go get -u gorm.io/gorm",
            },
            "sqlx": {
                "description": "Extensions to database/sql",
                "install_command": "go get github.com/jmoiron/sqlx",
            },
            "grpc": {
                "description": "gRPC for Go",
                "install_command": "go get -u google.golang.org/grpc",
            },
            "protoc": {
                "description": "Protocol Buffers compiler",
                "install_command": self._get_protoc_install_command(),
            },
            "migrate": {
                "description": "Database migration tool",
                "install_command": "go get -u github.com/golang-migrate/migrate/v4/cmd/migrate",
            }
        }
        
        self.cli_dev_tools = {
            "cobra": {
                "description": "Library for creating CLI applications",
                "install_command": "go get -u github.com/spf13/cobra@latest",
            },
            "urfave-cli": {
                "description": "Fast and simple CLI apps",
                "install_command": "go get github.com/urfave/cli/v2",
            },
            "viper": {
                "description": "Configuration solution for Go applications",
                "install_command": "go get github.com/spf13/viper",
            }
        }
        
        self.code_quality_tools = {
            "golangci-lint": {
                "description": "Fast Go linters runner",
                "install_command": "go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest",
                "check_command": "golangci-lint --version",
            },
            "staticcheck": {
                "description": "Static analysis tool",
                "install_command": "go install honnef.co/go/tools/cmd/staticcheck@latest",
                "check_command": "staticcheck -version",
            },
            "goimports": {
                "description": "Command to fix imports",
                "install_command": "go install golang.org/x/tools/cmd/goimports@latest",
                "check_command": "goimports -h",
            }
        }
        
        self.debugging_tools = {
            "delve": {
                "description": "Debugger for Go",
                "install_command": "go install github.com/go-delve/delve/cmd/dlv@latest",
                "check_command": "dlv version",
            }
        }
        
        self.development_utilities = {
            "air": {
                "description": "Live reload for Go apps",
                "install_command": "go install github.com/cosmtrek/air@latest",
                "check_command": "air -v",
            },
            "docker": {
                "description": "Container platform",
                "install_command": self._get_docker_install_command(),
                "check_command": "docker --version",
            },
            "kubectl": {
                "description": "Kubernetes command line tool",
                "install_command": self._get_kubectl_install_command(),
                "check_command": "kubectl version --client",
            },
            "mockgen": {
                "description": "Mock generator for Go interfaces",
                "install_command": "go install github.com/golang/mock/mockgen@latest",
                "check_command": "mockgen -version",
            },
            "goreleaser": {
                "description": "Release automation tool",
                "install_command": "go install github.com/goreleaser/goreleaser@latest",
                "check_command": "goreleaser --version",
            }
        }
        
        self.testing_tools = {
            "testify": {
                "description": "Testing toolkit",
                "install_command": "go get github.com/stretchr/testify",
            }
        }
        
    def _get_go_install_command(self) -> str:
        if self.system == "Darwin":  # macOS
            return "brew install go"
        elif self.system == "Linux":
            return "sudo apt-get install golang"  # For Debian/Ubuntu
        elif self.system == "Windows":
            return "choco install golang"
        return "Visit https://golang.org/dl/ to download"
    
    def _get_git_install_command(self) -> str:
        if self.system == "Darwin":
            return "brew install git"
        elif self.system == "Linux":
            return "sudo apt-get install git"
        elif self.system == "Windows":
            return "choco install git"
        return "Visit https://git-scm.com/downloads to download"
    
    def _get_protoc_install_command(self) -> str:
        if self.system == "Darwin":
            return "brew install protobuf"
        elif self.system == "Linux":
            return "sudo apt-get install protobuf-compiler"
        elif self.system == "Windows":
            return "choco install protoc"
        return "Visit https://github.com/protocolbuffers/protobuf/releases to download"
    
    def _get_docker_install_command(self) -> str:
        if self.system == "Darwin":
            return "brew install --cask docker"
        elif self.system == "Linux":
            return "sudo apt-get install docker.io"
        elif self.system == "Windows":
            return "choco install docker-desktop"
        return "Visit https://docs.docker.com/get-docker/ to download"
    
    def _get_kubectl_install_command(self) -> str:
        if self.system == "Darwin":
            return "brew install kubectl"
        elif self.system == "Linux":
            return "sudo apt-get install kubectl"
        elif self.system == "Windows":
            return "choco install kubernetes-cli"
        return "Visit https://kubernetes.io/docs/tasks/tools/install-kubectl/ to download"
    
    def get_all_tools(self) -> Dict:
        """Get all defined tools combined into a single dictionary."""
        all_tools = {}
        all_tools.update(self.essential_tools)
        all_tools.update(self.server_dev_tools)
        all_tools.update(self.cli_dev_tools)
        all_tools.update(self.code_quality_tools)
        all_tools.update(self.debugging_tools)
        all_tools.update(self.development_utilities)
        all_tools.update(self.testing_tools)
        return all_tools
    
    def check_installed_tools(self) -> Dict[str, bool]:
        """Check which tools are installed on the system."""
        results = {}
        for name, tool in self.get_all_tools().items():
            if "check_command" in tool:
                try:
                    subprocess.run(tool["check_command"].split(), 
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  check=True)
                    results[name] = True
                except (subprocess.SubprocessError, FileNotFoundError):
                    results[name] = False
            else:
                results[name] = None  # Cannot check
        return results
    
    def print_installation_guide(self):
        """Print a guide for installing all tools."""
        all_tools = self.get_all_tools()
        installed = self.check_installed_tools()
        
        print("Go Development Environment Setup Guide")
        print("=====================================")
        print()
        
        categories = [
            ("Essential Tools", self.essential_tools),
            ("Server Development", self.server_dev_tools),
            ("CLI Development", self.cli_dev_tools),
            ("Code Quality", self.code_quality_tools),
            ("Debugging", self.debugging_tools),
            ("Development Utilities", self.development_utilities),
            ("Testing", self.testing_tools)
        ]
        
        for category_name, tools in categories:
            print(f"\n{category_name}:")
            print("-" * len(category_name))
            
            for name, tool in tools.items():
                status = "✓ Installed" if installed.get(name, False) else "✗ Not installed"
                print(f"{name}: {tool['description']} [{status}]")
                if not installed.get(name, False):
                    print(f"    Install command: {tool['install_command']}")
            
        print("\nAdditional recommended setup:")
        print("- Set GOPATH environment variable")
        print("- Add $GOPATH/bin to your PATH")
        print("- Configure your IDE (VSCode with Go extension recommended)")

if __name__ == "__main__":
    go_env = GoDevEnv()
    go_env.print_installation_guide()