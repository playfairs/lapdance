module lapdance.formatter;

import std.algorithm : canFind;
import std.exception : enforce;
import std.string : endsWith;

import lapdance.config;

abstract class LanguageFormatter
{
    abstract string name();
    abstract string[] extensions();

    bool accepts(string path, string source)
    {
        foreach (extension; extensions())
        {
            if (path.endsWith("." ~ extension))
                return true;
        }

        return source.canFind("import ") || source.canFind("module ");
    }

    string format(string source, FormattingConfig config)
    {
        return source;
    }
}

final class FormatterRegistry
{
    private LanguageFormatter[] formatters;

    bool acceptsPath(string path)
    {
        foreach (formatter; formatters)
        {
            if (formatter.accepts(path, ""))
                return true;
        }

        return false;
    }

    void register(LanguageFormatter formatter)
    {
        formatters ~= formatter;
    }

    LanguageFormatter resolve(string languageName)
    {
        foreach (formatter; formatters)
        {
            if (formatter.name() == languageName)
                return formatter;
        }

        enforce(false, "unsupported language: " ~ languageName);
        return null;
    }

    LanguageFormatter resolveByPath(string path, string source)
    {
        foreach (formatter; formatters)
        {
            if (formatter.accepts(path, source))
                return formatter;
        }

        enforce(false, "unsupported language: " ~ path);
        return null;
    }
}

