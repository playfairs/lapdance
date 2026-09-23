module lapdance.diagnostics;

import std.stdio : stderr, writeln;

struct Diagnostic
{
    string message;
    string path;
    int line = 0;
    int column = 0;
}

void emitError(string message, string path = "", int line = 0, int column = 0)
{
    if (path.length > 0)
    {
        stderr.writefln("error: %s (%s:%d:%d)", message, path, line, column);
        return;
    }
    stderr.writeln("error: ", message);
}
