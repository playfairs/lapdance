module lapdance.ast;

import lapdance.token;

enum NodeKind
{
    Program,
    Block,
    Statement,
    Declaration,
    Function,
    Struct,
    Class,
    Enum,
    Import,
    Comment,
    Unknown
}

struct SourceSpan
{
    int line = 1;
    int column = 1;
    size_t offset = 0;
}

class AstNode
{
    NodeKind kind;
    SourceSpan span;
    string text;

    this(NodeKind nodeKind, SourceSpan sourceSpan, string nodeText = "")
    {
        kind = nodeKind;
        span = sourceSpan;
        text = nodeText;
    }
}

class ProgramNode : AstNode
{
    AstNode[] children;

    this()
    {
        super(NodeKind.Program, SourceSpan());
    }
}

class BlockNode : AstNode
{
    AstNode[] children;

    this(SourceSpan sourceSpan)
    {
        super(NodeKind.Block, sourceSpan);
    }
}

class StatementNode : AstNode
{
    Token[] tokens;

    this(SourceSpan sourceSpan, Token[] statementTokens)
    {
        super(NodeKind.Statement, sourceSpan);
        tokens = statementTokens;
    }
}

