#!/bin/bash

set -e

if [ "$1" = 'youtrack' ]; then
  shift
  exec ./bin/youtrack.sh "$@"
fi

exec "$@"
