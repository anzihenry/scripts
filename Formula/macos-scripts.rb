class MacosScripts < Formula
  desc "Unified macOS automation CLI for setup, maintenance, jobs, and lint"
  homepage "https://github.com/anzihenry/scripts"
  url "https://github.com/anzihenry/scripts/archive/refs/tags/v0.5.0.tar.gz"
  # Homebrew infers the stable version from the tag URL.
  sha256 "b98a376042a48ee0d1466024d70a6cbca4f5984c77d25ef5a7e7467417d81757"
  license "MIT"

  head "https://github.com/anzihenry/scripts.git", branch: "main"

  def install
    libexec.install "bin", "bootstrap", "job", "lib", "lint", "maintain", "setup", "VERSION", "README.md", "LICENSE"
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
        BOOTSTRAP_TAG=v0.5.0
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
