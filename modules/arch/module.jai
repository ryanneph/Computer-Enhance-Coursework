#if CPU == .X64 {
    #load "x64.jai";
} else {
    #assert(false && "unsupported arch");
}
