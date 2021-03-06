#!/usr/bin/env bash

# Script that allows to run multiple .lua scripts at once
# Usage: run.sh <path_to_sdl_bin> <path_to_scripts>
# Instead of <path_to_scripts> <path_to_test_set> or <path_to_folder> can be used

ATF_FOLDER=.
SOUND_FILE=/usr/share/sounds/freedesktop/stereo/complete.oga
SOUND_PLAYER=/usr/bin/paplay
REPORT_FOLDER="TestingReportsArch"
REPORT_FILE="Report.txt"
REPORT_FILE_CONSOLE="Console.txt"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
CORE_DUMP_FOLDER=/tmp/corefiles
LINE="====================================================================================================="

P="\033[0;32m"
F="\033[0;31m"
A="\033[0;35m"
S="\033[0;33m"
N="\033[0m"

REPORT_FOLDER=${ATF_FOLDER}/${REPORT_FOLDER}/${TIMESTAMP}

check_arguments() {
  if ([ -z $1 ] && [ -z $2 ]) || [ $1 = "-h" ] || [ $1 = "--help" ]; then
    echo "Usage: run.sh [SDL] [TEST_TARGET] [SDL_API]"
    echo "SDL - path to SDL binaries"
    echo "TEST_TARGET - one of the following:"
    echo "   - test script"
    echo "   - test set"
    echo "   - folder with test scripts (all scripts will be run recursively)"
    echo "SDL_API - path to SDL APIs"
    echo
    exit 0
  fi

  if [ -z $1 ]; then
    echo "Path to SDL binaries is not defined"
    exit 1
  fi
  if [ -z $2 ]; then
    echo "Test target is not defined"
    exit 1
  fi
  if [ ! -d $1 ]; then
    echo "SDL binaries was not found"
    exit 1
  fi
  if [ ! -d $2 ] && [ ! -f $2 ]; then
    echo "Test target was not found"
    exit 1
  fi
  if [ ! -z $3 ] && [ ! -d $3 ]; then
    echo "SDL APIs was not found"
    exit 1
  fi

  SDL_FOLDER=$1
  TEST_TARGET=$2
  API_FOLDER=$3

  if [ "${SDL_FOLDER: -1}" = "/" ]; then
    SDL_FOLDER="${SDL_FOLDER:0:-1}"
  fi
  if [ "${TEST_TARGET: -1}" = "/" ]; then
    TEST_TARGET="${TEST_TARGET:0:-1}"
  fi
  if [ "${API_FOLDER: -1}" = "/" ]; then
    API_FOLDER="${API_FOLDER:0:-1}"
  fi
}

log() {
  echo -e "${1}${2}${3}${4}${5}${6}${7}${8}${9}"
}

logf() {
  echo -e "${1}${2}${3}${4}${5}${6}${7}${8}${9}" \
   | tee >(sed -u "s/\x1b[^m]*m//g" >> ${REPORT_FOLDER}/${REPORT_FILE})
}

backup() {
  log "Back-up SDL files"
  cp -n ${SDL_FOLDER}/sdl_preloaded_pt.json ${SDL_FOLDER}/_sdl_preloaded_pt.json
  cp -n ${SDL_FOLDER}/smartDeviceLink.ini ${SDL_FOLDER}/_smartDeviceLink.ini
  cp -n ${SDL_FOLDER}/hmi_capabilities.json ${SDL_FOLDER}/_hmi_capabilities.json
  cp -n ${SDL_FOLDER}/log4cxx.properties ${SDL_FOLDER}/_log4cxx.properties
}

restore() {
  log "Restoring SDL files from back-up"
  cp -f ${SDL_FOLDER}/_sdl_preloaded_pt.json ${SDL_FOLDER}/sdl_preloaded_pt.json
  cp -f ${SDL_FOLDER}/_smartDeviceLink.ini ${SDL_FOLDER}/smartDeviceLink.ini
  cp -f ${SDL_FOLDER}/_hmi_capabilities.json ${SDL_FOLDER}/hmi_capabilities.json
  cp -f ${SDL_FOLDER}/_log4cxx.properties ${SDL_FOLDER}/log4cxx.properties
}

clean_backup() {
  log "Cleaning up back-up SDL files"
  rm -f ${SDL_FOLDER}/_sdl_preloaded_pt.json
  rm -f ${SDL_FOLDER}/_smartDeviceLink.ini
  rm -f ${SDL_FOLDER}/_hmi_capabilities.json
  rm -f ${SDL_FOLDER}/_log4cxx.properties
}

kill_sdl() {
  sleep 0.2
  PID="$(ps -ef | grep -e "^$(whoami).*smartDeviceLinkCore" | grep -v grep | awk '{print $2}')"
  if [ -n "$PID" ]; then
    log "SDL is running, PID: $PID"
    log "Killing SDL"
    kill -9 $PID
  fi
  sleep 0.2
}

create_log_folder() {
  mkdir -p ${REPORT_FOLDER}
  mkdir -p ${CORE_DUMP_FOLDER}
}

create_log_folder_for_script() {
  mkdir ${REPORT_FOLDER}/Script_"${ID_SFX}"
}

copy_logs() {
  cp `find ${ATF_FOLDER}/TestingReports/ -name "*.*"` ${REPORT_FOLDER}/Script_"${ID_SFX}"/
  cp ${ATF_FOLDER}/ErrorLog.txt ${REPORT_FOLDER}/Script_"${ID_SFX}"/
  NUM_OF_DUMP_FILES=$(ls -1 $CORE_DUMP_FOLDER | wc -l)
  if [ $RESULT = "ABORTED" ] && [ ! $NUM_OF_DUMP_FILES -eq 0 ]; then
    chmod 644 ${CORE_DUMP_FOLDER}/*
    for DUMP_FILE in $(ls -1 $CORE_DUMP_FOLDER/*)
    do
      gzip $DUMP_FILE
    done
    cp ${CORE_DUMP_FOLDER}/* ${REPORT_FOLDER}/Script_"${ID_SFX}"/
  fi
}

clean() {
  log "Cleaning up ATF folder"
  rm -f ${ATF_FOLDER}/ErrorLog.txt
  rm -f ${ATF_FOLDER}/sdl.pid
  rm -f ${ATF_FOLDER}/mobile*.out
  rm -f -r ${ATF_FOLDER}/TestingReports
  log "Cleaning up SDL folder"
  rm -f ${SDL_FOLDER}/*.log
  rm -f ${SDL_FOLDER}/app_info.dat
  rm -f ${SDL_FOLDER}/policy.sqlite
  rm -f -r ${SDL_FOLDER}/storage
  rm -f -r ${SDL_FOLDER}/ivsu_cache
  rm -f -r ${SDL_FOLDER}/../sdl_bin_bk
  log "Cleaning up folder with core dumps"
  rm -f -r ${CORE_DUMP_FOLDER}/*
}

run() {
  log ${LINE}

  ID=$((ID+1))
  ID_SFX=$(printf "%0${#NUM_OF_SCRIPTS}d" $ID)

  log "Processing script: " ${ID}"("${NUM_OF_SCRIPTS}") ["\
    "${P}PASSED: ${#LIST_PASSED[@]}, "\
    "${F}FAILED: ${#LIST_FAILED[@]}, "\
    "${A}ABORTED: ${#LIST_ABORTED[@]}, "\
    "${S}SKIPPED: ${#LIST_SKIPPED[@]}"\
    "${N}]"

  kill_sdl

  clean

  restore

  create_log_folder_for_script

  if [ ! -z $API_FOLDER ]; then
    SDL_API="--sdl-interfaces=${API_FOLDER}"
  fi

  ./start.sh $SCRIPT --sdl-core=${SDL_FOLDER} ${SDL_API}\
    | tee >(sed -u "s/\x1b[^m]*m//g" > ${REPORT_FOLDER}/Script_"${ID_SFX}"/${REPORT_FILE_CONSOLE})

  RESULT_CODE=${PIPESTATUS[0]}
  RESULT="NOT_DEFINED"

  case "${RESULT_CODE}" in
    0)
      RESULT="PASSED"
      LIST_PASSED[ID]=$ID_SFX:$SCRIPT
    ;;
    1)
      RESULT="ABORTED"
      LIST_ABORTED[ID]=$ID_SFX:$SCRIPT
    ;;
    2)
      RESULT="FAILED"
      LIST_FAILED[ID]=$ID_SFX:$SCRIPT
    ;;
    4)
      RESULT="SKIPPED"
      LIST_SKIPPED[ID]=$ID_SFX:$SCRIPT
    ;;
  esac

  log "SCRIPT STATUS: " ${RESULT}

  kill_sdl

  copy_logs
}

process() {
  ID=0
  EXT=${TEST_TARGET: -3}
  if [ $EXT = "txt" ]; then
    NUM_OF_SCRIPTS=$(cat $TEST_TARGET | egrep -v -c '^;')
    while read -r ROW
    do
      if [ ${ROW:0:1} = ";" ]; then
        continue
      fi
      SCRIPT=$(echo $ROW | awk '{print $1}')
      run
    done < "$TEST_TARGET"
  elif [ $EXT = "lua" ]; then
    NUM_OF_SCRIPTS=1
    SCRIPT=$TEST_TARGET
    run
  else
    NUM_OF_SCRIPTS=$(find $TEST_TARGET -iname "[0-9]*.lua" | wc -l)
    for ROW in $(find $TEST_TARGET -iname "[0-9]*.lua" | sort)
    do
      SCRIPT=$ROW
      run
    done
  fi
}

status() {
  logf "TOTAL: " $ID
  logf "${P}PASSED: " ${#LIST_PASSED[@]} "${N}"
  logf "${F}FAILED: " ${#LIST_FAILED[@]} "${N}"
  for i in ${LIST_FAILED[@]}
  do
    logf "${i/:/: }"
  done
  logf "${A}ABORTED: " ${#LIST_ABORTED[@]} "${N}"
  for i in ${LIST_ABORTED[@]}
  do
    logf "${i/:/: }"
  done
  logf "${S}SKIPPED: " ${#LIST_SKIPPED[@]} "${N}"
  for i in ${LIST_SKIPPED[@]}
  do
    logf "${i/:/: }"
  done
}

play_finish_sound() {
  if [ -f $SOUND_PLAYER ] && [ -f $SOUND_FILE ]; then
    $SOUND_PLAYER $SOUND_FILE
  fi
}

log_test_run_details() {
  logf "SDL: " $SDL_FOLDER
  logf "Test target: " $TEST_TARGET
}

check_arguments $1 $2 $3

create_log_folder

logf ${LINE}

log_test_run_details

logf ${LINE}

backup

process

log ${LINE}

restore

clean_backup

log ${LINE}

status

logf ${LINE}

play_finish_sound
