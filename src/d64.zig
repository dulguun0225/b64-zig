const Cli = @import("b64_zig_lib").Cli;
const std = @import("std");

pub fn main() void {
    std.debug.print("CLI FALSE ", .{});
    var cli = Cli(false){};
    cli.run();
}
