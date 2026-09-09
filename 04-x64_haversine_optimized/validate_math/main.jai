#import "Basic";
#import "Math";
#import "Sort";

#load "golden_data.jai";
absolute_error_threshold: float64 : 1.0E-12;

Test_Case :: struct {
    input: float64;
    expected: float64;
}

Test_Result :: struct {
    test_count: u64;
    error_count: u64;
    max_absolute_error: float64;
}

Golden_Test_Result :: struct {
    name: string; result: Test_Result;
}

compute_proc_type :: #type (float64) -> float64;
run_golden_test :: ($compute_proc: compute_proc_type, test_cases: []Test_Case) -> Test_Result {
    error_count: u64;
    max_absolute_error := FLOAT64_MIN;

    for test: test_cases {
        computed: float64 = compute_proc(test.input);
        absolute_error := abs(computed - test.expected);
        // print("computed=%, expected=%, absolute_error: %\n", computed, test.expected, absolute_error);
        if absolute_error >= absolute_error_threshold {
            error_count += 1;
        }
        max_absolute_error = max(max_absolute_error, absolute_error);
    }

    result := Test_Result.{
        xx test_cases.count,
        error_count,
        max_absolute_error,
    };
    return result;
}
print_header :: (builder: *String_Builder, format: string, args: ..Any) {
    print_to_builder(builder, "\n");

    before_length := builder_string_length(builder);
    print_to_builder(builder, format, ..args);
    header_length := builder_string_length(builder) - before_length;

    print_to_builder(builder, "\n");

    for 1..header_length  print_to_builder(builder, "-");
    print_to_builder(builder, "\n");
}
print_results :: (builder: *String_Builder, golden_results: []Golden_Test_Result) {
    print_header(builder, "Golden Data Test Summary (error_threshold=%)", formatFloat(absolute_error_threshold, mode=.SCIENTIFIC));
    for golden_results {
        using it;
        using it.result;
        if test_count > 0 {
            print_to_builder(builder, "- %: #errors=%/% max_absolute_error=%\n",
                name, error_count, test_count, max_absolute_error);
        } else {
            print_to_builder(builder, "- %: no tests cases\n", name);
        }
    }
}

libintrinsicscpp :: #library,no_dll "libintrinsicscpp";
// quadratic approximation
sinq :: (input: float64) -> float64 {
    A: float64 : -4.0 / (PI64 * PI64);
    B: float64 : 4.0 / PI64;

    x := input;
    sign: float64 = 1.0;
    if x < 0 {
        x = -x;
        sign = -1.0;
    }

    result := sign * (A*x*x + B*x);
    return result;
}

// precompute taylor series coefficients at compile-time
PRECOMP_MAX :: 40;
sin_taylor_coeff_compute :: (power: u64) -> float64 {
    result: float64 = 0;

    factorial :: (x: u64) -> float64 {
        result: float64 = cast(float64, x);
        while x > 1 {
            x -= 1;
            result *= cast(float64, x);
        }
        return result;
    }

    sign: float64 = ifx (((power - 1)/2) % 2) then -1.0 else 1.0;
    sign *= (power & 1); // even terms are zero for taylor series of sin(t) taken at x=0
    result = sign / factorial(power);
    return result;
}
sin_taylor_precomputed := #run -> [PRECOMP_MAX]float64 {
    out: [PRECOMP_MAX]float64;

    power: u64 = 1;
    while power <= PRECOMP_MAX {
        out[power] = sin_taylor_coeff_compute(power);
        power += 2;
    }

    return out;
}
sin_taylor_coeff :: ($$power: u64) -> float64 {
    if power < sin_taylor_precomputed.count {
        return sin_taylor_precomputed[power];
    } else {
        result := sin_taylor_coeff_compute(power);
        return result;
    }
}

// taylor-series approximation
sint :: (input: float64, $$order: u64 = 5) -> float64 {
    result := input;
    squared := input * input;

    input_product := input;
    i: u64 = 3;
    while i <= order {
        input_product *= squared;
        result += sin_taylor_coeff(i) * input_product;

        i += 2;
    }

    return result;
}

// horner's rule to evaluate polynomials more efficiently by factoring out the variable term
sint_horner :: (input: float64, $$order: u64 = 5) -> float64 {
    result: float64 = 0;
    squared := input * input;

    i: u64 = 1;
    while i <= order {
        index := order - (i-1);
        result = squared * result + sin_taylor_coeff(index);

        i += 2;
    }
    result *= input;

    return result;
}

// horner's rule to evaluate polynomials more efficiently by factoring out the variable term
sint_horner_fma :: (input: float64, $$order: u64 = 5) -> float64 {
    result: float64 = 0;
    squared := input * input;

    i: u64 = 1;
    while i <= order {
        index := order - (i-1);
        result = fmad_intrin(squared, result, sin_taylor_coeff(index));

        i += 2;
    }
    result *= input;

    return result;
}

// taylor-series approximation, computed backwards to mimic horner's version for reduced
// error (at greater compute cost).
sint_backward :: (input: float64, $$order: u64 = 5) -> float64 {
    result: float64 = 0;
    squared := input * input;

    i: s64 = 1;
    while i <= xx order {
        power := xx order - i + 1;

        product := input;
        j := 3;
        while j <= power {
            product *= squared;
            j += 2;
        }
        result += product * sin_taylor_coeff(xx power);

        i += 2;
    }

    return result;
}

sint_backward_fma :: (input: float64, $$order: u64 = 5) -> float64 {
    result: float64 = 0;
    squared := input * input;

    i: s64 = 1;
    while i <= xx order {
        power := xx order - i + 1;

        product := input;
        j := 3;
        while j <= power {
            product *= squared;
            j += 2;
        }
        result = fmad_intrin(product, sin_taylor_coeff(xx power), result);

        i += 2;
    }

    return result;
}

bind_to_cpp :: (name: string) -> string #compile_time {
    format := #string END
        %1 :: (input: float64) -> float64 {
            proc :: (x: float64) -> float64 #foreign libintrinsicscpp "%1_cpp";
            result := proc(input);
            return result;
        }
    END
    return tprint(format, name);
}
#insert #run bind_to_cpp("sqrt_intrin");
#insert #run bind_to_cpp("sqrt_intrin_f32");
#insert #run bind_to_cpp("sqrt_intrin_rcp");
#insert #run bind_to_cpp("sinq_intrin");
#insert #run bind_to_cpp("cosq_intrin");
#insert #run bind_to_cpp("asin_intrin1");
#insert #run bind_to_cpp("asin_intrin2");
#insert #run bind_to_cpp("asin_intrin3");
fmad_intrin :: (a: float64, b: float64, c: float64) -> float64 #foreign libintrinsicscpp "fmad_intrin_cpp";


Math_Tester_Result :: struct {
    label: string;
    label_storage: [64]u8;

    total_diff: float64;
    diff_count: u64;
    average_diff: float64;

    max_absolute_error: float64;
    input_at_max_error: float64;
    reference_at_max_error: float64;
    computed_at_max_error: float64;
    diff_at_max_error: float64;
}
Math_Tester :: struct {
    builder: *String_Builder; // NOTE(ryan): optional - set at initialization
    fallback_builder: String_Builder;

    step_size: float64;
    sample_index: u64;
    running: bool;

    input_value: float64; // NOTE(ryan): is set within each call to math_test();

    results_storage: [256]Math_Tester_Result;
    result_offset: u64;

    sentinel_result: Math_Tester_Result;
}
set_label :: (using test_result: *Math_Tester_Result, format: string, args: ..Any) {
    max_len := size_of(type_of(label_storage));
    label.data = label_storage.data;

    temp := tprint(format, ..args);
    label.count = min(temp.count, max_len);
    memcpy(label.data, temp.data, label.count);
}

// run one iteration of the tester, storing the next vale to .input
// and return true if more iterations remain
math_test :: (using tester: *Math_Tester, sample_first: float64, sample_last: float64, sample_count: u64 = 100_000_000) -> bool {
    if running {
        sample_index += 1;
    } else {
        // NOTE(ryan): test was started for first time or restarted after completing
        if !builder {
            builder = *fallback_builder;
        }

        sample_index = 0;
        running = true;
    }

    if sample_index < sample_count {
        result_offset = 0;

        t := sample_index / cast(float64, sample_count-1);
        input_value = (1.0 - t)*sample_first + t*sample_last;
    } else {
        running = false;

        // reusable float formatting
        format_context := context;
        format_float := *format_context.print_style.default_format_float;
        format_float.zero_removal = .NO;
        format_float.positive_number_prefix = .PLUS;
        format_float.trailing_width = 24;
        format_float.mode = .DECIMAL;

        print_to_builder(builder, "\n");
        print_to_builder(builder, "max abs error               (avg error                  )    input value\n");
        print_to_builder(builder, "--------------------------- ----------------------------- -- ---------------------------\n");

        results := []Math_Tester_Result.{ cast(s64, result_offset), results_storage.data };
        for *test_result: results {
            using test_result;
            average_diff = ifx diff_count > 0 then total_diff / cast(float64, diff_count) else 0;

            push_context format_context {
                print_to_builder(builder, "% (%) at % [%]\n", diff_at_max_error, average_diff, input_at_max_error, label);
            }
        }

        // sort results by ascending max error, use references to avoid copying entire structs when sorting
        result_references: [..] *Math_Tester_Result;
        for *result: results {
            using result;
            array_add(*result_references, result);
        }
        compare :: (a: *Math_Tester_Result, b: *Math_Tester_Result) -> float64 {
            cmp := a.max_absolute_error - b.max_absolute_error;
            if !cmp {
                cmp = abs(a.average_diff) - abs(b.average_diff);
            }
            return cmp;
        }
        quick_sort(result_references, compare);

        print_to_builder(builder, "\n");
        print_to_builder(builder, "sorted by max abs error (top ascending)\n");
        print_to_builder(builder, "------------------------------------------\n");

        for i: 0..result_references.count-1 {
            result := result_references[i];
            using result;

            push_context format_context {
                print_to_builder(builder, "% (%) [%", max_absolute_error, average_diff, label);

                while i+1 < result_references.count {
                    next_result := result_references[i+1];
                    if !compare(next_result, result) {
                        print_to_builder(builder, ", %", next_result.label);
                        i += 1;
                    } else {
                        break;
                    }
                }
                print_to_builder(builder, "]\n");
            }
        }

        if builder == *fallback_builder
            write_builder(builder);
    }

    return running;
}

// record the result for the current iteration
test_result :: (using tester: *Math_Tester, actual: float64, result: float64, label: string, args: ..Any) {
    test_result := *sentinel_result;
    if result_offset < results_storage.count {
        test_result = *results_storage[result_offset];
    } else {
        print_to_builder(builder, "ERROR: out of room to store test results.\n");
        return;
    }

    if sample_index == 0 {
        set_label(test_result, label, ..args);
    }

    diff := actual - result;
    test_result.total_diff += diff;
    test_result.diff_count += 1;

    absolute_error := abs(diff);
    if absolute_error > test_result.max_absolute_error {
        test_result.max_absolute_error = absolute_error;
        test_result.input_at_max_error = input_value;
        test_result.reference_at_max_error = actual;
        test_result.computed_at_max_error = result;
        test_result.diff_at_max_error = diff;
    }

    result_offset += 1;
}

main :: () {
    builder: String_Builder;

    //
    // Golden Tests
    //
    golden_results := Golden_Test_Result.[
        .{"sin",  run_golden_test(sin,  sin_golden_tests)},
        .{"cos",  run_golden_test(cos,  cos_golden_tests)},
        .{"asin", run_golden_test(asin, asin_golden_tests)},
        .{"sqrt", run_golden_test(sqrt, sqrt_golden_tests)},
    ];
    print_results(*builder, golden_results);

    tester: Math_Tester;
    tester.builder = *builder;

    while math_test(*tester, 0, PI/2) {
        input := tester.input_value;
        actual := sin(input);
        result: float64;

        taylor_highest_term :: 31;
        for n: 1..cast(u64, taylor_highest_term) {
            result = sint(input, n);
            test_result(*tester, actual, result, "sin_taylor%", n);

            result = sint_horner(input, n);
            test_result(*tester, actual, result, "sin_taylor%_horner", n);

            result = sint_backward(input, n);
            test_result(*tester, actual, result, "sin_taylor%_backward", n);

            result = sint_horner_fma(input, n);
            test_result(*tester, actual, result, "sin_taylor%_horner_fma", n);

            result = sint_backward_fma(input, n);
            test_result(*tester, actual, result, "sin_taylor%_backward_fma", n);

            n += 1;
        }

        result = sinq(input);
        test_result(*tester, actual, result, "sinq_halfdomain");

        result = sinq_intrin(input);
        test_result(*tester, actual, result, "sinq_quartdomain_intrin");
    }

    while math_test(*tester, -PI/2, PI/2) {
        test_result(*tester, cos(tester.input_value), cosq_intrin(tester.input_value), "cosq_quartdomain_intrin");
    }

    while math_test(*tester, 0.0, 1.0) {
        actual := asin(tester.input_value);
        test_result(*tester, actual, asin_intrin1(tester.input_value), "asin_intrin1");
        test_result(*tester, actual, asin_intrin2(tester.input_value), "asin_intrin2");
        test_result(*tester, actual, asin_intrin3(tester.input_value), "asin_intrin3");
    }

    while math_test(*tester, 0.0, 1.0) {
        actual := sqrt(tester.input_value);
        test_result(*tester, actual, sqrt_intrin(tester.input_value), "sqrt_intrin");
        test_result(*tester, actual, sqrt_intrin_f32(tester.input_value), "sqrt_intrin_f32");
        test_result(*tester, actual, sqrt_intrin_rcp(tester.input_value), "sqrt_intrin_rcp");
    }

    write_builder(*builder);
}
