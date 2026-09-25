module lapdance.parser;

import std.algorithm.searching : canFind;

import std.string : startsWith;

import lapdance.token;

enum DNodeKind
{
    Program,
    Comment,
    Import,
    Module,
    Declaration,
    Function,
    Aggregate,
    Control,
    Switch,
    Case,
    Statement,
    Unknown
}

class DNode
{
    DNodeKind kind;
    Token[] header;
    DNode[] children;
    bool hasBlock;

    this(DNodeKind nodeKind, Token[] nodeHeader = [], bool block = false)
    {
        kind = nodeKind;
        header = nodeHeader;
        hasBlock = block;
    }
}

struct ParseResult
{
    DNode root;
    bool valid;
}

class DParser
{
    private Token[] tokens;
    private size_t index;
    private bool valid = true;

    this(Token[] input)
    {
        tokens = input;
    }

    ParseResult parse()
    {
        auto root = new DNode(DNodeKind.Program);
        root.children = parseSequence(false);
        if (current().kind != TokenKind.EOF)
            valid = false;
        return ParseResult(root, valid);
    }

    private DNode[] parseSequence(bool stopAtBrace)
    {
        DNode[] nodes;
        while (current().kind != TokenKind.EOF)
        {
            if (current().text == "}")
            {
                if (!stopAtBrace)
                    valid = false;
                index++;
                return nodes;
            }
            if (current().kind == TokenKind.Comment || current().kind == TokenKind.Documentation)
            {
                nodes ~= new DNode(DNodeKind.Comment, [current()]);
                index++;
                continue;
            }
            auto node = parseItem();
            if (node !is null)
                nodes ~= node;
            else if (current().kind != TokenKind.EOF)
                index++;
        }
        if (stopAtBrace)
            valid = false;
        return nodes;
    }

    private DNode parseItem()
    {
        size_t start = index;
        int parenDepth;
        int bracketDepth;
        int braceDepth;
        while (current().kind != TokenKind.EOF)
        {
            auto token = current();
            if (token.text == "(")
                parenDepth++;
            else if (token.text == ")")
                parenDepth--;
            else if (token.text == "[")
                bracketDepth++;
            else if (token.text == "]")
                bracketDepth--;
            if (parenDepth < 0 || bracketDepth < 0)
            {
                valid = false;
                return makeLeaf(start, index + 1);
            }
            if (token.text == "{" && parenDepth == 0 && bracketDepth == 0)
            {
                auto header = tokens[start .. index];
                if (looksLikeBlock(header))
                {
                    index++;
                    auto node = new DNode(classify(header), header, true);
                    node.children = parseSequence(true);
                    return node;
                }
                braceDepth++;
            }
            else if (token.text == "}" && parenDepth == 0 && bracketDepth == 0)
            {
                if (braceDepth > 0)
                    braceDepth--;
                else
                {
                    if (start < index)
                        return makeLeaf(start, index);
                    break;
                }
            }
            if (token.text == ";" && parenDepth == 0 && bracketDepth == 0 && braceDepth == 0)
            {
                index++;
                return makeLeaf(start, index);
            }
            index++;
        }
        if (start == index)
            return null;
        valid = false;
        return makeLeaf(start, index);
    }

    private DNode makeLeaf(size_t start, size_t end)
    {
        auto header = tokens[start .. end];
        return new DNode(classify(header), header, false);
    }

    private static DNodeKind classify(Token[] header)
    {
        if (header.length == 0)
            return DNodeKind.Unknown;
        auto first = header[0].text;
        if (first == "module")
            return DNodeKind.Module;
        if (first == "import")
            return DNodeKind.Import;
        if (first == "struct" || first == "class" || first == "interface"
                || first == "union" || first == "enum")
            return DNodeKind.Aggregate;
        if (first == "switch")
            return DNodeKind.Switch;
        if (first == "case" || first == "default")
            return DNodeKind.Case;
        if (first == "if" || first == "else" || first == "while" || first == "do"
                || first == "for" || first == "foreach" || first == "try" || first == "catch"
                || first == "finally" || first == "scope" || first == "with"
                || first == "synchronized" || first == "unittest")
            return DNodeKind.Control;
        if (header[$ - 1].text == ";")
            return DNodeKind.Statement;
        foreach (token; header)
        {
            if (token.text == "(")
                return DNodeKind.Function;
        }
        if (first == "return" || first == "throw" || first == "break" || first == "continue")
            return DNodeKind.Statement;
        return DNodeKind.Declaration;
    }

    private static bool looksLikeBlock(Token[] header)
    {
        if (header.length == 0)
            return false;
        auto first = header[0].text;
        if (first == "if" || first == "else" || first == "while" || first == "do"
                || first == "for" || first == "foreach" || first == "switch" || first == "try" || first == "catch"
                || first == "finally" || first == "scope" || first == "with"
                || first == "synchronized" || first == "unittest"
                || first == "struct" || first == "class" || first == "interface"
                || first == "union" || first == "enum" || first == "template")
            return true;
        foreach (token; header)
        {
            if (token.text == ")")
                return true;
            if (token.text == "=")
                return false;
        }
        return false;
    }

    private Token current()
    {
        return index < tokens.length ? tokens[index] : Token(TokenKind.EOF, "");
    }
}
