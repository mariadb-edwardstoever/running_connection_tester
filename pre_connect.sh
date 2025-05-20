#!/usr/bin/env bash
# pre_connect.sh
# file distributed with Running Connection Tester 
# This software is based on Connection Pool Simulater.
# By Edward Stoever for MariaDB Support



TMPDIR="/tmp"
TOOL="running_connection_tester"
CONFIG_FILE="$SCRIPT_DIR/simulator.cnf"
CONNS=1 # default 10 connections
MINS=525600 # default 525600 minutes (1 year)
QRYS_LOW=30 # default 30 queries per minute, every 2 seconds
FIFO_DIR=$TMPDIR/$TOOL
SQL_DIR="$SCRIPT_DIR/SQL"
LC_ALL='en_US.UTF-8'
ERROR_LOG=$SCRIPT_DIR/CONN_ERRORS

function ts() {
   TS=$(date +%F-%T | tr ':-' '_')
   echo "$TS $*"
}

function die() {
   ts "$*" >&2
   exit 1
}

if [ ! $SCRIPT_VERSION ]; then  die "Do not run this script directly. Read the file README.md for help."; fi

function display_help_message() {
printf "This script can be run without options. Not indicating an option value will use the default.
  --interactive        # Run script with visible output to command line. Default is non-interactive.
  --minutes=10         # Indicate the number of minutes to run, default 525600 (1 year).
  --connections=2      # Indicate the number of connections maintained, default 1.
  --qpm_low            # Queries per minute, default 30.
  --cleanup            # If script is cancelled (ctrl+c or killed), processes and pipes must be removed.
                       # Use the cleanup option to start over.
  --test               # Test connect to database and display script version. Always interactive.
  --version            # Test connect to database and display script version. Always interactive.
  --help               # Display the help menu. Always interactive.

Read the file README.md for more information.\n"
if [ $INVALID_INPUT ]; then die "Invalid option: $INVALID_INPUT"; fi
}

function display_title(){
if [ ! $INTERACTIVE ]; then return; fi
  local BLANK='  │                                                         │'
  printf "  ┌─────────────────────────────────────────────────────────┐\n"
  printf "$BLANK\n"
  printf "  │            MARIADB RUNNING CONNECTION TESTER            │\n"
  printf '%-62s' "  │                      Version $SCRIPT_VERSION"; printf "│\n"
  printf "$BLANK\n"
  printf "  │      Script by Edward Stoever for MariaDB Support       │\n"
  printf "$BLANK\n"
  printf "  └─────────────────────────────────────────────────────────┘\n"

}

function make_fifo_dir (){
  mkdir -p $FIFO_DIR || die "Cannot mkdir"
  chmod 777 $FIFO_DIR || die "Cannot chmod"
  touch $FIFO_DIR/SLEEP_PID_LIST || die "Cannot create PID_LIST"
}

function verify_fifo_dir (){
  if [ "$(find $FIFO_DIR/ -type p)" ]; then 
    die "FIFO files exist. Is this script already running? Run with the --cleanup option first."
  fi
}

function start_message() {
  $CMD_MARIADB  --connect-timeout=2 $CLOPTS -s -e "select now();" 1>/dev/null 2>/dev/null && CAN_CONNECT=true || unset CAN_CONNECT
  if [ $CAN_CONNECT ]; then
    TEMP_COLOR=lgreen; print_color "Can connect to database.\n"; unset TEMP_COLOR;
  else
    TEMP_COLOR=lred;   print_color "Cannot connect to database.\n"; unset TEMP_COLOR;
  fi

  if [ ! $CAN_CONNECT ]; then 
    TEMP_COLOR=lred; print_color "Failing command: ";unset TEMP_COLOR; 
    TEMP_COLOR=lyellow; print_color "$CMD_MARIADB --connect-timeout=2 $CLOPTS\n";unset TEMP_COLOR; 
  fi

  if [ $HELP ]; then display_help_message; exit 0; fi
  if [ $DISPLAY_VERSION ]; then exit 0; fi
  if [ ! $CAN_CONNECT ]; then  die "Database connection failed. Read the file README.md. Edit the file simulator.cnf."; fi
 
  if [ ! $HELP ] && [ ! $DISPLAY_VERSION ]; then
    printf "%(%Y-%m-%d %H:%M:%S)T %s\n" -1 'CONNECTION ESTABLISHED' >> $ERROR_LOG;
  fi
}

function set_fifo_name () {
  local HD=$(printf $(($RANDOM * $RANDOM +100000))| base64 | sed 's/\=//g' | head -c 8)
  local MD=$(printf "%04d"  $((1 + $RANDOM % 1000)))
  local TL=$(printf "$(cat /proc/sys/kernel/random/uuid)"| head -c 8) 
  FIFO_BASENAME="$HD-$MD-$TL"
}

function make_fifo() {
  while true
  do
    set_fifo_name;
	if ! [ $(find $FIFO_DIR -name $FIFO_BASENAME )]; then 
	  FIFO="$FIFO_DIR/$FIFO_BASENAME"
	  mkfifo $FIFO
	  break
	fi
  done
}

function sleep_fifo() {
  local SECONDS_TO_SLEEP=$(((MINS +2)*60)) # overvalue this by 2 minutes
  sleep $SECONDS_TO_SLEEP > $FIFO & disown
  local PID=$!
  printf "$PID " >> $FIFO_DIR/SLEEP_PID_LIST
}

function add_timestamp_to_error() {
  while IFS= read -r line; do
    printf "%(%Y-%m-%d %H:%M:%S)T %s\n" -1 "$line"
    if [[ "$line" == *"ERROR 2006"* ]]; then touch ${SCRIPT_DIR}/RECONNECT_NOW; fi
  done
}

function client_input_fifo(){

  $CMD_MARIADB --init-command="set session wait_timeout=$WAIT_TIMEOUT;" $CLOPTS --force -B < $FIFO 1>/dev/null 2> >(add_timestamp_to_error >> $ERROR_LOG)  & disown

  TEMP_COLOR=lcyan; print_color "Piping input to Mariadb client via "; unset TEMP_COLOR; print_color "$FIFO\n";
}

function disconnect_clients(){
for SLEEPING_FILE in $(find $FIFO_DIR/ -type p)
  do
    if [ "$(lsof $SLEEPING_FILE | grep mariadb)" ]; then
      echo "exit" > $SLEEPING_FILE
	  TEMP_COLOR=lcyan; print_color "Disconnected Mariadb client via "; unset TEMP_COLOR; print_color "$SLEEPING_FILE\n";
	fi
  done
}

function test_clients(){
  for SLEEPING_FILE in $(find $FIFO_DIR/ -type p)
  do
    echo "select concat(rand(), '-', now(), '-', 'success') from information_schema.SCHEMATA where SCHEMA_NAME='information_schema';" > $SLEEPING_FILE
  done
}

function start_connection_pool(){
for (( cc=1; cc<=$CONNS; cc++))
 do
   make_fifo
   sleep_fifo
   client_input_fifo
 done
}


function kill_all_sleepers(){
  if [ ! -f $FIFO_DIR/SLEEP_PID_LIST ]; then return; fi
  kill -9 $(cat $FIFO_DIR/SLEEP_PID_LIST)  
  rm -f $FIFO_DIR/SLEEP_PID_LIST
  find $FIFO_DIR/ -type p -exec rm -f {} \; || die "Could not remove FIFO files."
  TEMP_COLOR=lmagenta; print_color "Cleanup of FIFOs completed.\n"; unset TEMP_COLOR; 
}

function _which() {
   if [ -x /usr/bin/which ]; then
      /usr/bin/which "$1" 2>/dev/null | awk '{print $1}'
   elif which which 1>/dev/null 2>&1; then
      which "$1" 2>/dev/null | awk '{print $1}'
   else
      echo "$1"
   fi
}


function dependency(){
  if [ ! $(_which $1) ]; then die "The linux program $1 is unavailable. Check PATH or install."; fi
}

function test_dependencies(){
  dependency which
  dependency awk
  dependency sed
  dependency base64
  dependency head
  dependency whoami
  dependency perl
}


function print_color () {
  if [ ! $INTERACTIVE ]; then return; fi  
  if [ -z "$COLOR" ] && [ -z "$TEMP_COLOR" ]; then printf "$1"; return; fi
  case "$COLOR" in
    default) i="0;36" ;;
    red)  i="0;31" ;;
    blue) i="0;34" ;;
    green) i="0;32" ;;
    yellow) i="0;33" ;;
    magenta) i="0;35" ;;
    cyan) i="0;36" ;;
    lred) i="1;31" ;;
    lblue) i="1;34" ;;
    lgreen) i="1;32" ;;
    lyellow) i="1;33" ;;
    lmagenta) i="1;35" ;;
    lcyan) i="1;36" ;;
    *) i="0" ;;
  esac
if [ $TEMP_COLOR ]; then
  case "$TEMP_COLOR" in
    default) i="0;36" ;;
    red)  i="0;31" ;;
    blue) i="0;34" ;;
    green) i="0;32" ;;
    yellow) i="0;33" ;;
    magenta) i="0;35" ;;
    cyan) i="0;36" ;;
    lred) i="1;31" ;;
    lblue) i="1;34" ;;
    lgreen) i="1;32" ;;
    lyellow) i="1;33" ;;
    lmagenta) i="1;35" ;;
    lcyan) i="1;36" ;;
    *) i="0" ;;
  esac
fi
  printf "\033[${i}m${1}\033[0m"

}


function set_arrays(){
SQFILES=0
FIFOFILES=0
# declare -a ALL_SQL_TEXT
# declare -a ALL_FIFOS

for SQL_FILE in $(find $SQL_DIR/ -type f -name "*.sql")
do
  ALL_SQL_TEXT[$SQFILES]=$(cat $SQL_FILE)
  SQFILES=$(($SQFILES+1))
done

for FIFO_FILE in $(find $FIFO_DIR/ -type p)
do
  ALL_FIFOS[$FIFOFILES]=${FIFO_FILE}
  FIFOFILES=$(($FIFOFILES+1))
done

# echo "${ALL_SQL_TEXT[$(((RANDOM % $SQFILES)))]}" ${ALL_FIFOS[$(((RANDOM % $FIFOFILES)))]}
}

function set_sleep_interval(){
  local SECONDS_PER_MIN=60
  local QRYS=$1
  SLEEP_INTERVAL=$(echo print $SECONDS_PER_MIN/$QRYS | perl)
  # echo "sleep interval: $SLEEP_INTERVAL"
  
  # setting WAIT_TIMEOUT to 4 seconds higher than SLEEP_INTERVAL, allowing client to detect a disconnect quickly.
  WAIT_TIMEOUT=$(perl -e "print int($SLEEP_INTERVAL)")
  WAIT_TIMEOUT=$((WAIT_TIMEOUT+4)) 
}

function spin_test_connect(){
  while [ true ]; do
      $CMD_MARIADB --connect-timeout=1 $CLOPTS -e "select sleep(1), now();" 1>/dev/null 2> >(add_timestamp_to_error >> $ERROR_LOG) && local BREAKOUT=true
      if [ $BREAKOUT ]; then 
        rm -f ${SCRIPT_DIR}/RECONNECT_NOW; 
        printf "%(%Y-%m-%d %H:%M:%S)T %s\n" -1 'CONNECTION ESTABLISHED' >> $ERROR_LOG; 
        break; 
      fi
    print_color "Cannot connect!\n"; sleep 10; 
    if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then return; fi
  done
}

function reconnect(){
  disconnect_clients 
  kill_all_sleepers
  spin_test_connect 
  
   unset STOP_NOW; if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then local STOP_NOW=TRUE; fi
   if [ $STOP_NOW ]; then 
      TEMP_COLOR=lmagenta; print_color "Exiting intentionally.\n";  unset TEMP_COLOR; 
      disconnect_clients 
      kill_all_sleepers
      printf "%(%Y-%m-%d %H:%M:%S)T %s\n" -1 'EXITED INTENTIONALLY' >> $ERROR_LOG;
      if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then rm -f ${SCRIPT_DIR}/STOP_NOW; fi
      return; 
   fi
   
  make_fifo_dir
  verify_fifo_dir
  start_connection_pool
  set_arrays
  spin_sql
}

function spin_sql(){
  local NW=$(date +%s)
  local STARTTIME=$(date +%s)
  local NEXT_MESSAGE=$((${NW} + 10))
  local SQL_RUNS=0
  if  [ $INTERACTIVE ]; then 
    TEMP_COLOR=lmagenta; print_color "Elapsed seconds: "; unset TEMP_COLOR;  printf "%'.f" "0"
    TEMP_COLOR=lmagenta; print_color "   SQL scripts sent to connection pool: "; unset TEMP_COLOR;  printf "%'.f\n" "$SQL_RUNS" 
  fi
  sleep 1 # prevents a count of 1 at 0 seconds
  while [[ "$(( $NW - $(( ${MINS} * 60 )) ))" -le "$STARTTIME" ]]; do
  
   unset STOP_NOW; if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then local STOP_NOW=TRUE; fi
   if [ $STOP_NOW ]; then 
      TEMP_COLOR=lmagenta; print_color "Exiting intentionally.\n";  unset TEMP_COLOR; 
      disconnect_clients 
      kill_all_sleepers
      printf "%(%Y-%m-%d %H:%M:%S)T %s\n" -1 'EXITED INTENTIONALLY' >> $ERROR_LOG;
      if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then rm -f ${SCRIPT_DIR}/STOP_NOW; fi
      break; 
   fi
   unset RECONNECT_NOW; if [ -f ${SCRIPT_DIR}/RECONNECT_NOW ]; then RECONNECT_NOW=TRUE; fi
   if [ $RECONNECT_NOW ]; then
      reconnect; break;
   fi   
    (echo "${ALL_SQL_TEXT[$(((RANDOM % $SQFILES)))]}" > "${ALL_FIFOS[$(((RANDOM % $FIFOFILES)))]}" ) & disown  
	SQL_RUNS=$(( $SQL_RUNS+1 ))
    sleep $SLEEP_INTERVAL
    if [[ "$NW" -ge "$NEXT_MESSAGE" ]]; then
      if  [ $INTERACTIVE ]; then
	    TEMP_COLOR=lmagenta; print_color "Elapsed seconds: "; unset TEMP_COLOR;  printf "%'.f" "$((NW - STARTTIME))"
        TEMP_COLOR=lmagenta; print_color "   SQL scripts sent to connection pool: "; unset TEMP_COLOR;  printf "%'.f\n" "$SQL_RUNS"
      fi
	  local NEXT_MESSAGE=$(( $NEXT_MESSAGE+10 ))
	  if [ ! "$QRYS_LOW" == "$QRYS_HIGH" ]; then set_sleep_interval $(perl -e "print int(rand($QRYS_HIGH-$QRYS_LOW)) + $QRYS_LOW"); fi
    fi
  local NW=$(date +%s)
   
  done
}



for params in "$@"; do
unset VALID; #REQUIRED
# echo "PARAMS: $params"
if [ $(echo "$params"|sed 's,=.*,,') == '--minutes' ]; then 
  MINS=$(echo "$params" | sed 's/.*=//g'); 
  if [ ! $(echo $MINS | awk '{ if(int($1)==$1) print $1}') ]; then 
   INVALID_INPUT="$params"; 
  else 
   VALID=TRUE; 
  fi
fi
if [ $(echo "$params"|sed 's,=.*,,') == '--qpm_low' ]; then 
  QRYS_LOW=$(echo "$params" | sed 's/.*=//g'); 
  if [ ! $(echo $QRYS_LOW | awk '{ if(int($1)==$1) print $1}') ]; then 
   INVALID_INPUT="$params"; 
#  elif [ $QRYS_LOW -lt 60 ]; then
#    INVALID_INPUT="$params";
  else 
   VALID=TRUE; 
  fi
fi
#if [ $(echo "$params"|sed 's,=.*,,') == '--qpm_high' ]; then 
#  QRYS_HIGH=$(echo "$params" | sed 's/.*=//g'); 
#  if [ ! $(echo $QRYS_HIGH | awk '{ if(int($1)==$1) print $1}') ]; then 
#   INVALID_INPUT="$params"; 
#  elif [ "$QRYS_HIGH" -lt "$QRYS_LOW" ]; then
#    INVALID_INPUT="$params";
#  else 
#   VALID=TRUE; 
#  fi
#fi
if [ $(echo "$params"|sed 's,=.*,,') == '--connections' ]; then 
  CONNS=$(echo "$params" | sed 's/.*=//g'); 
  if [ ! $(echo $CONNS | awk '{ if(int($1)==$1) print $1}') ]; then 
   INVALID_INPUT="$params"; 
  else 
   VALID=TRUE; 
  fi
fi
  if [ "$params" == '--cleanup' ]; then CLEANUP='TRUE'; VALID=TRUE; INTERACTIVE=TRUE; fi
  if [ "$params" == '--version' ]; then DISPLAY_VERSION=TRUE; VALID=TRUE; INTERACTIVE=TRUE; fi
  if [ "$params" == '--test' ]; then DISPLAY_VERSION=TRUE; VALID=TRUE; INTERACTIVE=TRUE; fi
  if [ "$params" == '--help' ]; then HELP=TRUE; VALID=TRUE; INTERACTIVE=TRUE; fi
  if [ "$params" == '--interactive' ]; then INTERACTIVE=TRUE; VALID=TRUE; fi
  if [ ! $VALID ] && [ ! $INVALID_INPUT ];  then  INVALID_INPUT="$params"; fi
done
if [ $INVALID_INPUT ]; then HELP=TRUE; fi


# DEFAULT VALUE FOR QRYS_HIGH 
if [ ! $QRYS_HIGH ]; then QRYS_HIGH=$QRYS_LOW; fi
set_sleep_interval $QRYS_LOW

  
if [ $(_which mariadb 2>/dev/null) ]; then
  CMD_MARIADB="${CMD_MARIADB:-"$(_which mariadb)"}"
else
  CMD_MARIADB="${CMD_MYSQL:-"$(_which mysql)"}"
fi

CMD_MY_PRINT_DEFAULTS="${CMD_MY_PRINT_DEFAULTS:-"$(_which my_print_defaults)"}"

if [ -z $CMD_MARIADB ]; then
  die "mariadb client command not available."
fi

if [ -z $CMD_MY_PRINT_DEFAULTS ]; then
  die "my_print_defaults command not available."
fi

CLOPTS=$(echo $($CMD_MY_PRINT_DEFAULTS --defaults-file=$CONFIG_FILE running_connection_tester | sed -z -e "s/\n/ /g") )


if [ -f ${SCRIPT_DIR}/STOP_NOW ]; then rm -f ${SCRIPT_DIR}/STOP_NOW; fi
if [ -f ${SCRIPT_DIR}/RECONNECT_NOW ]; then rm -f ${SCRIPT_DIR}/RECONNECT_NOW; fi
if [ "$(find $SQL_DIR/ -type f -name "*.sql" | wc -l)" == "0" ]; then die "No SQL files to run! Place some SQL scripts into the SQL directory."; fi

if [ "$CLEANUP" == "TRUE" ]; then 
 disconnect_clients 
 print_color "completed disconnect\n"
 kill_all_sleepers
 print_color "completed kill\n"

 exit 0
fi




