module lapdance.input;

import std.algorithm : canFind;
import std.path : extension;
import std.string : strip, toLower;

import lapdance.language;

LanguageDescriptor detectLanguage(string path, string source)
{
    string ext = extension(path).toLower();
    final switch (ext)
    {
        case ".d":
            return LanguageDescriptor("d", ["d"]);
        case ".c":
            return LanguageDescriptor("c", ["c"]);
        case ".h":
            return LanguageDescriptor("c", ["h"]);
        case ".cpp":
        case ".cc":
        case ".cxx":
            return LanguageDescriptor("cpp", ["cpp", "cc", "cxx"]);
        case ".rs":
            return LanguageDescriptor("rust", ["rs"]);
        case ".nix":
            return LanguageDescriptor("nix", ["nix"]);
        case ".py":
            return LanguageDescriptor("python", ["py"]);
        case ".js":
            return LanguageDescriptor("javascript", ["js"]);
        case ".ts":
            return LanguageDescriptor("typescript", ["ts"]);
        case ".noml":
            return LanguageDescriptor("noml", ["noml"]);
        case ".nox":
            return LanguageDescriptor("noxscript", ["nox"]);
        case "":
            break;
    }

    string normalized = source.strip;
    if (normalized.length > 0)
    {
        if (normalized.canFind("import ") || normalized.canFind("void main") || normalized.canFind("class "))
            return LanguageDescriptor("d", ["d"]);
    }

    return LanguageDescriptor("unknown", []);
}
