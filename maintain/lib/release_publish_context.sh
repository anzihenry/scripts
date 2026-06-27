#!/bin/bash
# filepath: maintain/lib/release_publish_context.sh

initialize_release_publish_context() {
  RELEASE_LOG_FILE="$(prepare_log_file_path "github-release-publish.log" "$SCRIPT_DIR/github-release-publish.log")"
  enable_log_capture "$RELEASE_LOG_FILE"

  REPO_SLUG="anzihenry/scripts"
  TAG=""
  TARGET="main"
  TITLE=""
  NOTES_FILE=""
  YES="false"
  DRY_RUN="false"
  VERIFY_ONLY="false"
  UPDATE_EXISTING="false"
}
