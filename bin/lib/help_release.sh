#!/bin/zsh
# filepath: bin/lib/help_release.sh

print_release_publish_help() {
  cat <<'EOF'
用法:
  macos-scripts release publish <tag> [选项]

说明:
  创建或更新 GitHub Release。
  默认自动使用 releases/<tag>-release-notes.md 作为 notes 文件。

位置参数:
  <tag>                    Git tag，例如 0.5.0 或 v0.5.0

选项:
  --notes-file <path>      自定义 Release note 文件路径
  --target <branch>        Release target，默认 main
  --title <title>          Release 标题，默认与 tag 相同
  --repo <owner/name>      GitHub 仓库，默认 anzihenry/scripts
  --yes                    跳过交互确认
  --dry-run                仅打印将执行的动作
  -h, --help               显示帮助
EOF
}

print_release_verify_help() {
  cat <<'EOF'
用法:
  macos-scripts release verify <tag> [选项]

说明:
  仅检查 tag、gh 登录状态和现有 Release 状态。
  默认自动使用 releases/<tag>-release-notes.md 作为 notes 文件。

位置参数:
  <tag>                    Git tag，例如 0.5.0 或 v0.5.0

选项:
  --notes-file <path>      自定义 Release note 文件路径
  --target <branch>        Release target，默认 main
  --title <title>          Release 标题，默认与 tag 相同
  --repo <owner/name>      GitHub 仓库，默认 anzihenry/scripts
  -h, --help               显示帮助
EOF
}

print_release_help() {
  cat <<'EOF'
用法:
  macos-scripts release publish <tag> [参数]
  macos-scripts release verify <tag> [参数]

说明:
  publish          创建或更新 GitHub Release
  verify           仅检查 tag、gh 和现有 Release 状态
EOF
}
