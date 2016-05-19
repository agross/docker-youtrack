#!/bin/bash

set -e

if [ "$1" = 'youtrack' ]; then
  SCRIPT=./bin/$1.sh

  # More information: http://veithen.github.io/2014/11/16/sigterm-propagation.html
  trap "echo Received INT;  "$SCRIPT" stop" INT   # Ctrl + C.
  trap "echo Received TERM; "$SCRIPT" stop" TERM  # docker stop graceful shutdown.

  shift
  "$SCRIPT" "$@" &
  PID=$!

  echo Started with PID $PID, waiting for exit signal.
  wait $PID

  trap - INT TERM

  wait $PID
  exit $?
fi

exec "$@"
