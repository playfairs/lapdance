module lapdance.document;

import std.array : appender;

import lapdance.config;

enum DocKind
{
    Text, Space, HardLine, SoftLine, Indent, Dedent, GroupStart, GroupEnd
}

struct DocPart
{
    DocKind kind;
    string text;
}

struct Document
{
    DocPart[]parts;

    void text(string value)
    {
        parts~=DocPart(DocKind.Text, value);
    }

    void space()
    {
        parts~=DocPart(DocKind.Space, "");
    }

    void line()
    {
        parts~=DocPart(DocKind.HardLine, "");
    }

    void softLine()
    {
        parts~=DocPart(DocKind.SoftLine, "");
    }

    void indent()
    {
        parts~=DocPart(DocKind.Indent, "");
    }

    void dedent()
    {
        parts~=DocPart(DocKind.Dedent, "");
    }

    void groupStart()
    {
        parts~=DocPart(DocKind.GroupStart, "");
    }

    void groupEnd()
    {
        parts~=DocPart(DocKind.GroupEnd, "");
    }

    string render(FormattingConfig config)
    {
        auto output = appender!string();
        int indentLevel;
        bool atLineStart = true;
        size_t column;
        int groupDepth;
        foreach (part; parts)
        {
            final switch (part.kind)
            {
                case DocKind.Text : if (atLineStart)
                {
                    output.put(indentText(indentLevel, config));
                    column = cast(size_t)indentLevel * indentWidth(config);
                    atLineStart = false;
                }

                output.put(part.text);
                column+=part.text.length;
                break;

                case DocKind.Space : if (!atLineStart && (output.data.length == 0 || output.data[$ - 1] != ' '))
                {
                    output.put(' ');
                    column++;
                }

                break;
                case DocKind.HardLine : output.put(config.newline);
                atLineStart = true;
                column = 0;
                break;

                case DocKind.SoftLine : if (groupDepth > 0 && column < cast(size_t)config.maxLineWidth)
                {
                    if (!atLineStart)
                    {
                        output.put(' ');
                        column++;
                    }
                }

                else
                {
                    output.put(config.newline);
                    atLineStart = true;
                    column = 0;
                }
                break;
                case DocKind.Indent : indentLevel++;
                break;
                case DocKind.Dedent : if (indentLevel > 0)indentLevel--;
                break;
                case DocKind.GroupStart : groupDepth++;
                break;
                case DocKind.GroupEnd : if (groupDepth > 0)groupDepth--;
                break;
            }
        }
        return output.data;
    }

    private static int indentWidth(FormattingConfig config)
    {
        return config.useTabs ? 1 : config.indentWidth;
    }

    private static string indentText(int level, FormattingConfig config)
    {
        string value;
        foreach (i; 0 .. level)
        {
            if (config.useTabs)value~="\t";
            else foreach (j; 0 .. config.indentWidth)value~=' ';
        }
        return value;
    }
}
