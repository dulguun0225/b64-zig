const EncDec = @import("b64_zig_lib").EncDec;
const std = @import("std");

pub fn main() void {
    var cli = EncDec(false).init() catch {
        return;
    };
    defer cli.deinit();
    cli.run();
}
