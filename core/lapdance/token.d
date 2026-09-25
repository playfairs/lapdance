module lapdance.token;

import std.algorithm : canFind;

import std.ascii : isDigit;

import std.string : startsWith;

import std.uni : isAlpha, isAlphaNum;

enum TokenKind
{
    Identifier, Keyword, Number, String, Character, Comment, Documentation, Operator, Punctuation, EOF
}

struct SourceLocation
{
    int line = 1;
    int column = 1;
    size_t offset = 0;
}

struct Token
{
    TokenKind kind;
    string text;
    SourceLocation location;

    bool isKeyword()const
    {
        return kind == TokenKind.Keyword;
    }
}

class Lexer
{
    private string source;
    private size_t index;
    private int line = 1;
    private int column = 1;

    this(string input)
    {
        source = input;
    }

    Token[]lex()
    {
        Token[]tokens;
        while (true)
        {
            auto token = nextToken();
            tokens~=token;
            if (token.kind == TokenKind.EOF)break;
        }
        return tokens;
    }

    private Token nextToken()
    {
        while (index < source.length)
        {
            char ch = source[index];
            if (ch == '\r' || ch == '\n')
            {
                consumeNewline();
                continue;
            }
            if (ch == ' ' || ch == '\t')
            {
                index++;
                column++;
                continue;
            }
            if (ch == '/' && index + 1 < source.length)
            {
                if (source[index + 1] == '/')return readLineComment();
                if (source[index + 1] == '*')return readBlockComment();
                if (source[index + 1] == '+')return readNestedComment();
            }
            if ((ch == 'q' || ch == 'r' || ch == 'x') && index + 1 < source.length && source[index + 1] == '"')return readPrefixedString();
            if (isAlpha(ch) || ch == '_')return readIdentifier();
            if (isDigit(ch))return readNumber();
            if (ch == '"' || ch == '\'' || ch == '`')return readStringLiteral();
            auto token = readOperatorOrPunctuation();
            if (token.kind != TokenKind.EOF)return token;
            index++;
            column++;
        }
        return Token(TokenKind.EOF, "", SourceLocation(line, column, index));
    }

    private void consumeNewline()
    {
        if (source[index] == '\r' && index + 1 < source.length && source[index + 1] == '\n')index++;
        index++;
        line++;
        column = 1;
    }

    private Token readIdentifier()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        while (index < source.length && (isAlphaNum(source[index]) || source[index] == '_'))
        {
            index++;
            column++;
        }
        auto text = source[start .. index];
        return Token(isKeyword(text) ? TokenKind.Keyword : TokenKind.Identifier, text, location);
    }

    private Token readNumber()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        bool exponent;
        while (index < source.length)
        {
            auto ch = source[index];
            if (isDigit(ch) || ch == '_' || ch == '.' || ch == 'x' || ch == 'X' || ch == 'b' || ch == 'B' || ch == 'e' || ch == 'E' || ch == '+' || ch == '-')
            {
                if (ch == 'e' || ch == 'E')exponent = true;
                index++;
                column++;
                continue;
            }
            break;
        }
        return Token(TokenKind.Number, source[start .. index], location);
    }

    private Token readStringLiteral()
    {
        auto quote = source[index];
        auto start = index;
        auto location = SourceLocation(line, column, index);
        index++;
        column++;
        bool escaped;
        while (index < source.length)
        {
            auto ch = source[index];
            if (quote == '`')
            {
                if (ch == '`')
                {
                    index++;
                    column++;
                    break;
                }
                if (ch == '\n' || ch == '\r')consumeNewline();
                else
                {
                    index++;
                    column++;
                }
                continue;
            }
            if (escaped)
            {
                escaped = false;
                index++;
                column++;
                continue;
            }
            if (ch == '\\')
            {
                escaped = true;
                index++;
                column++;
                continue;
            }
            if (ch == quote)
            {
                index++;
                column++;
                break;
            }
            if (ch == '\n' || ch == '\r')consumeNewline();
            else
            {
                index++;
                column++;
            }
        }
        return Token(quote == '\'' ? TokenKind.Character : TokenKind.String, source[start .. index],
        location);
    }

    private Token readPrefixedString()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        index+=2;
        column+=2;
        while (index < source.length)
        {
            auto ch = source[index];
            if (ch == '"')
            {
                index++;
                column++;
                break;
            }
            if (ch == '\n' || ch == '\r')consumeNewline();
            else
            {
                index++;
                column++;
            }
        }
        return Token(TokenKind.String, source[start .. index], location);
    }

    private Token readLineComment()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        index+=2;
        column+=2;
        while (index < source.length && source[index] != '\n' && source[index] != '\r')
        {
            index++;
            column++;
        }
        auto text = source[start .. index];
        return Token(text.startsWith("///") ? TokenKind.Documentation : TokenKind.Comment, text, location);
    }

    private Token readBlockComment()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        index+=2;
        column+=2;
        int depth = 1;
        while (index < source.length && depth > 0)
        {
            if (index + 1 < source.length && source[index .. index + 2] == "/*")
            {
                depth++;
                index+=2;
                column+=2;
            }
            else if (index + 1 < source.length && source[index .. index + 2] == "*/")
            {
                depth--;
                index+=2;
                column+=2;
            }
            else if (source[index] == '\n' || source[index] == '\r')consumeNewline();
            else
            {
                index++;
                column++;
            }
        }
        auto text = source[start .. index];
        return Token(text.startsWith("/**") ? TokenKind.Documentation : TokenKind.Comment, text, location);
    }

    private Token readNestedComment()
    {
        auto start = index;
        auto location = SourceLocation(line, column, index);
        index+=2;
        column+=2;
        int depth = 1;
        while (index < source.length && depth > 0)
        {
            if (index + 1 < source.length && source[index .. index + 2] == "/+")
            {
                depth++;
                index+=2;
                column+=2;
            }
            else if (index + 1 < source.length && source[index .. index + 2] == "+/")
            {
                depth--;
                index+=2;
                column+=2;
            }
            else if (source[index] == '\n' || source[index] == '\r')consumeNewline();
            else
            {
                index++;
                column++;
            }
        }
        return Token(TokenKind.Comment, source[start .. index], location);
    }

    private Token readOperatorOrPunctuation()
    {
        if (index >= source.length)return Token(TokenKind.EOF, "", SourceLocation(line, column, index));
        string two = index + 1 < source.length ? source[index .. index + 2] : "";
        string three = index + 2 < source.length ? source[index .. index + 3] : "";
        foreach (candidate; ["<<=", ">>=", "&&=", "||=", "^^=", "...", "==", "!=", "<=", ">=", "&&",
        "||", "<<", ">>", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "=>", "..", "->",
        "::", "^^", "~="])
        {
            if ((candidate.length == 3 && three == candidate) || (candidate.length == 2 && two == candidate))
            {
                auto token = Token(TokenKind.Operator, candidate, SourceLocation(line, column, index));
                index+=candidate.length;
                column+=cast(int)candidate.length;
                return token;
            }
        }
        if (source[index] == '(' || source[index] == ')' || source[index] == '{' || source[index] == '}' || source[index] == '[' || source[index] == ']' || source[index] == ';' || source[index] == ',' || source[index] == '.' || source[index] == ':')
        {
            auto text = source[index .. index + 1];
            auto token = Token(TokenKind.Punctuation, text, SourceLocation(line, column, index));
            index++;
            column++;
            return token;
        }
        foreach (candidate; ["=", "+", "-", "*", "/", "%", "!", "<", ">", "&", "|", "^", "~", "?", "@",
        "$", "#"])
        {
            if (source[index] == candidate[0])
            {
                auto token = Token(TokenKind.Operator, candidate, SourceLocation(line, column, index));
                index++;
                column++;
                return token;
            }
        }
        return Token(TokenKind.EOF, "", SourceLocation(line, column, index));
    }

    private static bool isKeyword(string text)
    {
        static immutable string[]keywords = ["abstract", "alias", "align", "asm", "assert", "auto", "body",
        "bool", "break", "case", "cast", "catch", "class", "const", "continue", "debug", "default", "delegate",
        "delete", "deprecated", "do", "double", "else", "enum", "export", "extern", "false", "final",
        "finally", "for", "foreach", "foreach_reverse", "function", "goto", "if", "immutable", "import",
        "in", "inout", "interface", "invariant", "is", "lazy", "long", "mixin", "module", "new", "nothrow",
        "null", "out", "override", "package", "pragma", "private", "protected", "public", "pure", "real",
        "ref", "return", "scope", "shared", "short", "static", "struct", "super", "switch", "synchronized",
        "template", "this", "throw", "true", "try", "typeof", "ubyte", "uint", "ulong", "union", "unittest",
        "ushort", "version", "void", "volatile", "wchar", "while", "with", "int", "float", "double",
        "string", "char", "byte", "short", "long", "bool", "dchar", "cent", "ucent"];
        return keywords.canFind(text);
    }
}
