const Cli = @import("b64_zig_lib").Cli;

pub fn main() void {
    var cli = Cli(true){};
    cli.run();
}
