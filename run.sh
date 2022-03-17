#! /bin/sh

SCRIPT_PATH=$(readlink -f "$0")

cd $(dirname "$SCRIPT_PATH")

export JAVA_HOME=`echo jdk/build/*/images/jdk`
export PATH="$JAVA_HOME/bin:$PATH"

agent=$1
shift
java -agentpath:./async-profiler/build/libasyncProfiler.so=start,$agent -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints $@
