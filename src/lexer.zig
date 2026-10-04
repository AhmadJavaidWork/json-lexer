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
        't' => {
            const start: usize = self.position;
            self.takeWord();
            token = .{
                .kind = Token.TokenKind.bool_true,
                .literal = self.input[start..self.read_position],
            };
        },
        'f' => {
            const start: usize = self.position;
            self.takeWord();
            token = .{
                .kind = Token.TokenKind.bool_false,
                .literal = self.input[start..self.read_position],
            };
        },
        else => {
            if (utils.isNumber(self.ch)) {
                const start: usize = self.position;
                try self.takeNumber();
                token = .{
                    .kind = Token.TokenKind.number,
                    .literal = self.input[start..self.read_position],
                };
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
    while (self.ch != '"') {
        self.takeChar();
    }
}

fn takeWord(self: *Self) void {
    while (self.peekChar() >= 'a' and self.peekChar() <= 'z') {
        self.takeChar();
    }
}

fn takeNumber(self: *Self) !void {
    var isDecimal: bool = false;
    while (utils.isNumber(self.peekChar()) or (self.peekChar() == '.' and isDecimal == false)) {
        if (self.peekChar() == '.') {
            isDecimal = true;
        }
        self.takeChar();
    }
    if (self.peekChar() == '.' and isDecimal == true) {
        return error.InvalidNumber;
    }
}

test "tokenize json" {
    var l = Self.init(
        \\{
        \\    "key1": "value1",
        \\    "key2": "value2",
        \\    "key3": true,
        \\    "key4": false,
        \\    "key5": 1234,
        \\    "key6": 12.25
        \\}
    );

    const expected_tokens = [_]Token{
        .{ .kind = Token.TokenKind.left_brace, .literal = "{" },
        .{ .kind = Token.TokenKind.string, .literal = "key1" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "value1" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "key2" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.string, .literal = "value2" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "key3" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.bool_true, .literal = "true" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "key4" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.bool_false, .literal = "false" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "key5" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "1234" },
        .{ .kind = Token.TokenKind.comma, .literal = "," },
        .{ .kind = Token.TokenKind.string, .literal = "key6" },
        .{ .kind = Token.TokenKind.colon, .literal = ":" },
        .{ .kind = Token.TokenKind.number, .literal = "12.25" },
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
