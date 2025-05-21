#!/usr/bin/env bash
# Mariadb Running Connection Tester
# By Edward Stoever for MariaDB Support
unset ERR
INTERACTIVE=TRUE
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source ${SCRIPT_DIR}/vsn.sh
source ${SCRIPT_DIR}/pre_connect.sh

touch ${SCRIPT_DIR}/STOP_NOW || ERR=true 
if [ ! $ERR ]; then
  TEMP_COLOR=lgreen; print_color "Created stop file: "; unset TEMP_COLOR; print_color "${SCRIPT_DIR}/STOP_NOW\n";
  TEMP_COLOR=lmagenta; print_color "Wait a few seconds for Running Connection Tester to stop.\n" 
else
  TEMP_COLOR=lred; print_color "Something unexpected occurred.\n"
fi

unset TEMP_COLOR

