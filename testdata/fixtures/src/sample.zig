//! sample.zig — comprehensive Zig syntax fixture for parser testing.
//! Covers: structs, unions, enums, optionals, error handling, comptime,
//! generics, allocators, slices, arrays, tagged unions, defer, async (legacy),
//! type reflection, build options, inline assembly comment.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// -------------------------------------------------------------------------- //
// Constants & compile-time values
// -------------------------------------------------------------------------- //

const MAX_RETRIES: u32 = 3;
const DEFAULT_TIMEOUT_MS: u64 = 30_000;
const VERSION: []const u8 = "1.0.0";

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

const Status = enum {
    pending,
    running,
    done,
    failed,

    pub fn isTerminal(self: Status) bool {
        return self == .done or self == .failed;
    }

    pub fn label(self: Status) []const u8 {
        return switch (self) {
            .pending => "Waiting",
            .running => "In progress",
            .done    => "Completed",
            .failed  => "Failed",
        };
    }
};

// -------------------------------------------------------------------------- //
// Tagged union
// -------------------------------------------------------------------------- //

const Value = union(enum) {
    int:   i64,
    float: f64,
    bool:  bool,
    str:   []const u8,
    nil,

    pub fn format(
        self: Value,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .int   => |n| try writer.print("{d}", .{n}),
            .float => |f| try writer.print("{d}", .{f}),
            .bool  => |b| try writer.print("{}", .{b}),
            .str   => |s| try writer.print("{s}", .{s}),
            .nil   => try writer.writeAll("nil"),
        }
    }
};

// -------------------------------------------------------------------------- //
// Structs
// -------------------------------------------------------------------------- //

const Point = struct {
    x: f64,
    y: f64,

    pub const origin = Point{ .x = 0, .y = 0 };

    pub fn distanceTo(self: Point, other: Point) f64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }

    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

const User = struct {
    id:    []const u8,
    name:  []const u8,
    email: []const u8,
    role:  []const u8 = "member",

    pub const Error = error{
        NameEmpty,
        InvalidEmail,
    };

    pub fn validate(self: User) User.Error!void {
        if (self.name.len == 0) return error.NameEmpty;
        if (std.mem.indexOf(u8, self.email, "@") == null) return error.InvalidEmail;
    }
};

// -------------------------------------------------------------------------- //
// Error sets
// -------------------------------------------------------------------------- //

const AppError = error{
    NotFound,
    Validation,
    OutOfMemory,
    IoError,
};

// -------------------------------------------------------------------------- //
// Optionals
// -------------------------------------------------------------------------- //

fn findFirst(haystack: []const u8, needle: u8) ?usize {
    for (haystack, 0..) |byte, i| {
        if (byte == needle) return i;
    }
    return null;
}

fn getOrDefault(value: ?i32, default: i32) i32 {
    return value orelse default;
}

// -------------------------------------------------------------------------- //
// Generics via comptime
// -------------------------------------------------------------------------- //

fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(T),

        pub fn init(allocator: Allocator) Self {
            return .{ .items = std.ArrayList(T).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn push(self: *Self, item: T) !void {
            try self.items.append(item);
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.pop();
        }

        pub fn peek(self: Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[self.items.items.len - 1];
        }

        pub fn len(self: Self) usize {
            return self.items.items.len;
        }
    };
}

fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

fn sum(comptime T: type, items: []const T) T {
    var total: T = 0;
    for (items) |item| total += item;
    return total;
}

// -------------------------------------------------------------------------- //
// Comptime reflection
// -------------------------------------------------------------------------- //

fn printFields(comptime T: type) void {
    const info = @typeInfo(T);
    inline for (info.Struct.fields) |field| {
        std.debug.print("  field: {s} ({s})\n", .{ field.name, @typeName(field.type) });
    }
}

// -------------------------------------------------------------------------- //
// Slices & arrays
// -------------------------------------------------------------------------- //

fn reverseInPlace(comptime T: type, slice: []T) void {
    var lo: usize = 0;
    var hi: usize = slice.len;
    while (lo < hi) {
        hi -= 1;
        const tmp = slice[lo];
        slice[lo] = slice[hi];
        slice[hi] = tmp;
        lo += 1;
    }
}

fn copySlice(allocator: Allocator, src: []const u8) ![]u8 {
    const dst = try allocator.alloc(u8, src.len);
    @memcpy(dst, src);
    return dst;
}

// -------------------------------------------------------------------------- //
// defer
// -------------------------------------------------------------------------- //

fn withDefer(allocator: Allocator) !void {
    const buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);

    // Use buf here — freed automatically on scope exit
    _ = buf;
}

// -------------------------------------------------------------------------- //
// Recursion
// -------------------------------------------------------------------------- //

fn fibonacci(n: u32) u64 {
    return switch (n) {
        0 => 0,
        1 => 1,
        else => fibonacci(n - 1) + fibonacci(n - 2),
    };
}

fn factorial(n: u32) u64 {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// -------------------------------------------------------------------------- //
// Comptime conditional compilation
// -------------------------------------------------------------------------- //

const builtin = @import("builtin");

fn platformInfo() []const u8 {
    return switch (builtin.os.tag) {
        .linux   => "Linux",
        .macos   => "macOS",
        .windows => "Windows",
        else     => "Other",
    };
}

// -------------------------------------------------------------------------- //
// Iterator pattern
// -------------------------------------------------------------------------- //

const RangeIter = struct {
    current: i64,
    end: i64,
    step: i64,

    pub fn init(start: i64, end: i64, step: i64) RangeIter {
        return .{ .current = start, .end = end, .step = step };
    }

    pub fn next(self: *RangeIter) ?i64 {
        if (self.current >= self.end) return null;
        const val = self.current;
        self.current += self.step;
        return val;
    }
};

// -------------------------------------------------------------------------- //
// Error handling with try / catch
// -------------------------------------------------------------------------- //

fn safeDivide(a: i64, b: i64) AppError!i64 {
    if (b == 0) return error.Validation;
    return @divTrunc(a, b);
}

fn readFileSafe(allocator: Allocator, path: []const u8) AppError![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch return error.NotFound;
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024) catch error.OutOfMemory;
}

// -------------------------------------------------------------------------- //
// Main
// -------------------------------------------------------------------------- //

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Struct & optionals
    const user = User{ .id = "u1", .name = "Alice", .email = "alice@example.com" };
    try user.validate();
    std.debug.print("User: {s}\n", .{user.name});

    // Generic stack
    var stack = Stack(i32).init(allocator);
    defer stack.deinit();
    try stack.push(10);
    try stack.push(20);
    std.debug.print("Stack peek: {?d}\n", .{stack.peek()});

    // Fibonacci
    var fibs: [10]u64 = undefined;
    for (&fibs, 0..) |*f, i| f.* = fibonacci(@intCast(i));
    std.debug.print("Fibonacci: {any}\n", .{fibs});

    // Geometry
    const p1 = Point{ .x = 3.0, .y = 4.0 };
    std.debug.print("Distance: {d}\n", .{p1.distanceTo(Point.origin)});

    // Error handling
    const result = safeDivide(10, 0);
    if (result) |v| {
        std.debug.print("Result: {d}\n", .{v});
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }

    // Value tagged union
    const val = Value{ .str = "hello" };
    std.debug.print("Value: {}\n", .{val});

    // Platform
    std.debug.print("Platform: {s}\n", .{platformInfo()});

    // comptime reflection
    printFields(User);
}
