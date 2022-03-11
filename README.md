# AsyncGetCallTrace Extension Demo

This project showcases the ideas behind the drafted extension of the AsyncGetCallTrace
call and combines the modified [JDK](https://github.com/parttimenerd/jdk/tree/parttimenerd_asgct2)
and the related [async-profiler fork](https://github.com/SAP/async-profiler/tree/parttimenerd_asgct2)
which uses the API.

## Build

Either build the JDK in the folder `jdk` as you would usually do
(it's a JDK 19, release builds are recommended) 
and build the async-profiler in the folder 
`async-profiler` via make or run `./build.sh`.
Be sure to install the required dependencies (you will probably
see related error messages if you don't).

## Demo script

`./run.sh AGENT_ARGS JAVA_ARGS...` which uses the built JDK and async-profiler.

For example, to run a [dacapo](https://github.com/dacapobench/dacapobench) benchmark, e.g jython, and generate a flamegraph run

```sh
test -e dacapo.jar || wget https://downloads.sourceforge.net/project/dacapobench/9.12-bach-MR1/dacapo-9.12-MR1-bach.jar -O dacapo.jar

./run.sh flat=10,traces=1,interval=0.5ms,event=cpu,flamegraph,file=flame.html -jar dacapo.jar jython
```
*with an interval of 0.5ms, more information on the arguments in the [async-profiler](https://github.com/SAP/async-profiler/tree/parttimenerd_asgct2)*

This results in a flamegraph like (click on the image to get to the HTML flamegraph):

[![Crop of the generated flamegraph for jython dacapo benchmark](img/jython.png)](https://htmlpreview.github.io/?https://github.com/parttimenerd/asgct2-demo/blob/main/img/jython.html)

The usage of the new draft AsyncGetCallTrace gives us the following additions to a normal
async-profiler flamegraph: Information on the compilation stage (C1 vs C2 compiler),
inlining information for non-top frames and the c frames starting with `_pthread_start`
upto the first Java frames. This information was previously unobtainable by async-profiler
(or any other profiler using just JFR or AsyncGetCallTrace).

The same flamegraph using the old AsyncGetCallTrace can be found [here](img/jython_old.png) 
(using [async-profiler](https://github.com/SAP/async-profiler/tree/distinguish_inlined_frames2)
that includes the hover texts).


## Technical stuff

### Problems with current code
- code duplication between JFR and AsyncGetCallTrace and possibly other places in the JVM like pnd
- Licensing problems regarding AsyncGetCallTrace: it has no classpath exception
- lacking information: the JVM already has information on inlining and more, why not make it accessible
- the JVM already walks the stack and walks over native frames, so information on them could simplify applications like async-profiler

### Proposed changes
- introduce a new stackWalker class that wraps the implementation details of stack walking and exposes a cleaner API and adds more checks (curtesy to the integrated AsyncGetCallTrace code)
- introduce a new AsyncGetCallTrace version which uses this stack walker class to give more information
  - its implementation is straightforward
  - gives information on all frames, not just java frames 
  - propose data structure
  - current data structure (required less modifications in async-profiler)
- give remarks on changed files
