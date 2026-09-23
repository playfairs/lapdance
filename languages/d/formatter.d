module formatter;

import std.algorithm.searching : canFind;
import std.array : appender;
import std.string : endsWith, startsWith, strip, stripRight;

import lapdance.config;
import lapdance.formatter;
import lapdance.token;

class DFormatter : LanguageFormatter
{
    override string name()
    {
        return "d";
    }

    override string[] extensions()
    {
        return ["d"];
    }

    override bool accepts(string path, string source)
    {
        if (path.endsWith(".d"))
            return true;
        return source.canFind("import ") || source.canFind("module ") || source.canFind("void main");
    }

    override string format(string source, FormattingConfig config)
    {
        if (source.length == 0)
            return source;

        auto lexer = new Lexer(source);
        auto tokens = lexer.lex();
        return formatTokens(tokens, config);
    }

    private static string formatTokens(Token[] tokens, FormattingConfig config)
    {
        auto result = appender!string();
        int indentLevel = 0;
        bool lineStart = true;
        bool pendingCommentLine = false;
        bool lastTokenWasKeyword = false;

        foreach (idx, ref token; tokens)
        {
            if (token.kind == TokenKind.EOF)
                break;

            if (token.kind == TokenKind.Comment)
            {
                if (lineStart)
                    result.put(indentString(indentLevel, config));
                result.put(token.text);
                if (token.text.startsWith("//") || token.text.startsWith("///"))
                {
                    result.put('\n');
                    lineStart = true;
                    pendingCommentLine = true;
                }
                else
                {
                    pendingCommentLine = false;
                }
                continue;
            }

            if (lineStart)
            {
                result.put(indentString(indentLevel, config));
                lineStart = false;
            }

            if (token.text == "{")
            {
                if (idx > 0 && tokens[idx - 1].kind != TokenKind.EOF &&
                    tokens[idx - 1].kind != TokenKind.Punctuation &&
                    tokens[idx - 1].text != "{" &&
                    tokens[idx - 1].text != "(")
                {
                    result.put(' ');
                }
                result.put('{');
                indentLevel++;
                if (idx + 1 < tokens.length && tokens[idx + 1].kind != TokenKind.EOF &&
                    tokens[idx + 1].text != "}" && tokens[idx + 1].kind != TokenKind.Comment)
                {
                    result.put('\n');
                    lineStart = true;
                }
                lastTokenWasKeyword = false;
                continue;
            }

            if (token.text == "}")
            {
                if (indentLevel > 0)
                    indentLevel--;
                if (result.data.length > 0 && result.data[$ - 1] != '\n')
                    result.put('\n');
                result.put(indentString(indentLevel, config));
                result.put('}');
                if (idx + 1 < tokens.length && tokens[idx + 1].kind != TokenKind.EOF &&
                    tokens[idx + 1].text != ";" && tokens[idx + 1].text != "}" &&
                    tokens[idx + 1].kind != TokenKind.Comment)
                {
                    result.put('\n');
                    lineStart = true;
                }
                else
                {
                    lineStart = false;
                }
                lastTokenWasKeyword = false;
                continue;
            }

            if (token.text == ";")
            {
                result.put(';');
                result.put('\n');
                lineStart = true;
                pendingCommentLine = false;
                lastTokenWasKeyword = false;
                continue;
            }

            if (token.text == ",")
            {
                result.put(',');
                result.put(' ');
                lastTokenWasKeyword = false;
                continue;
            }

            if (token.text == ":")
            {
                result.put(": ");
                lastTokenWasKeyword = false;
                continue;
            }

            if (needsWhitespaceBefore(tokens, idx, token))
                result.put(' ');

            result.put(token.text);

            if (needsWhitespaceAfter(tokens, idx, token))
                result.put(' ');

            lastTokenWasKeyword = token.kind == TokenKind.Keyword;
        }

        string output = result.data.stripRight();
        if (output.length > 0 && output[$ - 1] != '\n')
            output ~= config.newline;
        else if (output.length == 0 && config.preserveFinalNewline)
            output = "";
        return output;
    }

    private static bool needsWhitespaceBefore(Token[] tokens, size_t index, Token token)
    {
        if (index == 0)
            return false;

        bool isWordLike(TokenKind kind)
        {
            return kind == TokenKind.Keyword || kind == TokenKind.Identifier ||
                kind == TokenKind.Number || kind == TokenKind.String ||
                kind == TokenKind.Character;
        }

        Token prev = tokens[index - 1];
        if (prev.kind == TokenKind.EOF)
            return false;
        if (isWordLike(prev.kind) && isWordLike(token.kind))
            return false;
        if (token.kind == TokenKind.Punctuation)
        {
            if (token.text == "." || token.text == "," || token.text == ";" ||
                token.text == ")" || token.text == "]" || token.text == "}")
                return false;
            if (token.text == "(" || token.text == "[")
                return false;
            return false;
        }

        if (token.kind == TokenKind.Operator)
        {
            if (token.text == "." || token.text == "->" || token.text == "::" || token.text == "++" ||
                token.text == "--" || token.text == "!" || token.text == "~")
                return false;
            return false;
        }

        if (prev.kind == TokenKind.Keyword || prev.kind == TokenKind.Identifier ||
            prev.kind == TokenKind.Number || prev.kind == TokenKind.String || prev.kind == TokenKind.Character)
        {
            if (token.kind == TokenKind.Keyword || token.kind == TokenKind.Identifier ||
                token.kind == TokenKind.Number || token.kind == TokenKind.String ||
                token.kind == TokenKind.Character)
                return true;
        }

        if (prev.text == ")" || prev.text == "]" || prev.text == "}")
            return token.kind == TokenKind.Identifier || token.kind == TokenKind.Keyword ||
                token.kind == TokenKind.Number || token.kind == TokenKind.String ||
                token.kind == TokenKind.Character || token.text == "(";

        return false;
    }

    private static bool needsWhitespaceAfter(Token[] tokens, size_t index, Token token)
    {
        if (index + 1 >= tokens.length)
            return false;

        Token next = tokens[index + 1];
        if (next.kind == TokenKind.EOF)
            return false;

        bool isWordLike(TokenKind kind)
        {
            return kind == TokenKind.Keyword || kind == TokenKind.Identifier ||
                kind == TokenKind.Number || kind == TokenKind.String ||
                kind == TokenKind.Character;
        }

        if (isWordLike(token.kind) && isWordLike(next.kind))
            return true;

        if (token.kind == TokenKind.Keyword && next.kind == TokenKind.Punctuation && next.text == "(")
            return token.text == "if" || token.text == "for" || token.text == "foreach" || token.text == "while" ||
                token.text == "switch" || token.text == "catch" || token.text == "return" || token.text == "throw" ||
                token.text == "new" || token.text == "delete" || token.text == "assert" || token.text == "cast" ||
                token.text == "typeof" || token.text == "sizeof" || token.text == "alignof" || token.text == "mixin" ||
                token.text == "with";

        if (token.kind == TokenKind.Identifier && next.kind == TokenKind.Punctuation && next.text == "(")
            return false;

        if (token.kind == TokenKind.Punctuation)
        {
            if (token.text == ";" || token.text == "," || token.text == "." ||
                token.text == ")" || token.text == "]" || token.text == "}")
                return false;
            if (token.text == "(" || token.text == "[")
                return false;
            if (token.text == "{")
                return false;
            return false;
        }

        if (token.kind == TokenKind.Operator)
        {
            if (token.text == "." || token.text == "->" || token.text == "::" ||
                token.text == "++" || token.text == "--" || token.text == "!" ||
                token.text == "~" || token.text == "$" || token.text == "=" || token.text == "?" ||
                token.text == ":")
                return token.text == "=" || token.text == "?" || token.text == ":";
            return true;
        }

        if (next.kind == TokenKind.Operator)
        {
            if (next.text == "." || next.text == "->" || next.text == "::" || next.text == "++" ||
                next.text == "--")
                return false;
            return true;
        }

        if (next.kind == TokenKind.Punctuation && next.text == ")")
            return false;

        if (next.kind == TokenKind.Punctuation && next.text == ";")
            return false;

        if (next.kind == TokenKind.Punctuation && next.text == ",")
            return false;

        if (next.kind == TokenKind.Identifier || next.kind == TokenKind.Keyword ||
            next.kind == TokenKind.Number || next.kind == TokenKind.String || next.kind == TokenKind.Character)
        {
            if (token.kind == TokenKind.Identifier || token.kind == TokenKind.Keyword ||
                token.kind == TokenKind.Number || token.kind == TokenKind.String ||
                token.kind == TokenKind.Character || token.kind == TokenKind.Operator)
                return true;
        }

        return false;
    }

    private static string indentString(int level, FormattingConfig config)
    {
        string output;
        foreach (i; 0 .. level)
        {
            if (config.useTabs)
            {
                output ~= "\t";
            }
            else
            {
                foreach (j; 0 .. config.indentWidth)
                    output ~= ' ';
            }
        }
        return output;
    }
}

