# New Version of AsyncGetCallTrace

*This might diverge over time from the [JEP draft](https://bugs.openjdk.java.net/browse/JDK-8284289) so please consider reading the JEP draft. This repository is mainly for trying out my prototypical implementation of the JEP draft.*


I propose to

1. Replace duplicated stack walking code with unified API
2. Create a new version of AsyncGetCallTrace, tentatively called "AsyncGetCallTrace2", with more information on more frames using the unified API

Skip to the [Demo section](#demo) if you want to see a prototype of this proposal in action.

## Unify Stack Walking

There are currently multiple implementations of stack walking in JFR and for AsyncGetCallTrace. 
They each implement their own extension of vframeStream but with comparable features
and check for problematic frames.

My proposal is, therefore, to replace the stack walking code with a unified API that
includes all error checking and vframeStream extensions in a single place.
The prosposed new class is called StackWalker and could be part of
`jfr/recorder/stacktrace` [1].
This class also supports getting information on C frames so it can be potentially
used for walking stacks in VMError (used to create hs_err files), further
reducing the amount of different stack walking code.

## AsyncGetCallTrace2

**Summary**

Define an efficient, secure, and supported API for asynchronous stack traces with information on Java and native frames.

**Goals**

- Provide a supported API for external profilers to obtain information on Java and native frames.
- Unify stack walking for profiling to improve its maintainability and stability.
- Support asynchronous usage as well as calling the API from signal handlers.
- The implementation does not affect the performance of an unprofiled JVM.
- Memory requirements for the collected data don't significantly increase compared to the existing AsyncGetCallTrace routine.

**Non-Goals**

- It is not a goal to create a new JVMTI extension.
- The new API shall not be recommended for production usage.

**Motivation**

The AsyncGetCallTrace routine has seen increasing use in recent years in profilers like [async-profiler](https://github.com/jvm-profiling-tools/async-profiler) with almost all available profilers, open-source and commercial, using it. But it is only an internal API, as it is not exported in any header, and the information on frames it returns is pretty limited: Only the method and byte code index for Java frames is captured. Both make implementing profilers and related tooling harder. Tools like async-profiler have to resort to complicated code to at least partially obtain information that the JVM already has. Information that is currently hidden and impossible to get is

- whether a compiled Java frame is inlined which is currently only obtainable for the topmost compiled frames
- the compilation level of a Java frame (e.g. C1 or C2 compiled)
- C/C++ frames that are not at the top of the stack

Such data can be helpful when profiling and tuning a VM for a given application and also for profiling code that uses JNI heavily.

There are two stack walking implementations for profiling (in JFR and AsyncGetCallTrace) that benefit from being unified. This improves maintainability and stability by removing redundant code and increasing coverage.

**Description**

This JEP proposes an AsyncGetCallTrace2 API which is modeled after AsyncGetCallTrace:

```
void AsyncGetCallTrace2(CallTrace *trace, jint depth, void* ucontext,
                        uint32_t options);
```

This API can be called by profilers to obtain the call trace for the current thread. Calling this API from a signal-handler is safe and the new implementation will be at least as stable as
AsyncGetCallTrace or the JFR stack walking code.
The VM fills in information about the frames and the number of frames. The caller of the API should allocate the `CallTrace` structure with enough memory for the requested stack depth. 

Arguments:

- `trace`: buffer for structured data to be filled in by the JVM
- `depth`: maximum depth of the call stack trace
- `ucontext`: optional `ucontext_t` of the current thread when it was interrupted
- `options`: bit set for options, currently only the lowest bit is considered, it enables (`1`) and disables (`0`) the inclusion of C/C++ frames, all other bits are considered to be `0`

The `trace` struct
```
typedef struct {
  jint num_frames;                // number of frames in this trace
  CallFrame *frames;              // frames
  void* frame_info;               // more information on frames
} CallTrace;
```
is filled by the VM. Its `num_frames` field contains the actual number of frames in the `frames` array or an error code. 
The `frame_info` field in that structure can later be used to store more information but is currently supposed to be NULL.

The error codes are a subset of the error codes for `AsyncGetCallTrace`, with the addition of `THREAD_NOT_JAVA` related to calling this procedure for non-Java threads:

```
enum Error {
  NO_JAVA_FRAME         =   0,
  NO_CLASS_LOAD         =  -1, 
  GC_ACTIVE             =  -2,    
  UNKNOWN_NOT_JAVA      =  -3,
  NOT_WALKABLE_NOT_JAVA =  -4,
  UNKNOWN_JAVA          =  -5,
  UNKNOWN_STATE         =  -7,
  THREAD_EXIT           =  -8,
  DEOPT                 =  -9,
  THREAD_NOT_JAVA       = -10
};
```

Every `CallFrame` is the element of a union, as the information stored for Java and non-Java frames differs:

```
typedef union {
  FrameTypeId type;     // to distinguish between JavaFrame and NonJavaFrame 
  JavaFrame java_frame;
  NonJavaFrame non_java_frame;
} CallFrame;
```

There a several distinguishable frame types:

```
enum FrameTypeId {
  FRAME_JAVA         = 1, // JIT compiled and interpreted
  FRAME_JAVA_INLINED = 2, // inlined JIT compiled
  FRAME_NATIVE       = 3, // native wrapper to call C methods from Java
  FRAME_STUB         = 4, // VM generated stubs
  FRAME_CPP          = 5  // C/C++/... frames
};
```
The first two types are for Java frames for which we store the following information in a struct of type `JavaFrame`:

```
typedef struct {     
  uint8_t type;            // frame type
  uint8_t comp_level;      // compilation level, 0 is interpreted
  uint16_t bci;            // 0 < bci < 65536
  jmethodID method_id;
} JavaFrame;               // used for FRAME_JAVA and FRAME_JAVA_INLINED
```

The `comp_level` states the compilation level of the method related to the frame with higher numbers representing "more" compilation. 0 is defined as interpreted. It is modeled after the `CompLevel` enum in `compiler/compilerDefinitions` but is dependent on the used compiler infrastructure.

Information on all other frames is stored in the `NonJavaFrame` struct:

```
typedef struct {
  FrameTypeId type;  // frame type
  void *pc;          // current program counter inside this frame
} NonJavaFrame;  
```

Although the API provides more information on the frames, the amount of space required per frame (e.g. 16 bytes on x86) is the same as for the original AsyncGetCallTrace API.

The underlying stack walking code can be unified such that `AsyncGetCallTrace`, `AsyncGetCallTrace2`, and the JFR call stack collection become thin wrappers for a single implementation. 

A prototype implementation can be found at https://github.com/parttimenerd/asgct2-demo/.

**Alternatives**

Keep AsyncGetCallTrace as is, meaning a lack of maintenance and stability for a widely used de-facto API.

**Risks and Assumptions**

Returning information on C/C++ frames leaks implementation details, but this is also true for the Java frames of AsyncGetCallTrace as they leak details of the implementation of standard library files and include native wrapper frames.

**Testing**

Unifying the existing profiling-related stack walking code allows for testing it more efficiently by combining the existing tests.
The implementation of this JEP will also add new stress tests to find rare stability problems on all supported platforms. The idea is to run the profiling on a set of example programs (for example the dacapo and renaissance benchmark suites) repeatedly with small profiling intervals (<= 0.1ms).


## Demo

This project showcases the ideas behind the drafted extension of the AsyncGetCallTrace
call and combines the modified [JDK](https://github.com/parttimenerd/jdk/tree/parttimenerd_asgct2)
and the related [async-profiler fork](https://github.com/SAP/async-profiler/tree/parttimenerd_asgct2)
which uses the API.

### Build

Either build the JDK in the folder `jdk` as you would usually do
(it's a JDK 19, release builds are recommended) 
and build the async-profiler in the folder 
`async-profiler` via make or run `./build.sh`.
Be sure to install the required dependencies (you will probably
see related error messages if you don't).

*It is based on OpenJDK head but the changes should be easy to backport to previous versions.*

### Demo Script

`./run.sh AGENT_ARGS JAVA_ARGS...` which uses the built JDK and async-profiler.

For example, to run a [dacapo](https://github.com/dacapobench/dacapobench) benchmark, e.g jython, and generate a flame graph run

```sh
test -e dacapo.jar || wget https://downloads.sourceforge.net/project/dacapobench/9.12-bach-MR1/dacapo-9.12-MR1-bach.jar -O dacapo.jar

./run.sh flat=10,traces=1,interval=500us,event=cpu,flamegraph,file=flame.html -jar dacapo.jar jython
```
*With an interval of 500us (0.5ms), more information on the arguments in the [async-profiler](https://github.com/SAP/async-profiler/tree/parttimenerd_asgct2).
Use another benchmark like tomcat instead of jython, if the flame graph misses the bottom frames.*

This results in a flame graph like (click on the image to get to the HTML flame graph):

[![Crop of the generated flame graph for jython dacapo benchmark](img/jython.png)](https://htmlpreview.github.io/?https://github.com/parttimenerd/asgct2-demo/blob/main/img/jython.html)

*Orange frames are related to C/C++ internal JVM methods, red frames are related to other C/C++ code, darker green frames to interpreted methods, lighter green frames to compiled methods and blue frames to inlined compiled methods.*

The usage of the new draft AsyncGetCallTrace gives us the following additions to a normal
async-profiler flame graph: Information on the compilation stage (C1 vs C2 compiler),
inlining information for non-top frames, and the c frames starting with `_pthread_start`
up to the first Java frame. This information was previously unobtainable by async-profiler
(or any other profiler using just JFR or AsyncGetCallTrace).

The same flame graph using the old AsyncGetCallTrace can be found [here](img/jython_old.png) 
(using [async-profiler](https://github.com/SAP/async-profiler/tree/distinguish_inlined_frames2)
that includes the hover texts).
