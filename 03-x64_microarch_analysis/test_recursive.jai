#import "Basic";

#import,dir "../modules/profiler"()(DISABLED=false);

recurse :: (depth: s64) {
    profile_function();
    if depth >= 1000  return;

    print("recurse depth: %\n", depth);
    sleep_milliseconds(1);
    recurse(depth + 1);
}

main :: () {
    print("Hello\n");

    profiler_begin();

    recurse(1);
    recurse(1);
    recurse(1);

    profiler_end_and_summarize();
}
