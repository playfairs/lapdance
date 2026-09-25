module lapdance.formatter;

import std.array : appender;
import std.string : stripRight;
import lapdance.config;
import lapdance.document;
import lapdance.token;
import lapdance.parser;

class DFormatter
{
    string format(string source, FormattingConfig config)
    {
        if (source.length == 0)
            return source;
        auto tokens = new Lexer(source).lex();
        auto parsed = new DParser(tokens).parse();
        if (!parsed.valid)
            return source;
        Document document;
        renderNodes(document, parsed.root.children, config, true);
        auto output = document.render(config).stripRight();
        if (config.preserveFinalNewline && output.length > 0)
            output ~= config.newline;
        return output;
    }

    private static void renderNodes(ref Document document, DNode[] nodes,
            FormattingConfig config, bool topLevel = false)
    {
        foreach (index, node; nodes)
        {
            renderNode(document, node, config);
            document.line();
            if (index + 1 < nodes.length && (topLevel || node.kind == DNodeKind.Aggregate
                    || node.kind == DNodeKind.Function || nodes[index + 1].kind == DNodeKind.Function
                    || nodes[index + 1].kind == DNodeKind.Aggregate))
                document.line();
        }
    }

    private static void renderNode(ref Document document, DNode node, FormattingConfig config)
    {
        if (node.kind == DNodeKind.Comment)
        {
            renderTokens(document, node.header, config);
            return;
        }
        if (node.kind == DNodeKind.Case)
        {
            renderTokens(document, node.header, config);
            document.line();
            if (node.hasBlock)
            {
                document.text("{");
                document.line();
                document.indent();
                renderNodes(document, node.children, config, false);
                document.dedent();
                document.text("}");
            }
            else
            {
                renderNodes(document, node.children, config, false);
            }
            return;
        }
        renderTokens(document, node.header, config);
        if (!node.hasBlock)
            return;
        if (config.braceStyle == BraceStyle.SameLine)
            document.space();
        else
            document.line();
        document.text("{");
        document.line();
        document.indent();
        renderNodes(document, node.children, config, false);
        document.dedent();
        document.text("}");
    }

    private static void renderTokens(ref Document document, Token[] tokens, FormattingConfig config)
    {
        document.groupStart();
        foreach (index, token; tokens)
        {
            if (token.kind == TokenKind.EOF)
                continue;
            if (token.text == ";")
            {
                document.text(";");
                if (insideParentheses(tokens, index))
                    document.space();
                continue;
            }
            if (token.text == ",")
            {
                document.text(",");
                document.softLine();
                continue;
            }
            if (token.text == ":")
            {
                document.space();
                document.text(":");
                document.space();
                continue;
            }
            if (needsSpaceBefore(tokens, index))
                document.space();
            document.text(token.text);
            if (needsSoftBreakAfter(tokens, index, document, config))
                document.softLine();
            else if (needsSpaceAfter(tokens, index))
                document.space();
        }
        document.groupEnd();
    }

    private static bool needsSpaceBefore(Token[] tokens, size_t index)
    {
        if (index == 0)
            return false;
        auto current = tokens[index];
        auto previous = tokens[index - 1];
        if (isClosing(current.text) || current.text == "."
                || current.text == "::" || current.text == "->"
                || current.text == "," || current.text == ";")
            return false;
        if (current.text == "(" || current.text == "[")
            return previous.kind == TokenKind.Keyword && isControlKeyword(previous.text);
        if (current.text == "++" || current.text == "--" || current.text == "!")
            return false;
        if (isWord(previous) && isWord(current))
            return true;
        if (isBinaryOperator(current.text))
            return true;
        if (isWord(previous) && current.text == "{")
            return true;
        return false;
    }

    private static bool needsSpaceAfter(Token[] tokens, size_t index)
    {
        if (index + 1 >= tokens.length)
            return false;
        auto current = tokens[index];
        auto next = tokens[index + 1];
        if (current.text == "(" || current.text == "[" || current.text == "."
                || current.text == "::" || current.text == "->" || current.text == "!")
            return false;
        if (current.text == "++" || current.text == "--")
            return false;
        if (current.text == "$" || next.text == "]")
            return false;
        if (isBinaryOperator(current.text))
            return true;
        if (isWord(current) && isWord(next))
            return true;
        return false;
    }

    private static bool needsSoftBreakAfter(Token[] tokens, size_t index,
            ref Document document, FormattingConfig config)
    {
        if (index + 1 >= tokens.length || config.maxLineWidth <= 0)
            return false;
        if (tokens[index].text != ",")
            return false;
        return true;
    }

    private static bool insideParentheses(Token[] tokens, size_t index)
    {
        int depth;
        foreach (position; 0 .. index)
        {
            if (tokens[position].text == "(")
                depth++;
            else if (tokens[position].text == ")" && depth > 0)
                depth--;
        }
        return depth > 0;
    }

    private static bool isWord(Token token)
    {
        return token.kind == TokenKind.Keyword || token.kind == TokenKind.Identifier
            || token.kind == TokenKind.Number || token.kind == TokenKind.String
            || token.kind == TokenKind.Character;
    }

    private static bool isClosing(string text)
    {
        return text == ")" || text == "]" || text == "}";
    }

    private static bool isBinaryOperator(string text)
    {
        return text == "=" || text == "+" || text == "-" || text == "*"
            || text == "/" || text == "%" || text == "==" || text == "!="
            || text == "<" || text == ">" || text == "<=" || text == ">="
            || text == "&&" || text == "||" || text == "&" || text == "|"
            || text == "^" || text == "?" || text == "=>" || text == "..";
    }

    private static bool isControlKeyword(string text)
    {
        return text == "if" || text == "for" || text == "foreach" || text == "while"
            || text == "switch" || text == "catch" || text == "with" || text == "synchronized";
    }
}
