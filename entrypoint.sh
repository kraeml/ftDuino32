#!/usr/bin/env bash
set -e

. ~/.bashrc
. $IDF_PATH/export.sh


exec "$@"
