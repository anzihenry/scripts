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
  [ "$VERBOSE" = "true" ] && export DEBUG=true
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

  [ "$VERBOSE" = "true" ] && export DEBUG=true
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
