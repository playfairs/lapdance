module lapdance.config;

struct FormattingConfig
{
    int indentWidth = 4;
    bool useTabs = false;
    int maxLineWidth = 100;
    string newline = "\n";
    bool trailingComma = false;
    bool preserveFinalNewline = true;
}

FormattingConfig defaultFormattingConfig()
{
    return FormattingConfig();
}
