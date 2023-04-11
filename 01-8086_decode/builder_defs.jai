// The types and declarations in this file are known only at compile time. They are used to generate
// various tables and helpers, that get injected during the main program build procedure.
//
// See "builder_workspace" in build.jai

Register_Definition :: struct {
    bit_encoding: u8;     // field_reg(3-bit) | field_w(1-bit)
    offset: u8;
    size:   u8;
}

// NOTE(ryan): register name is everything after the last "_"
// These are detected at compile-time to generate index-matched #placeholder tables above.
register_al :: Register_Definition.{0b0000,  0, 1};
register_ax :: Register_Definition.{0b0001,  0, 2};
register_cl :: Register_Definition.{0b0010,  4, 1};
register_cx :: Register_Definition.{0b0011,  4, 2};
register_dl :: Register_Definition.{0b0100,  6, 1};
register_dx :: Register_Definition.{0b0101,  6, 2};
register_bl :: Register_Definition.{0b0110,  2, 1};
register_bx :: Register_Definition.{0b0111,  2, 2};
register_ah :: Register_Definition.{0b1000,  1, 1};
register_sp :: Register_Definition.{0b1001,  8, 2};
register_ch :: Register_Definition.{0b1010,  5, 1};
register_bp :: Register_Definition.{0b1011, 10, 2};
register_dh :: Register_Definition.{0b1100,  7, 1};
register_si :: Register_Definition.{0b1101, 12, 2};
register_bh :: Register_Definition.{0b1110,  3, 1};
register_di :: Register_Definition.{0b1111, 14, 2};
