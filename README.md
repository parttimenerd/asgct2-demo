# Asynchronous Stack Trace VM API

This repo combines an implementation of [JEP candidate](https://openjdk.org/jeps/435) with an [async-profiler fork](https://github.com/parttimenerd/async-profiler/tree/parttimenerd_asgct2)
which uses the API, giving an example on how to easily migrate an application which uses the old API.

### Build

Either build the JDK in the folder `jdk` as you would usually do
(it's a JDK 20, release builds are recommended) 
and build the async-profiler in the folder 
`async-profiler` via make or run `./build.sh`.
Be sure to install the required dependencies (you will probably
see related error messages if you don't) and use a current JDK (19 or 20).

*It is based on OpenJDK head but the changes should be easy to backport to previous versions.*

### Demo Script

`./run.sh AGENT_ARGS JAVA_ARGS...` which uses the built JDK and async-profiler.

For example, to run a [dacapo](https://github.com/dacapobench/dacapobench) benchmark, e.g jython, and generate a flame graph run

```sh
test -e dacapo.jar || wget https://downloads.sourceforge.net/project/dacapobench/9.12-bach-MR1/dacapo-9.12-MR1-bach.jar -O dacapo.jar

./run.sh flat=10,traces=1,interval=500us,event=cpu,flamegraph,file=flame.html -jar dacapo.jar jython
```
*With an interval of 500us (0.5ms), more information on the arguments in the [async-profiler](https://github.com/parttimenerd/async-profiler/tree/parttimenerd_asgct2).
Use another benchmark like tomcat instead of jython, if the flame graph misses the bottom frames.*

This resulted in a flame graph like (click on the image to get to the HTML flame graph):

[![Crop of the generated flame graph for jython dacapo benchmark](img/jython.png)](https://htmlpreview.github.io/?https://github.com/parttimenerd/asgct2-demo/blob/main/img/jython.html)

*Orange frames are related to C/C++ internal JVM methods, red frames are related to other C/C++ code, darker green frames to interpreted methods, lighter green frames to compiled methods and blue frames to inlined compiled methods.*

The usage of the new AsyncGetStackTrace gives us the following additions to a normal
async-profiler flame graph: Information on the compilation stage (C1 vs C2 compiler),
inlining information for non-top frames, information on C frames starting with `_pthread_start`
up to the first Java frame and C frames between Java frames. This information was previously unobtainable by async-profiler
(or any other profiler using just JFR or AsyncGetCallTrace).

The same flame graph using the old AsyncGetCallTrace can be generated using the following:

```sh
test -e dacapo.jar || wget https://downloads.sourceforge.net/project/dacapobench/9.12-bach-MR1/dacapo-9.12-MR1-bach.jar -O dacapo.jar
test -e ap-loader.jar || wget https://github.com/jvm-profiling-tools/ap-loader/releases/latest/download/ap-loader-all.jar -O ap-loader.jar
java -javaagent:./ap-loader.jar=start,flat=10,traces=1,interval=500us,event=cpu,flamegraph,file=flame_old.html -jar dacapo.jar jython
```

This resulted in a flame graph like (click on the image to get to the HTML flame graph):

[![Crop of the generated flame graph for jython dacapo benchmark](img/jython_old.png)](https://htmlpreview.github.io/?https://github.com/parttimenerd/asgct2-demo/blob/main/img/jython_old.html)

Showing the stark difference in the amount of available information.
