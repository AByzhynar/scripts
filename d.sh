#!/usr/bin/env bash

DOCKER_IMAGE=ubuntu_14.04:10

SDL_REPO=https://github.com/smartdevicelink/sdl_core
SDL_BRANCH=develop
SDL_POLICY=PROPRIETARY
SDL_3RD_PARTY_LIBS=PREINSTALLED # Possible: BUILD, PREINSTALLED
SDL_TESTS=OFF # Possible: OFF, ON

ATF_REPO=https://github.com/smartdevicelink/sdl_atf
ATF_BRANCH=develop

SCRIPTS_REPO=https://github.com/smartdevicelink/sdl_atf_test_scripts
SCRIPTS_BRANCH=develop

TARGET=./test_sets/smoke_tests.txt

NUM_OF_THREADS_MAX=4

log() {
  echo "["$(date +"%Y-%m-%d %H:%M:%S,%3N")"]" "$1$2$3"
}

log "=== Starting Docker ================================================================================"
log "Docker image: "$DOCKER_IMAGE

DOCKER_RUN="docker run -d -it "\
"--cap-add NET_ADMIN "\
"--mount type=bind,source=$PWD/reports,target=/home/reports "\
"--tmpfs /home:rw,exec,size=5242880k "\
"$DOCKER_IMAGE"

DOCKER_CONTAINER=$($DOCKER_RUN)
log "Docker container: "$DOCKER_CONTAINER
log "----------------------------------------------------------------------------------------------------"

docker exec \
  -it $DOCKER_CONTAINER \
  env \
  COLUMNS=180 \
  LINES=50 \
  SDL_REPO=$SDL_REPO \
  SDL_BRANCH=$SDL_BRANCH \
  SDL_POLICY=$SDL_POLICY \
  SDL_3RD_PARTY_LIBS=$SDL_3RD_PARTY_LIBS \
  SDL_TESTS=$SDL_TESTS \
  NUM_OF_THREADS_MAX=$NUM_OF_THREADS_MAX \
  ATF_REPO=$ATF_REPO \
  ATF_BRANCH=$ATF_BRANCH \
  SCRIPTS_REPO=$SCRIPTS_REPO \
  SCRIPTS_BRANCH=$SCRIPTS_BRANCH \
  TARGET=$TARGET \
  ./s.sh

DOCKER_CONTAINER=$(docker stop $DOCKER_CONTAINER)
log "=== Docker stopped ================================================================================="