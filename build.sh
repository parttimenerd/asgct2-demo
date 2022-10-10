#! /bin/bash

SCRIPT_PATH=$(readlink -f "$0")

cd $(dirname "$SCRIPT_PATH")

(cd jdk; git checkout parttimenerd_asgst; git pull -f; bash configure; make images)
export JAVA_HOME=(jdk/**/*-release/images/jdk)
(cd async-profiler; git checkout parttimenerd_asgst; git pull -f; git checkout parttimenerd_asgst; make)

