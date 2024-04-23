#import "Basic";

#import,dir "../modules/memory_utils";

#if CPU == .X64 {
    #import,file "../modules/arch/x64.jai";

    get_x64_info :: () {
        // We offer an efficient way for a user to query an entire cpuid leaf
        // (i.e. get_cpuid_leaf(eax, ecx)), and extract the interesting bits.
        //
        // There are also several convenience procedures that may result in
        // additional CPUID instructions to be executed (though those results
        // may end up being cached under-the-hood anyways).
        eax, ebx, ecx, edx: u32;

        // Basic Info and Features
        cpu_manufacturer_id_string := get_cpuid_manufacturer_id_string();
        cacheline_size := get_cacheline_size();

        eax, ebx, ecx, edx = get_cpuid_leaf(0x1);
        family, model, stepping := get_cpuid_processor_info();
        has_pat            := !!(edx & (1 << 16));
        has_clflush        := !!(edx & (1 << 19));
        has_mmx            := !!(edx & (1 << 23));
        has_sse            := !!(edx & (1 << 25));
        has_sse2           := !!(edx & (1 << 26));
        has_cache_snooping := !!(edx & (1 << 27));
        has_sse3           := !!(ecx & (1 <<  0));
        has_supp_sse3      := !!(ecx & (1 <<  9));
        has_avx            := !!(ecx & (1 << 28));

        eax, ebx, ecx, edx = get_cpuid_leaf(0x7);
        has_avx2           := !!(ebx & (1 <<  5));

        print("CPU Basic Info/Features:\n");
        print("========================\n");
        print("manufacturer id: '%'\n", cpu_manufacturer_id_string);
        print("family id:        %\n", family);
        print("model:            %\n", model);
        print("stepping id:      %\n", stepping);
        print("cacheline size:   % bytes\n", cacheline_size);
        print("has PAT:          %\n", has_pat);
        print("has CLFLUSH:      %\n", has_clflush);
        print("has MMX:          %\n", has_mmx);
        print("has SSE:          %\n", has_sse);
        print("has SSE2:         %\n", has_sse2);
        print("has SSE3:         %\n", has_sse3);
        print("has supp. SSE3:   %\n", has_supp_sse3);
        print("has snoopy cache: %\n", has_cache_snooping);
        print("has AVX:          %\n", has_cache_snooping);
        print("has AVX2          %\n", has_avx2);
        print("\n");


        // Extended Features (AVX-512)
        avx512 := get_avx512_features();


        print("CPU Extended Features:\n");
        print("======================\n");
        print("has AVX-512 foundation: %\n", avx512.foundation);
        print("has AVX-512 optional instructions:\n");
        print("  - dword/qword          %\n", avx512.dq);
        print("  - integer fma          %\n", avx512.ifma);
        print("  - prefetch             %\n", avx512.pf);
        print("  - exp/recip            %\n", avx512.er);
        print("  - conflict detect      %\n", avx512.cd);
        print("  - byte/word            %\n", avx512.bw);
        print("  - vector length        %\n", avx512.vl);
        print("  - vector bit manip     %\n", avx512.vbmi);
        print("  - vector bit manip2    %\n", avx512.vbmi2);
        print("  - vector neural net    %\n", avx512.vnni);
        print("  - bitalg               %\n", avx512.bitalg);
        print("  - vec popcnt d/qword   %\n", avx512.vpopcntdq);
        print("  - 4-reg neural net     %\n", avx512._4vnniw);
        print("  - 4-reg sp mult/accum  %\n", avx512._4fmaps);
        print("  - vector intersect     %\n", avx512.vp2intersect);
        print("  - fp16 arithmetic      %\n", avx512.fp16);
    }
}

main :: () {
    #if CPU == .X64 {
        get_x64_info();
        exit(0);
    } else {
        print("CPU architecture '%' not supported\n", CPU);
        exit(1);
    }
}
