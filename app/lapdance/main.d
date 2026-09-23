module lapdance.main;

import std.array : appender;
import std.algorithm : sort;
import std.file : dirEntries, exists, isDir, readText, SpanMode, write;
import std.stdio;
import std.string : splitLines, strip;

import lapdance.config;
import lapdance.formatter;
import lapdance.input;
import formatter;
import lapdance.language;

int main(string[] args)
{
    try
    {
        return runLapdance(args);
    }
    catch (Exception ex)
    {
        stderr.writeln("error: ", ex.msg);
        return 1;
    }
}

int runLapdance(string[] args)
{
    auto config = defaultFormattingConfig();
    auto registry = new FormatterRegistry();
    registry.register(new DFormatter());

    if (args.length <= 1)
    {
        printHelp();
        return 0;
    }

    string[] remaining = args[1 .. $];
    if (remaining[0] == "--help" || remaining[0] == "-h")
    {
        printHelp();
        return 0;
    }

    if (remaining[0] == "--version" || remaining[0] == "-v")
    {
        writeln("lapdance 0.1.0");
        return 0;
    }

    if (remaining[0] == "--stdin")
    {
        return formatStdin(config, registry);
    }

    string command = "format";
    if (remaining[0] == "format" || remaining[0] == "check" || remaining[0] == "diff")
    {
        command = remaining[0];
        remaining = remaining[1 .. $];
    }

    if (remaining.length == 0)
    {
        stderr.writeln("error: no input files provided");
        return 2;
    }

    remaining = expandInputPaths(remaining, registry);

    if (command == "check")
        return runCheckMode(remaining, config, registry);
    if (command == "diff")
        return runDiffMode(remaining, config, registry);
    return runFormatMode(remaining, config, registry);
}

string[] expandInputPaths(string[] paths, FormatterRegistry registry)
{
    string[] expanded;
    foreach (path; paths)
    {
        if (!exists(path) || !isDir(path))
        {
            expanded ~= path;
            continue;
        }

        foreach (entry; dirEntries(path, SpanMode.depth))
        {
            if (!entry.isDir && registry.acceptsPath(entry.name))
                expanded ~= entry.name;
        }
    }

    expanded.sort;
    return expanded;
}

void printHelp()
{
    writeln("Usage: lapdance [format|check|diff] <files...>");
    writeln("       lapdance --stdin");
    writeln("       lapdance --version");
    writeln("Commands:");
    writeln("  format     Format files in place");
    writeln("  check      Report files that need formatting");
    writeln("  diff       Show formatting differences");
    writeln("  --stdin    Read source from stdin");
    writeln("  --version  Show version information");
}

int formatStdin(FormattingConfig config, FormatterRegistry registry, bool diffMode = false, bool checkMode = false)
{
    string source;
    while (!stdin.eof())
    {
        source ~= stdin.readln();
    }

    if (source.length == 0)
        return 0;

    auto language = detectLanguage("stdin", source);
    auto formatter = registry.resolve(language.name);
    auto formatted = formatter.format(source, config);

    if (checkMode)
        return source == formatted ? 0 : 1;
    if (diffMode)
    {
        writeln("--- stdin");
        writeln("+++ stdin");
        writeln(diffText(source, formatted));
        return 0;
    }

    stdout.write(formatted);
    return 0;
}

int runFormatMode(string[] paths, FormattingConfig config, FormatterRegistry registry)
{
    int failures;
    foreach (path; paths)
    {
        if (!exists(path))
        {
            stderr.writeln("error: file not found: ", path);
            failures++;
            continue;
        }

        auto source = readText(path);
        auto language = detectLanguage(path, source);
        auto formatter = registry.resolve(language.name);
        auto formatted = formatter.format(source, config);
        if (source != formatted)
            write(path, formatted);
    }
    return failures > 0 ? 1 : 0;
}

int runCheckMode(string[] paths, FormattingConfig config, FormatterRegistry registry)
{
    int failures;
    foreach (path; paths)
    {
        if (!exists(path))
        {
            stderr.writeln("error: file not found: ", path);
            failures++;
            continue;
        }

        auto source = readText(path);
        auto language = detectLanguage(path, source);
        auto formatter = registry.resolve(language.name);
        auto formatted = formatter.format(source, config);
        if (source != formatted)
        {
            writeln(path, ": requires formatting");
            failures++;
        }
    }
    return failures > 0 ? 1 : 0;
}

int runDiffMode(string[] paths, FormattingConfig config, FormatterRegistry registry)
{
    int failures;
    foreach (path; paths)
    {
        if (!exists(path))
        {
            stderr.writeln("error: file not found: ", path);
            failures++;
            continue;
        }

        auto source = readText(path);
        auto language = detectLanguage(path, source);
        auto formatter = registry.resolve(language.name);
        auto formatted = formatter.format(source, config);
        if (source != formatted)
        {
            writeln("--- ", path);
            writeln("+++ ", path);
            writeln(diffText(source, formatted));
            failures++;
        }
    }
    return failures > 0 ? 1 : 0;
}

string diffText(string before, string after)
{
    auto result = appender!string();
    auto linesBefore = before.splitLines();
    auto linesAfter = after.splitLines();
    size_t maxLines = linesBefore.length > linesAfter.length ? linesBefore.length : linesAfter.length;

    foreach (idx; 0 .. maxLines)
    {
        if (idx >= linesBefore.length || idx >= linesAfter.length || linesBefore[idx] != linesAfter[idx])
        {
            result.put("- ");
            if (idx < linesBefore.length)
                result.put(linesBefore[idx]);
            result.put("\n+ ");
            if (idx < linesAfter.length)
                result.put(linesAfter[idx]);
            result.put("\n");
        }
    }

    return result.data;
}

