class MacosScripts < Formula
  desc "Unified macOS automation CLI for setup, maintenance, jobs, and lint"
  homepage "https://github.com/anzihenry/scripts"
  url "https://github.com/anzihenry/scripts/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "4dc4e198f9a5314728b9d99fba3828e84fef67a3e7147f1d3161200bf4b0ee04"
  version "0.1.0"
  license "MIT"

  head "https://github.com/anzihenry/scripts.git", branch: "main"

  def install
    libexec.install "bin", "bootstrap", "job", "lib", "lint", "maintain", "setup", "README.md", "LICENSE"
    bin.install_symlink libexec/"bin/macos-scripts"
  end

  def caveats
    <<~EOS
      macos-scripts 已安装。

      常用命令：
        macos-scripts --help
        macos-scripts maintain brew --dry-run
        macos-scripts job list

      默认日志目录：
        ~/Library/Logs/macos-scripts

      默认配置目录：
        ~/.config/macos-scripts

      全新 macOS 首次安装请使用独立 bootstrap 入口（正式发布示例）：
        BOOTSTRAP_TAG=v0.1.0
        curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh

      如需安装开发中的最新版本，可选：
        brew install --HEAD anzihenry/scripts/macos-scripts
    EOS
  end

  test do
    assert_match "macos-scripts v", shell_output("#{bin}/macos-scripts --version")
    assert_match "macos-scripts setup git", shell_output("#{bin}/macos-scripts help setup git")
    assert_match "macos-scripts job create", shell_output("#{bin}/macos-scripts help job create")
  end
end