// set DISABLED = true to make all calls no-ops, so instrumentation is disabled
// without modifying one's program
#module_parameters()(DISABLED := false);

#load "counters.jai";
#load "profiler.jai";
#load "repetition_tester.jai";
#load "timer.jai";
#load "timing.jai";
