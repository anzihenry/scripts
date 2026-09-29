#!/bin/zsh
# filepath: maintain/lib/macos_installer_commands.sh

parse_download_args() {
  DOWNLOAD_VERSION=""
  DOWNLOAD_FORCE="no"

  while [ $# -gt 0 ]; do
    case "$1" in
      --version) DOWNLOAD_VERSION="${2:-}"; shift 2 ;;
      --force|-f) DOWNLOAD_FORCE="yes"; shift ;;
      -v|--verbose) VERBOSE="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "未知参数: $1" ;;
    esac
  done

  [ -n "${DOWNLOAD_VERSION}" ] || die "请通过 --version 指定版本号，例如 --version 14.6.1"
  # 必须显式 return 0：`[ ... ] && export ...` 在未加 -v 时返回 1，
  # 会被调用方的 set -e 当作失败（此前导致无 -v 的 download 直接退出）。
  [ "$VERBOSE" = "true" ] && export DEBUG=true
  return 0
}

parse_create_args() {
  CREATE_VOLUME=""
  CREATE_INSTALLER_PATH=""
  CREATE_VERSION=""
  CREATE_YES="no"
  CREATE_FORCE="no"

  while [ $# -gt 0 ]; do
    case "$1" in
      --volume) CREATE_VOLUME="${2:-}"; shift 2 ;;
      --installer-path) CREATE_INSTALLER_PATH="${2:-}"; shift 2 ;;
      --version) CREATE_VERSION="${2:-}"; shift 2 ;;
      -y|--yes|--nointeraction) CREATE_YES="yes"; shift ;;
      --force|-f) CREATE_FORCE="yes"; shift ;;
      -v|--verbose) VERBOSE="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "未知参数: $1" ;;
    esac
  done

  # 同 parse_download_args：避免末位 && 条件在未加 -v 时返回 1。
  [ "$VERBOSE" = "true" ] && export DEBUG=true
  return 0
}

dispatch_macos_installer_command() {
  case "${1:-}" in
    list)
      shift
      sub_list "$@"
      ;;
    download)
      shift
      sub_download "$@"
      ;;
    create)
      shift
      sub_create "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      log_error "未知子命令: ${1:-}"
      usage
      exit 1
      ;;
  esac
}
