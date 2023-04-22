#!zsh
set -e # abort if any command fails

source ./message_utils.sh

(
  exec 3>/dev/tty

  CONTEXT=subshell

  setopt null_glob

  rm -rf ./build
  rm -f ./buildlog.txt
  rm -rf ./deps/*
  progress_success "All build artifacts have been removed."
) >>&| /dev/null
