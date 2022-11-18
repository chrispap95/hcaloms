#!/bin/sh

# Ignore warnings that are not important for bash
# shellcheck disable=SC3000-SC4000

touch "$SCRIPT_LOG"

SCRIPTENTRY(){
  timeAndDate=$(date)
  script_name=$(basename "$0")
  script_name="${script_name%.*}"
  echo "[$timeAndDate] [DEBUG]  > $script_name ${FUNCNAME[0]}" >> "$SCRIPT_LOG"
}

SCRIPTEXIT(){
  script_name=$(basename "$0")
  script_name="${script_name%.*}"
  echo "[$timeAndDate] [DEBUG]  < $script_name ${FUNCNAME[0]}" >> "$SCRIPT_LOG"
}

ENTRY(){
  local cfn="${FUNCNAME[1]}"
  timeAndDate=$(date)
  echo "[$timeAndDate] [DEBUG]  > $cfn ${FUNCNAME[0]}" >> "$SCRIPT_LOG"
}

EXIT(){
  local cfn="${FUNCNAME[1]}"
  timeAndDate=$(date)
  echo "[$timeAndDate] [DEBUG]  < $cfn ${FUNCNAME[0]}" >> "$SCRIPT_LOG"
}


INFO(){
  local msg="$1"
  timeAndDate=$(date)
  echo "[$timeAndDate] [INFO]  $msg" >> "$SCRIPT_LOG"
}


DEBUG(){
  local msg="$1"
  timeAndDate=$(date)
  echo "[$timeAndDate] [DEBUG]  $msg" >> "$SCRIPT_LOG"
}

ERROR(){
  local msg="$1"
  timeAndDate=$(date)
  echo "[$timeAndDate] [ERROR]  $msg" >> "$SCRIPT_LOG"
}
