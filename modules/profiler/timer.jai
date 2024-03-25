Timer :: struct {
    start: u64;
    elapsed: u64;
}
timer_start :: (using timer: *Timer) {
    start = read_cpu_timer();
}
timer_stop :: (using timer: *Timer) {
    timer_stop := read_cpu_timer();
    elapsed += timer_stop - start;
}
timer_reset :: (using timer: *Timer) {
    elapsed = 0;
}
timer_seconds :: (using timer: *Timer) -> float64 {
    return cast(float64) elapsed / get_cpu_timer_freq();
}
