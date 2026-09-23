import std.stdio;
import std.algorithm.searching : canFind;
import std.string : strip;

import formatter;
import lapdance.config;
import lapdance.token;

void require(bool condition, string message)
{
    if (!condition)
    {
        throw new Exception(message);
    }
}

void testLexerBasic()
{
    auto lexer = new Lexer("int x = 1; // hi\nimport std.stdio;\n");
    auto tokens = lexer.lex();

    require(tokens.length > 0, "lexer produced no tokens");
    require(tokens[0].kind == TokenKind.Keyword, "first token should be keyword");
    require(tokens[0].text == "int", "first token text mismatch");
    require(tokens[1].text == "x", "identifier token mismatch");
    require(tokens[2].text == "=", "assignment token mismatch");
    require(tokens[3].text == "1", "number token mismatch");
    require(tokens[4].kind == TokenKind.Punctuation, "semicolon should be punctuation");
    require(tokens[5].kind == TokenKind.Comment, "comment token should be preserved");
}

void testFormatterIdempotent()
{
    auto config = defaultFormattingConfig();
    auto formatter = new DFormatter();

    string dirty = "import std.stdio;void main(){int x=1;if(x>0){writeln(\"ok\");}}";
    string first = formatter.format(dirty, config);
    string second = formatter.format(first, config);

    require(first == second, "formatter is not idempotent");
    require(first.canFind("import std.stdio;"), "import line missing");
    require(first.canFind("void main()"), "main signature missing");
    require(first.canFind("if (x > 0)"), "if spacing missing");
    require(first.canFind("writeln(\"ok\")"), "call spacing missing");
}

void testFormatterRespectsStrings()
{
    auto config = defaultFormattingConfig();
    auto formatter = new DFormatter();

    string source = "auto s = \"if (a > b) { x(); }\";\nvoid main(){writeln(s);}";
    string formatted = formatter.format(source, config);

    require(formatted.canFind("\"if (a > b) { x(); }\""), "string literal was reformatted");
    require(formatted.canFind("void main()"), "main signature missing");
}

void testFormatterPreservesSlices()
{
    auto config = defaultFormattingConfig();
    auto formatter = new DFormatter();
    auto formatted = formatter.format("auto tail = args[1 .. $];", config);

    require(formatted.canFind("args[1 .. $]"), "slice expression was corrupted");
}

int main()
{
    try
    {
        testLexerBasic();
        testFormatterIdempotent();
        testFormatterRespectsStrings();
        testFormatterPreservesSlices();
        writeln("all tests passed");
        return 0;
    }
    catch (Exception ex)
    {
        stderr.writeln("test failure: ", ex.msg);
        return 1;
    }
}

