#!/bin/zsh
# filepath: maintain/lib/macos_installer_args.sh

initialize_macos_installer_context() {
  # SCRIPT_NAME 由入口脚本在顶层赋值（函数内 $0 是函数名、库内 $0 是库名）。
  # 若被直接 source 后调用且未预设，则回退到进程名，保证 set -u 下不报未绑定。
  if [[ -z "${SCRIPT_NAME:-}" ]]; then
    SCRIPT_NAME="${0:t}"
  fi
  MAINTAIN_LOG_FILE="$(prepare_log_file_path "macos-installer.log" "$SCRIPT_DIR/macos-installer.log")"
  enable_log_capture "$MAINTAIN_LOG_FILE"

  LOCK_DIR=""
  VERBOSE="false"
  REMAINING_ARGS=()

  DOWNLOAD_VERSION=""
  DOWNLOAD_FORCE="no"

  CREATE_VOLUME=""
  CREATE_INSTALLER_PATH=""
  CREATE_VERSION=""
  CREATE_YES="no"
  CREATE_FORCE="no"
  CREATEINSTALLMEDIA_PATH=""
  CREATE_APP_VERSION=""
  CREATE_APP_NAME=""
  CREATE_APP_LABEL=""
}

parse_macos_installer_global_args() {
  case "${1:-}" in
    -v|--verbose)
      VERBOSE="true"
      shift
      ;;
  esac

  if [[ "$VERBOSE" == "true" ]]; then
    export DEBUG=true
  fi

  REMAINING_ARGS=("$@")
}
