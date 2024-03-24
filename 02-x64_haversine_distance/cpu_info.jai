#import "Basic";

#import,dir "./memory_utils";

main :: () {
    cpu_manufacturer_id_string := get_cpuid_manufacturer_id_string();
    cacheline_size := get_cacheline_size();
    print("cpu manufacturer id='%'\n", cpu_manufacturer_id_string);
    print("has CLFLUSH=%\n", cacheline_size > 0);
    print("Cacheline Size: %\n", cacheline_size);
}
