import std.algorithm.searching : canFind;

import std.file : readText;

import std.stdio;

import std.string : startsWith;

import lapdance.formatter;

import lapdance.config;

import lapdance.token;

import lapdance.parser;

void require(bool condition, string message)
{
    if (!condition)throw new Exception(message);
}

DFormatter makeFormatter()
{
    return new DFormatter();
}

void testLexer()
{
    auto lexer = new Lexer("/// docs\nint x = 1; // note\n/+ outer /+ inner +/ +/\nauto raw = `a { b }`; index++; index--;\n");
    auto tokens = lexer.lex();
    require(tokens[0].kind == TokenKind.Documentation, "documentation comment token missing");
    require(tokens[1].kind == TokenKind.Keyword, "type keyword token missing");
    bool foundNested;
    bool foundLineComment;
    bool foundIncrement;
    foreach (token; tokens)
    {
        if (token.kind == TokenKind.Comment && token.text.startsWith("/+"))foundNested = true;
        if (token.kind == TokenKind.Comment && token.text.startsWith("//"))foundLineComment = true;
        if (token.text == "++")foundIncrement = true;
    }
    require(foundNested, "nested comment token missing");
    require(foundLineComment, "line comment token missing");
    require(foundIncrement, "increment token missing");
}

void testFixture(string name)
{
    auto config = defaultFormattingConfig();
    auto input = readText("tests/fixtures/d/"~name~"/input.d");
    auto expected = readText("tests/fixtures/d/"~name~"/expected.d");
    auto actual = makeFormatter().format(input, config);
    require(actual == expected, name~" fixture mismatch");
    require(makeFormatter().format(actual, config) == actual, name~" fixture is not idempotent");
}

void testMalformedInputIsUnchanged()
{
    auto input = readText("tests/fixtures/d/malformed/input.d");
    require(makeFormatter().format(input, defaultFormattingConfig()) == input, "malformed input was modified");
}

void testSameLineBraces()
{
    auto config = defaultFormattingConfig();
    config.braceStyle = BraceStyle.SameLine;
    auto actual = makeFormatter().format("void main(){return;}", config);
    require(actual.canFind("void main() {"), "same-line brace style ignored");
}

int main()
{
    try
    {
        testLexer();
        foreach (name; ["modules", "imports", "declarations", "functions", "structs", "classes", "interfaces",
        "enums", "aliases", "templates", "attributes", "expressions", "statements", "control-flow", "comments",
        "strings", "multiline", "edge-cases"])testFixture(name);
        testMalformedInputIsUnchanged();
        testSameLineBraces();
        writeln("all tests passed");
        return 0;
    }
    catch (Exception ex)
    {
        stderr.writeln("test failure: ", ex.msg);
        return 1;
    }
}
