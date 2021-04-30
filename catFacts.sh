#!/bin/bash

# Written by: Braydon Brinkerhoff
# Date written: April 24th, 2021
# Objective: Send randomized cat facts to a recipient over iMessage
# Package requirements: jq

#################
## Global Vars ##
#################
delayRange=30 # Number range for randomized delays
msgCount=; msgDelay=; recipient=; message=;


################
## Color Vars ##
################
GREEN=$(tput -T xterm-256color setaf 2;tput -T xterm-256color bold)
RED=$(tput -T xterm-256color setaf 1;tput -T xterm-256color bold)
YELLOW=$(tput -T xterm-256color setaf 3;tput -T xterm-256color bold)
BLUE=$(tput -T xterm-256color setaf 4;tput -T xterm-256color bold)
RESET=$(tput -T xterm-256color sgr0;tput -T xterm-256color bold)


###########################
## Text Output Functions ##
###########################
_error() { printf "${RED} * ERROR${RESET}: %s\n" "$@" 1>&2;} # echo 'ERROR' text to stderr
_info()  { printf "${GREEN} *  INFO${RESET}: %s\n" "$@";}    # echo 'INFO' text to stdout
_echo()  { local color=$(tr [a-z] [A-Z] <<< $1);shift;echo "${!color}$@${RESET}"; } # echo with specified color


###################
## Menu Function ##
###################
menu() {
  local ESC=$( printf "\033")
  cursor_blink_on()  { printf "$ESC[?25h"; }
  cursor_blink_off() { printf "$ESC[?25l"; }
  cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
  print_option()     { printf "   $1 "; }
  print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()        { read -s -n3 key 2>/dev/null >&2
                       if [[ $key = "$ESC[A" ]]; then echo up;    fi
                       if [[ $key = "$ESC[B" ]]; then echo down;  fi
                       if [[ $key = ""     ]]; then echo enter; fi; }
  for opt; do printf "\n"; done
  local lastrow=$(get_cursor_row)
  local startrow=$(($lastrow - $#))
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off
  local selected=0
  while true; do
      printf "\n"
      local idx=0
      for opt; do
          cursor_to $(($startrow + $idx))
          if [ $idx -eq $selected ]; then
              print_selected "$opt"
          else
              print_option "$opt"
          fi
          ((idx++))
      done
      case $(key_input) in
          enter) break;;
          up)    ((selected--));
                 if [ $selected -lt 0 ]; then local selected=$(($# - 1)); fi;;
          down)  ((selected++));
                 if [ $selected -ge $# ]; then local selected=0; fi;;
      esac
  done
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on
  return $selected; }


########################
## Variable functions ##
########################
isINT() { local var=${1}; local re='^[0-9]+$'; [[ ${var} =~ ${re} ]] && return $?; }
setVARS() {
  setCOUNT() {
    until [[ -n ${msgCount} ]];do
      read -ep "${YELLOW}How many facts would you like to send?${RESET} " msgCount
      if ! isINT ${msgCount};then
        _error "Invalid message amount. Please provide a valid numerical value."; unset msgCount
      fi
    done; }
  setRECIPIENT() {
    until [[ -n ${recipient} ]];do
      read -ep "${YELLOW}What is the name of the recipient you would like to send facts to?${RESET} " recipient
      [[ -z ${recipient} ]] && _error "Recipient cannot be empty"
    done; }
  setDELAY() {
    until [[ -n ${msgDelay} ]];do
      echo "${BLUE}Would you like to have a delay between messages?${RESET}"
      if menu yes no;then
        echo "${BLUE}Would you like the delay to be a randomized or fixed number?${RESET}"
        if menu fixed randomized;then
          while [[ -z ${msgDelay} ]];do
            read -ep "${YELLOW}How many seconds would you like to wait between messages?${RESET} " msgDelay
            if ! isINT ${msgDelay};then
              _error "Invalid value for message delay. Please provide a valid numerical value."; unset msgDelay
            fi
          done
        else
          msgDelay="randomized"
        fi
      else
        msgDelay=0
      fi
    done; }
  setCOUNT
  setRECIPIENT
  setDELAY; }
msgDELAY() {
  [[ -z ${msgDelay} ]] && setVARS
  if isINT ${msgDelay};then
    local delay=${msgDelay}
  else
    local delay=$((1 + ${RANDOM} % ${delayRange}))
  fi
  echo -n "${delay}"; }


######################
## Default function ##
######################
catFACTS() {
  getFACT() { curl -s -X GET --header 'Accept: application/json' 'https://catfact.ninja/fact'|jq '.fact'; }
  SMS() {
    local fact=$(getFACT)
    if [[ -n ${fact} ]];then
      message=$(sed 's/"//g' <<< ${fact}|sed "s/'//g")
    fi
    [[ -z ${message} ]] && message='Cats are cool'
    osascript << EOF
tell application "Messages"
  set targetService to first service whose service type = iMessage
  set targetBuddy to first buddy of targetService whose name is "${recipient}"
  send "${message}" to targetBuddy
end tell
EOF
  }
  setVARS
  [[ -n ${msgCount} && -n ${msgDelay} && -n ${recipient} ]] && \
  echo "${GREEN}Sending ${msgCount} cat facts to ${recipient}${RESET}"
  local i=0; while (( i < msgCount ));do (( i++ ))
    local delay=$(msgDELAY)
    SMS & >/dev/null 2>&1; echo -n
    echo -en "\r${BLUE}Sending message${YELLOW} ${i}/${msgCount}${BLUE} to${YELLOW} ${recipient}${BLUE} with a delay of ${YELLOW}${delay}${BLUE} seconds.${RESET}"
    sleep ${delay}
  done; }


###################
## Help Function ##
###################
showHELP() {
  echo "${YELLOW}Options:${BLUE}"
  echo "    -h,--help                         Show this help menu."
  echo "    -r,--recipient                    Set the value of the message recipient."
  echo "    -c,--count                        Set the amount of messages to be sent."
  echo "    -d,--delay                        Set the delay in seconds between messages being sent."
  echo "    --random                          Set the delay between messages to a random number of seconds between 0-30."
  echo
  echo "${YELLOW}Usage:${BLUE}"
  echo "    ./catFactsPlus.sh"
  echo "    ./catFactsPlus.sh [-h,--help]"
  echo "    ./catFactsPlus.sh [-r,--recipient][name]"
  echo "    ./catFactsPlus.sh [-c,--count][number]"
  echo "    ./catFactsPlus.sh [-d,--delay][number]"
  echo "    ./catFactsPlus.sh [--random]"
  echo "${RESET}"; exit 0; }


##################
## Script Flags ##
##################
while test $# -gt 0;do
      case $1 in
              -h|--help)
                showHELP
                ;;
              -r|--recipient)
                shift
                recipient=${1}
                ;;
              -c|--count)
                shift
                msgCount=${1}
                ;;
              -d|--delay)
                shift
                msgDelay=${1}
                ;;
              --random)
                msgDelay="randomized"
                ;;
              *)
                _error "'$1' is not a valid argument."
                _info "A list of valid arguments can be found using -h or --help"
                exit 1
                ;;
      esac
      shift
done


catFACTS
exit $?
