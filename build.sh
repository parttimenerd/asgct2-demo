#! /bin/sh

case "$(uname -s)" in
   Darwin)
     SCRIPT_PATH=$(greadlink -f "$0")
     ;;

   *)
     SCRIPT_PATH=$(readlink -f "$0")
     ;;
esac

cd $(dirname "$SCRIPT_PATH")

(cd jdk; bash configure; make images)
(cd async-profiler; make)

