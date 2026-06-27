#!/bin/zsh
# filepath: maintain/lib/macos_installer_args.sh

initialize_macos_installer_context() {
  SCRIPT_NAME="$(basename "$0")"
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
