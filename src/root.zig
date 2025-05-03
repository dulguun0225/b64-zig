const std = @import("std");
const io = std.io;
const fs = std.fs;

pub const ENCODE_INDEX = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
pub const DECODE_INDEX = [_]u8{
    0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  62, 0,  0,  0,  63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 0,  0, 0, 0, 0, 0,
    0, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 0, 0, 0, 0, 0,
    0, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 0, 0, 0, 0, 0,
};

pub inline fn encode_chunk(len: usize, chunk_in: *[3]u8, chunk_out: *[4]u8) void {
    switch (len) {
        3 => {
            const b0 = chunk_in[0] >> 2;
            chunk_out[0] = ENCODE_INDEX[b0];

            const b1 = ((chunk_in[0] & 0b11) << 4) | (chunk_in[1] >> 4);
            chunk_out[1] = ENCODE_INDEX[b1];

            const b2 = ((chunk_in[1] & 0b1111) << 2) | (chunk_in[2] >> 6);
            chunk_out[2] = ENCODE_INDEX[b2];

            const b3 = chunk_in[2] & 0b111111;
            chunk_out[3] = ENCODE_INDEX[b3];
        },
        2 => {
            const b0 = chunk_in[0] >> 2;
            chunk_out[0] = ENCODE_INDEX[b0];

            const b1 = ((chunk_in[0] & 0b11) << 4) | (chunk_in[1] >> 4);
            chunk_out[1] = ENCODE_INDEX[b1];

            const b2 = ((chunk_in[1] & 0b1111) << 2);
            chunk_out[2] = ENCODE_INDEX[b2];

            chunk_out[3] = '=';
        },
        1 => {
            const b0 = chunk_in[0] >> 2;
            chunk_out[0] = ENCODE_INDEX[b0];

            const b1 = ((chunk_in[0] & 0b11) << 4);
            chunk_out[1] = ENCODE_INDEX[b1];

            chunk_out[2] = '=';
            chunk_out[3] = '=';
        },
        else => {},
    }
}

pub inline fn decode_chunk(chunk_in: *[4]u8, chunk_out: *[3]u8) usize {
    var byte_count: usize = 1;
    chunk_out[0] = (DECODE_INDEX[chunk_in[0]] << 2) | ((DECODE_INDEX[chunk_in[1]] & 0b00110000) >> 4);

    if (chunk_in[2] != '=') {
        chunk_out[1] = (DECODE_INDEX[chunk_in[1]] << 4) | ((DECODE_INDEX[chunk_in[2]] & 0b00111100) >> 2);
        byte_count += 1;

        if (chunk_in[3] != '=') {
            chunk_out[2] = (DECODE_INDEX[chunk_in[2]] << 6) | (DECODE_INDEX[chunk_in[3]] & 0b00111111);
            byte_count += 1;
        }
    }

    return byte_count;
}

pub fn Cli(comptime is_encode: bool) type {
    const len_chunk_in = if (is_encode) 3 else 4;
    const len_chunk_out = if (is_encode) 4 else 3;

    return struct {
        chunk_in: [len_chunk_in]u8 = [_]u8{0} ** len_chunk_in,
        chunk_out: [len_chunk_out]u8 = [_]u8{0} ** len_chunk_out,

        const Self = @This();

        pub fn run(self: *Self) void {
            std.debug.print("is_encode={}", .{is_encode});
            const stderr = io.getStdErr();
            defer stderr.close();
            var bw_stderr = io.bufferedWriter(stderr.writer());
            const vt_writer_stderr = bw_stderr.writer();

            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            const args = std.process.argsAlloc(allocator) catch |e| {
                vt_writer_stderr.print("Error while reading command line arguments: {}", .{e}) catch {};
                return;
            };

            const input = fs.cwd().openFile(args[1], .{ .mode = fs.File.OpenMode.read_only }) catch |e| {
                vt_writer_stderr.print("Error while opening input file {s}. {}", .{ args[1], e }) catch {};
                return;
            };
            defer input.close();
            var br_input = io.bufferedReader(input.reader());
            const vt_reader_input = br_input.reader();

            const output = if (3 <= args.len) blk: {
                const f = fs.cwd().createFile(args[2], .{
                    .truncate = true,
                    .read = true,
                }) catch |e| {
                    vt_writer_stderr.print("Error while opening output file {s}. {}", .{ args[2], e }) catch {};
                    return;
                };
                break :blk f;
            } else io.getStdOut();
            defer output.close();

            var bw_output = io.bufferedWriter(output.writer());
            var vt_writer_output = bw_output.writer();

            while (true) {
                const bytes_read = vt_reader_input.readAll(&self.chunk_in) catch |e| {
                    vt_writer_stderr.print("Error while reading from input buffer for {s}. {}", .{ args[1], e }) catch {};
                    return;
                };
                if (bytes_read == 0) {
                    break;
                }

                if (is_encode) {
                    encode_chunk(bytes_read, &self.chunk_in, &self.chunk_out);
                    _ = vt_writer_output.writeAll(&self.chunk_out) catch |e| {
                        vt_writer_stderr.print("Error while writing to output buffer for {s}. {}", .{ args[1], e }) catch {};
                        return;
                    };
                } else {
                    const decoded_bytes = decode_chunk(&self.chunk_in, &self.chunk_out);
                    _ = vt_writer_output.writeAll(self.chunk_out[0..decoded_bytes]) catch |e| {
                        vt_writer_stderr.print("Error while writing to output buffer for {s}. {}", .{ args[1], e }) catch {};
                        return;
                    };
                }
            }

            bw_output.flush() catch |e| {
                vt_writer_stderr.print("Error while writing(flush) to output {s}. {}", .{ args[2], e }) catch {};
            };

            bw_stderr.flush() catch {};
        }
    };
}
