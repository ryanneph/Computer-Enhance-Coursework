#import "Basic";

Platform :: #import "platform";

#import "profiler";

#load "json.jai";
#load "types.jai";
#load "reference_haversine.jai";

Compute_Function :: #type (haversine: Haversine_Data) -> float64;
Validate_Function :: #type (haversine: Haversine_Data) -> u64;

Test :: struct {
    name: string;
    compute: Compute_Function;
    validate: Validate_Function;
}

tests :: Test.[
    .{"ReferenceHaversine",          reference_haversine_compute,     reference_haversine_validate},
    .{"ReferenceHaversineCpp",       reference_haversine_cpp_compute, reference_haversine_cpp_validate},
    .{"ReferenceHaversineApproxCpp", reference_haversine_approx_cpp_compute, reference_haversine_approx_cpp_validate},
];

Result :: struct {
    name: string;
    best: float64;
}

main :: () {
    args := get_command_line_arguments();

    // XXX(ryan): remove
    if args.count < 3
        args = string.[args[0], "data/haversine_input_10000000.json", "data/haversine_answer_10000000.bin"];

    if args.count == 3 {
        haversine_data := load_haversine_data(args[1], args[2]);
        if is_valid(haversine_data) {
            reference_sum := haversine_data.sum_answer;

            results: [..]Result;
            for test: tests {
                tester := repetition_test_init(test.name, max_iters=200, improve_threshold=10);

                pair_error_count := test.validate(haversine_data);

                sum_error_count: u64;
                while repetition_test_is_running(*tester) {
                    repetition_test_start(*tester);
                    sum := test.compute(haversine_data);
                    repetition_test_stop(*tester, haversine_data.parsed_byte_count);

                    sum_error_count += cast(u64) !approx_equal(sum, reference_sum);
                }

                result: Result;
                result.name = test.name;
                best := repetition_test_get_best(*tester);
                result.best = gigabytes_per_second(best);
                array_add(*results, result);

                if pair_error_count > 0 || sum_error_count > 0 {
                    print("WARNING: % pairs mismatched, % sums mismatched\n", pair_error_count, sum_error_count);
                }
            }

            // CSV output
            print("name,max_gigabytes_per_second\n");
            for results {
                print("%,%\n", it.name, it.best);
            }

        } else {
            print("ERROR: failed to load test data\n");
        }
        free_haversine_data(haversine_data);
    } else {
        print("usage: % <json_file> <answer_file>\n", args[0]);
    }
}
