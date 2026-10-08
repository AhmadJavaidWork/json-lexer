const std = @import("std");
const Token = @import("token.zig");
const utils = @import("utils.zig");

input: []const u8,
ch: u8 = 0,
position: usize = 0,
read_position: usize = 0,

const Self = @This();

pub fn init(input: []const u8) Self {
    var l: Self = .{ .input = input };
    l.takeChar();
    return l;
}

pub fn nextToken(self: *Self) !Token {
    var token: Token = undefined;

    self.skipWhiteSpace();

    switch (self.ch) {
        0 => {
            token = .{
                .kind = Token.TokenKind.eof,
                .literal = "",
            };
        },
        '{' => {
            token = .{
                .kind = Token.TokenKind.left_brace,
                .literal = self.input[self.position..self.read_position],
            };
        },
        '}' => {
            token = .{
                .kind = Token.TokenKind.right_brace,
                .literal = self.input[self.position..self.read_position],
            };
        },
        '[' => {
            token = .{
                .kind = Token.TokenKind.left_bracket,
                .literal = self.input[self.position..self.read_position],
            };
        },
        ']' => {
            token = .{
                .kind = Token.TokenKind.right_bracket,
                .literal = self.input[self.position..self.read_position],
            };
        },
        ':' => {
            token = .{
                .kind = Token.TokenKind.colon,
                .literal = self.input[self.position..self.read_position],
            };
        },
        ',' => {
            token = .{
                .kind = Token.TokenKind.comma,
                .literal = self.input[self.position..self.read_position],
            };
        },
        '"' => {
            self.takeChar();
            const start: usize = self.position;
            self.takeString();
            token = .{
                .kind = Token.TokenKind.string,
                .literal = self.input[start..self.position],
            };
        },
        '-' => {
            if (utils.isNumber(self.peekChar())) {
                const start: usize = self.position;
                self.takeChar();
                try self.takeNumber();
                token = .{
                    .kind = Token.TokenKind.number,
                    .literal = self.input[start..self.read_position],
                };
            } else {
                return error.InvalidTokenAfterMinusSign;
            }
        },
        't' => {
            const start: usize = self.position;
            self.takeWord();
            if (std.mem.eql(u8, "true", self.input[start..self.read_position])) {
                token = .{
                    .kind = Token.TokenKind.bool_true,
                    .literal = self.input[start..self.read_position],
                };
            } else {
                return error.InvalidToken;
            }
        },
        'f' => {
            const start: usize = self.position;
            self.takeWord();
            if (std.mem.eql(u8, "false", self.input[start..self.read_position])) {
                token = .{
                    .kind = Token.TokenKind.bool_false,
                    .literal = self.input[start..self.read_position],
                };
            } else {
                return error.InvalidToken;
            }
        },
        else => {
            if (utils.isNumber(self.ch)) {
                const start: usize = self.position;
                try self.takeNumber();
                token = .{
                    .kind = Token.TokenKind.number,
                    .literal = self.input[start..self.read_position],
                };
            } else if (utils.isLetter(self.ch)) {
                const start: usize = self.position;
                self.takeWord();
                if (std.mem.eql(u8, "null", self.input[start..self.read_position])) {
                    token = .{
                        .kind = Token.TokenKind.null,
                        .literal = self.input[start..self.read_position],
                    };
                } else {
                    return error.InvalidToken;
                }
            } else {
                return error.InvalidToken;
            }
        },
    }

    self.takeChar();
    return token;
}

fn takeChar(self: *Self) void {
    if (self.read_position >= self.input.len) {
        self.ch = 0;
        self.position = self.read_position;
    } else {
        self.ch = self.input[self.read_position];
    }
    self.position = self.read_position;
    self.read_position += 1;
}

fn skipWhiteSpace(self: *Self) void {
    while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') {
        self.takeChar();
    }
}

fn peekChar(self: *Self) u8 {
    if (self.read_position >= self.input.len) {
        return 0;
    } else {
        return self.input[self.read_position];
    }
}

fn takeString(self: *Self) void {
    var is_escaped: bool = false;
    while (true) {
        if (self.ch == '\\' and self.peekChar() == '"') {
            is_escaped = !is_escaped;
            self.takeChar();
            self.takeChar();
            continue;
        } else if (self.ch == '"') {
            break;
        }
        self.takeChar();
    }
}

fn takeWord(self: *Self) void {
    while (self.peekChar() >= 'a' and self.peekChar() <= 'z') {
        self.takeChar();
    }
}

fn takeNumber(self: *Self) !void {
    while (self.peekChar() != ' ' and self.peekChar() != '\t' and self.peekChar() != '\r' and self.peekChar() != '\n' and self.peekChar() != ',') {
        self.takeChar();
    }
}

test "tokenize json" {
    const io = std.testing.io;
    const input = try std.Io.Dir.cwd().readFileAlloc(io, "test-data.json", std.testing.allocator, .unlimited);
    defer std.testing.allocator.free(input);
    var l = Self.init(input);

    const expected_tokens = [_]Token{
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "name" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "Lexer Test Dataset" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "version" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "1.2" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "enabled" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.bool_true, .literal = "true" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "description" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "A JSON document designed to test a lexer." },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "nullValue" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.null, .literal = "null" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "numbers" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "integer" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "42" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "negative" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "-17" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "decimal" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "3.14159" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "negativeDecimal" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "-0.125" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "exponent" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "6.022e23" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "negativeExponent" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "-1.5e-4" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "zero" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "0" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "strings" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "empty" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "spaces" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "hello world" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "quotes" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "She said \\\"hello\\\"." },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "backslash" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "C:\\\\Users\\\\Public\\\\Documents" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "newline" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "line one\\nline two" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "tab" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "column1\\tcolumn2" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "unicode" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "Hello, 世界! 🌍" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "escaped" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "\\\\\\\"\\/\\b\\f\\n\\r\\t" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "arrays" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.number, .literal = "1" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.number, .literal = "2" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.number, .literal = "3" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "four" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.bool_true, .literal = "true" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.bool_false, .literal = "false" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.null, .literal = "null" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "nested" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "object" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.string, .literal = "nested" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "array" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "users" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "id" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "1" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "name" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "Alice" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "active" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.bool_true, .literal = "true" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "roles" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.string, .literal = "admin" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "editor" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "id" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "2" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "name" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "Bob" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "active" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.bool_false, .literal = "false" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "roles" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.string, .literal = "viewer" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "metadata" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "created" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "2026-10-07T19:44:00Z" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "tags" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_bracket, .literal = "[" },
        .{ .kind = Token.TokenKind.string, .literal = "lexer" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "parser" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "json" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "testing" },
        .{ .kind = Token.TokenKind.right_bracket, .literal = "]" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "dimensions" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "width" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "1920" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "height" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "1080" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.right_brace, .literal = "}" },
        .{ .kind = Token.TokenKind.eof, .literal = "" },
    };

    var actual_token: Token = undefined;

    try std.testing.expectEqual(0, l.position);
    try std.testing.expectEqual(1, l.read_position);

    for (expected_tokens) |et| {
        actual_token = try l.nextToken();

        try std.testing.expectEqual(et.kind, actual_token.kind);
        try std.testing.expectEqualStrings(et.literal, actual_token.literal);
    }

    try std.testing.expect(l.position > l.input.len);
    try std.testing.expect(l.read_position > l.input.len);
    try std.testing.expectEqual(0, l.ch);
}
