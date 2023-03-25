#import "Basic";
#import "File";

file_read_all_as_bytes :: (filename: string) -> (data: []u8, success: bool) {
    file, success := file_open(filename, for_writing=false, keep_existing_content=true);
    if !success
        return .[], false;

    count := file_length(file);
    data := alloc(count);
    if !file_read(file, data, count)
        return .[], false;

    output: []u8;
    output.data = data;
    output.count = count;

    return output, true;
}
