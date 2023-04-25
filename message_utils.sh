#!zsh

# Terminal colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`
RESET=`tput sgr0`

progress_success() (
  MESSAGE="==== ${1} ===="
  echo ${MESSAGE}
  echo "${GREEN}${MESSAGE}${RESET}" >&3
)

progress_error() (
  MESSAGE="** ${1} **"
  echo ${MESSAGE}
  echo "${RED}${MESSAGE}${RESET}" >&3
)

progress_section() (
  MESSAGE="=== ${1} ==="
  echo ${MESSAGE}
  echo "${MAGENTA}${MESSAGE}${RESET}" >&3
)

progress_subsection() (
  MESSAGE="== ${1} =="
  echo ${MESSAGE}
  echo "${CYAN}${MESSAGE}${RESET}" >&3
)

progress_item() (
  MESSAGE="= ${1} ="
  echo ${MESSAGE}
  echo "${BLUE}${MESSAGE}${RESET}" >&3
)

note() (
  MESSAGE="* ${1}"
  echo ${MESSAGE}
  echo "${YELLOW}${MESSAGE}${RESET}" >&3
)

export CONTEXT=top

TRAPZERR() {
  if [[ ${CONTEXT} == "top" ]]
  then
    progress_error "Build error."
    echo "Log tail:" >&3
    tail -n 10 ${BUILD_LOG} >&3
  fi

  return $(( 128 + $1 ))
}

TRAPINT() {
  if [[ ${CONTEXT} == "top" ]]
  then
    progress_error "Build stopped."
  fi

  return $(( 128 + $1 ))
}
