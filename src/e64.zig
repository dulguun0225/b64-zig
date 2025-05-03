const EncDec = @import("b64_zig_lib").EncDec;

pub fn main() !void {
    var cli = EncDec(true).init() catch {
        return;
    };
    defer cli.deinit();
    cli.run();
}
