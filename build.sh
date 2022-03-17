#! /bin/sh

SCRIPT_PATH=$(readlink -f "$0")

cd $(dirname "$SCRIPT_PATH")

(cd jdk; bash configure; make images)
(cd async-profiler; make)

