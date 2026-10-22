#!/bin/zsh
# filepath: maintain/lib/macos_installer_commands.sh

parse_download_args() {
  DOWNLOAD_VERSION=""
  DOWNLOAD_FORCE="no"

  while [ $# -gt 0 ]; do
    case "$1" in
      --version) (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || { error "--version 缺少参数值"; return 2; }; DOWNLOAD_VERSION="$2"; shift 2 ;;
      --force|-f) DOWNLOAD_FORCE="yes"; shift ;;
      -v|--verbose) VERBOSE="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) error "未知参数: $1"; return 2 ;;
    esac
  done

  [[ "$DOWNLOAD_VERSION" =~ ^[0-9]+([.][0-9]+){1,2}$ ]] || { error "请通过 --version 指定版本号，例如 --version 14.6.1"; return 2; }
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
      --volume) (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || { error "--volume 缺少参数值"; return 2; }; CREATE_VOLUME="$2"; shift 2 ;;
      --installer-path) (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || { error "--installer-path 缺少参数值"; return 2; }; CREATE_INSTALLER_PATH="$2"; shift 2 ;;
      --version) (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || { error "--version 缺少参数值"; return 2; }; CREATE_VERSION="$2"; shift 2 ;;
      -y|--yes|--nointeraction) CREATE_YES="yes"; shift ;;
      --force|-f) CREATE_FORCE="yes"; shift ;;
      -v|--verbose) VERBOSE="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) error "未知参数: $1"; return 2 ;;
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
      local list_option
      for list_option in "$@"; do
        case "$list_option" in
          -h|--help|help) usage; return 0 ;;
          -v|--verbose) VERBOSE=true ;;
          *) error "未知参数: $list_option"; return 2 ;;
        esac
      done
      initialize_macos_installer_logging || return 1
      require_supported_macos || return 1
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
