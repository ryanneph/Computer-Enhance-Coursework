#scope_export
b32 :: bool;

Buffer :: struct {
    count: u64;
    data: *u8;
}

BUFFER :: (input: string) -> Buffer #expand {
    result := Buffer.{cast(u64, input.count), input.data};
    return result;
}

is_valid :: (buffer: Buffer) -> b32 {
    result := buffer.data != null;
    return result;
}

is_in_bounds :: (buffer: Buffer, at: u64) -> b32 {
    result := at < buffer.count;
    return result;
}

are_equal :: (a: Buffer, b: Buffer) -> b32 {
    if (a.count != b.count)  return false;
    if (a.count == 0)        return true;

    for 0..a.count-1 {
        if (a.data[it] != b.data[it])  return false;
    }
    return true;
}

as_string :: (buffer: Buffer) -> string {
    return string.{xx buffer.count, buffer.data};
}

Point_Pair :: struct {
    x0, y0: float64;
    x1, y1: float64;
}
