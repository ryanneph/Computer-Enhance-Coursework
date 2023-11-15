#import "Basic";

Pointer_Decomposition :: struct {
    pml4e_index: u16; // page-map-level-4 (bits 39-47)
    pdpte_index: u16; // page-directory-pointer-table (bits 30-38)
    pde_index:   u16; // page-directory (bits 21-29)
    pte_index:   u16; // page-table (bits 12-20)
    offset:      u32; // offset from page base address (bits 0-11)
}

decompose_pointer_4k_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.pde_index   = cast(u16) (raw >> 21) & 0x1FF;
    decomp.pte_index   = cast(u16) (raw >> 12) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0xFFF;

    return decomp;
}

decompose_pointer_2mb_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.pde_index   = cast(u16) (raw >> 21) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0x1FFFFF;

    return decomp;
}

decompose_pointer_1gb_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0x3FFFFFFF;

    return decomp;
}
