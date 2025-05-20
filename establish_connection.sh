#!/usr/bin/env bash
# Running Connection Tester -- test long running connection to see if it disconnects.
# This software is based on Connection Pool Simulater.
# By Edward Stoever for MariaDB Support

### DO NOT EDIT SCRIPT. 
### FOR FULL INSTRUCTIONS: README.md
### FOR BRIEF INSTRUCTIONS: ./establish_connection.sh --help


# Establish working directory and source pre_connect.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source ${SCRIPT_DIR}/vsn.sh
source ${SCRIPT_DIR}/pre_connect.sh

display_title
start_message
make_fifo_dir
verify_fifo_dir
start_connection_pool
set_arrays
spin_sql
disconnect_clients
kill_all_sleepers
