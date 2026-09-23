module lapdance.token;

import std.algorithm : canFind;
import std.ascii : isDigit;
import std.uni : isAlpha, isAlphaNum;

enum TokenKind
{
    Identifier,
    Keyword,
    Number,
    String,
    Character,
    Comment,
    Operator,
    Punctuation,
    EOF
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

    bool isKeyword() const
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

    Token[] lex()
    {
        Token[] tokens;
        while (true)
        {
            auto token = nextToken();
            tokens ~= token;
            if (token.kind == TokenKind.EOF)
                break;
        }
        return tokens;
    }

    private Token nextToken()
    {
        while (index < source.length)
        {
            char ch = source[index];

            if (ch == '\r')
            {
                index++;
                if (index < source.length && source[index] == '\n')
                    index++;
                line++;
                column = 1;
                continue;
            }

            if (ch == '\n')
            {
                index++;
                line++;
                column = 1;
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
                if (source[index + 1] == '/')
                    return readLineComment();
                if (source[index + 1] == '*')
                    return readBlockComment();
                if (source[index + 1] == '+')
                    return readNestedComment();
            }

            if (isAlpha(ch) || ch == '_')
                return readIdentifier();

            if (isDigit(ch))
                return readNumber();

            if (ch == '"' || ch == '\'')
                return readStringLiteral();

            auto opToken = readOperatorOrPunctuation();
            if (opToken.kind != TokenKind.EOF)
                return opToken;

            index++;
            column++;
        }

        return Token(TokenKind.EOF, "", SourceLocation(line, column, index));
    }

    private Token readIdentifier()
    {
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;

        while (index < source.length)
        {
            char ch = source[index];
            if (isAlphaNum(ch) || ch == '_')
            {
                index++;
                column++;
            }
            else
            {
                break;
            }
        }

        string text = source[start .. index];
        auto keyword = isKeyword(text);
        return Token(keyword ? TokenKind.Keyword : TokenKind.Identifier, text,
            SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readNumber()
    {
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;

        while (index < source.length)
        {
            char ch = source[index];
            if (isDigit(ch) || ch == '_' || ch == '.' || ch == 'e' || ch == 'E' || ch == 'x' || ch == 'X' || ch == 'b' || ch == 'B')
            {
                index++;
                column++;
            }
            else
            {
                break;
            }
        }

        return Token(TokenKind.Number, source[start .. index],
            SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readStringLiteral()
    {
        char quote = source[index];
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;
        index++;
        column++;

        bool escaped = false;
        while (index < source.length)
        {
            char ch = source[index];
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

            if (ch == '\n')
            {
                line++;
                column = 1;
            }
            else
            {
                column++;
            }
            index++;
        }

        return Token(quote == '\'' ? TokenKind.Character : TokenKind.String,
            source[start .. index], SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readLineComment()
    {
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;
        index += 2;
        column += 2;

        while (index < source.length && source[index] != '\n')
        {
            index++;
            column++;
        }

        return Token(TokenKind.Comment, source[start .. index],
            SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readBlockComment()
    {
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;
        index += 2;
        column += 2;
        int depth = 1;

        while (index + 1 < source.length)
        {
            if (source[index] == '/' && source[index + 1] == '*')
            {
                depth++;
                index += 2;
                column += 2;
                continue;
            }

            if (source[index] == '*' && index + 1 < source.length && source[index + 1] == '/')
            {
                depth--;
                index += 2;
                column += 2;
                if (depth == 0)
                    break;
                continue;
            }

            if (source[index] == '\n')
            {
                index++;
                line++;
                column = 1;
                continue;
            }

            index++;
            column++;
        }

        return Token(TokenKind.Comment, source[start .. index],
            SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readNestedComment()
    {
        auto start = index;
        auto startLine = line;
        auto startColumn = column;
        auto startOffset = index;
        index += 2;
        column += 2;
        int depth = 1;

        while (index + 1 < source.length)
        {
            if (source[index] == '/' && source[index + 1] == '+')
            {
                depth++;
                index += 2;
                column += 2;
                continue;
            }

            if (source[index] == '+' && source[index + 1] == '/')
            {
                depth--;
                index += 2;
                column += 2;
                if (depth == 0)
                    break;
                continue;
            }

            if (source[index] == '\n')
            {
                index++;
                line++;
                column = 1;
                continue;
            }

            index++;
            column++;
        }

        return Token(TokenKind.Comment, source[start .. index],
            SourceLocation(startLine, startColumn, startOffset));
    }

    private Token readOperatorOrPunctuation()
    {
        if (index >= source.length)
            return Token(TokenKind.EOF, "", SourceLocation(line, column, index));

        string twoChar = index + 1 < source.length ? source[index .. index + 2] : "";
        string threeChar = index + 2 < source.length ? source[index .. index + 3] : "";

        foreach (candidate; [
                "==", "!=", "<=", ">=", "&&", "||", "<<", ">>", "+=", "-=",
                "*=", "/=", "%=", "&=", "|=", "^=", "=>", "..", "...", "->",
                "::", "<<=", ">>=", "&&=", "||=", "^^=", "^^", "~="
            ])
        {
            if (candidate.length == 3 && threeChar == candidate)
            {
                auto result = Token(TokenKind.Operator, candidate, SourceLocation(line, column, index));
                index += 3;
                column += 3;
                return result;
            }
            if (candidate.length == 2 && twoChar == candidate)
            {
                auto result = Token(TokenKind.Operator, candidate, SourceLocation(line, column, index));
                index += 2;
                column += 2;
                return result;
            }
        }

        if (source[index] == '(' || source[index] == ')' || source[index] == '{' ||
            source[index] == '}' || source[index] == '[' || source[index] == ']' ||
            source[index] == ';' || source[index] == ',' || source[index] == ':' ||
            source[index] == '.')
        {
            auto ch = source[index];
            auto result = Token(TokenKind.Punctuation, [ch].idup, SourceLocation(line, column, index));
            index++;
            column++;
            return result;
        }

        foreach (candidate; ["=", "+", "-", "*", "/", "%", "!", "<", ">", "&", "|", "^", "~", "?", "@", "$"])
        {
            if (source[index] == candidate[0])
            {
                auto result = Token(TokenKind.Operator, candidate, SourceLocation(line, column, index));
                index++;
                column++;
                return result;
            }
        }

        return Token(TokenKind.EOF, "", SourceLocation(line, column, index));
    }

    private static bool isKeyword(string text)
    {
        static immutable string[] keywords = [
            "abstract", "alias", "align", "asm", "assert", "auto", "body", "bool",
            "break", "case", "cast", "catch", "class", "const", "continue", "debug",
            "default", "delegate", "delete", "deprecated", "do", "double", "else",
            "enum", "export", "extern", "false", "final", "finally", "for", "foreach",
            "foreach_reverse", "function", "goto", "if", "import", "in", "inout",
            "interface", "immutable", "int", "invariant", "is", "lazy", "long", "mixin",
            "module", "new", "nothrow", "null", "out", "override", "package", "pragma",
            "private", "protected", "public", "pure", "real", "ref", "return", "scope",
            "shared", "short", "static", "struct", "super", "switch", "synchronized",
            "template", "this", "throw", "true", "try", "typedef", "typeof", "ubyte",
            "ucent", "uint", "ulong", "union", "unittest", "ushort", "version", "void",
            "volatile", "wchar", "while", "with"
        ];
        return keywords.canFind(text);
    }
}

