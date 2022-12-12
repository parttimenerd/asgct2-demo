#! /bin/bash

SCRIPT_PATH=$(readlink -f "$0")

cd $(dirname "$SCRIPT_PATH")

(cd jdk; git checkout asgct2; git pull -f; bash configure --disable-precompiled-headers --disable-warnings-as-errors; make images)
export JAVA_HOME=(jdk/**/*-release/images/jdk)
(cd async-profiler; git checkout parttimenerd_asgct2; git pull -f; git checkout parttimenerd_asgct2; make)

