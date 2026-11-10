#include "highlighter.h"

#include "theme.h"

static QRegularExpression rx(const QString &pattern) {
    return QRegularExpression(pattern);
}

static QString words(const QStringList &list) {
    return "\\b(?:" + list.join('|') + ")\\b";
}

Highlighter::Highlighter(const QString &language, Theme *theme, QTextDocument *document)
    : QSyntaxHighlighter(document), m_grammar(grammarFor(language)), m_theme(theme) {
    refreshColors();
    connect(theme, &Theme::changed, this, [this] {
        refreshColors();
        rehighlight();
    });
}

void Highlighter::refreshColors() {
    m_formats.clear();
    for (const auto &role : {"keyword", "string", "number", "comment", "function", "type", "tag", "attribute",
                             "constant", "heading", "preprocessor", "operator", "emphasis", "strong"}) {
        QTextCharFormat format;
        const QString r(role);
        if (r == "emphasis") {
            format.setFontItalic(true);
        } else if (r == "strong") {
            format.setFontWeight(QFont::Bold);
        } else {
            format.setForeground(m_theme->syntax(r));
        }
        if (r == "comment")
            format.setFontItalic(true);
        if (r == "heading")
            format.setFontWeight(QFont::Bold);
        m_formats.insert(r, format);
    }
}

Highlighter::Grammar Highlighter::grammarFor(const QString &language) {
    Grammar g;
    const QString doubleString = R"("(?:[^"\\]|\\.)*")";
    const QString singleString = R"('(?:[^'\\]|\\.)*')";
    const QString number = R"(\b(?:0x[0-9A-Fa-f_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)[fFuUlL]*\b)";
    const QString call = R"(\b([A-Za-z_]\w*)\s*(?=\())";
    const QString type = R"(\b[A-Z][A-Za-z0-9_]*\b)";
    auto cLike = [&](const QStringList &keywords, const QStringList &constants = {"true", "false", "null"}) {
        g.rules << Rule{rx(type), "type"} << Rule{rx(call), "function", 1} << Rule{rx(words(keywords)), "keyword"}
                << Rule{rx(words(constants)), "constant"} << Rule{rx(number), "number"}
                << Rule{rx(doubleString), "string"} << Rule{rx(singleString), "string"}
                << Rule{rx(R"(//.*$)"), "comment"};
        g.blocks << Block{rx(R"(/\*)"), rx(R"(\*/)"), "comment"};
    };

    if (language == "cpp" || language == "c") {
        cLike({"auto", "break", "case", "catch", "class", "const", "constexpr", "continue", "default", "delete",
               "do", "else", "enum", "explicit", "extern", "for", "friend", "goto", "if", "inline", "namespace",
               "new", "noexcept", "operator", "override", "private", "protected", "public", "return", "sizeof",
               "static", "static_cast", "struct", "switch", "template", "this", "throw", "try", "typedef",
               "typename", "union", "using", "virtual", "volatile", "while", "void", "int", "char", "bool",
               "float", "double", "long", "short", "unsigned", "signed", "emit", "signals", "slots", "Q_OBJECT",
               "Q_PROPERTY", "Q_INVOKABLE", "co_await", "co_return", "final"},
              {"true", "false", "nullptr", "NULL"});
        g.rules << Rule{rx(R"(^\s*#\s*\w+.*$)"), "preprocessor"} << Rule{rx(R"(//.*$)"), "comment"};
    } else if (language == "javascript" || language == "typescript" || language == "qml" || language == "java" ||
               language == "kotlin" || language == "go" || language == "rust" || language == "dart" ||
               language == "csharp" || language == "swift") {
        cLike({"abstract", "as", "async", "await", "break", "case", "catch", "class", "const", "continue",
               "default", "delete", "do", "else", "enum", "export", "extends", "finally", "for", "from", "function",
               "if", "implements", "import", "in", "instanceof", "interface", "let", "new", "of", "private",
               "protected", "public", "readonly", "return", "static", "super", "switch", "this", "throw", "try",
               "type", "typeof", "var", "void", "while", "yield", "property", "signal", "required", "alias",
               "readonly", "component", "fn", "impl", "mut", "pub", "struct", "trait", "use", "mod", "match",
               "loop", "move", "ref", "self", "Self", "where", "func", "package", "go", "defer", "chan", "map",
               "range", "select", "val", "fun", "when", "override", "final", "late", "required", "extension"},
              {"true", "false", "null", "undefined", "nil", "None", "NaN", "Infinity"});
        if (language == "javascript" || language == "typescript")
            g.rules << Rule{rx(R"(`(?:[^`\\]|\\.)*`)"), "string"} << Rule{rx(R"(//.*$)"), "comment"};
        if (language == "rust")
            g.rules << Rule{rx(R"(\b\w+!)"), "preprocessor"} << Rule{rx(R"(//.*$)"), "comment"};
    } else if (language == "python") {
        g.rules << Rule{rx(type), "type"} << Rule{rx(call), "function", 1}
                << Rule{rx(words({"and", "as", "assert", "async", "await", "break", "class", "continue", "def",
                                  "del", "elif", "else", "except", "finally", "for", "from", "global", "if",
                                  "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                                  "return", "try", "while", "with", "yield", "match", "case", "self"})),
                        "keyword"}
                << Rule{rx(words({"True", "False", "None"})), "constant"} << Rule{rx(number), "number"}
                << Rule{rx(R"(^\s*@[\w.]+)"), "preprocessor"} << Rule{rx(doubleString), "string"}
                << Rule{rx(singleString), "string"} << Rule{rx(R"(#.*$)"), "comment"};
        g.blocks << Block{rx(R"(""")"), rx(R"(""")"), "string"} << Block{rx("'''"), rx("'''"), "string"};
    } else if (language == "shell") {
        g.rules << Rule{rx(words({"if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
                                  "case", "esac", "in", "function", "return", "local", "export", "set", "unset",
                                  "exit", "source", "readonly", "shift", "echo", "cd", "exec"})),
                        "keyword"}
                << Rule{rx(R"(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|\$[0-9@#?*!$-])"), "attribute"}
                << Rule{rx(number), "number"} << Rule{rx(doubleString), "string"} << Rule{rx(singleString), "string"}
                << Rule{rx(R"((?:^|\s)#.*$)"), "comment"};
    } else if (language == "html" || language == "xml") {
        g.rules << Rule{rx(R"(</?[A-Za-z][\w:-]*)"), "tag"} << Rule{rx(R"(/?>)"), "tag"}
                << Rule{rx(R"(\s([A-Za-z_:][\w:.-]*)(?==))"), "attribute", 1} << Rule{rx(doubleString), "string"}
                << Rule{rx(singleString), "string"} << Rule{rx(R"(&\w+;)"), "constant"};
        g.blocks << Block{rx("<!--"), rx("-->"), "comment"};
    } else if (language == "css") {
        g.rules << Rule{rx(R"([.#]?[A-Za-z_-][\w-]*(?=[^{}]*\{))"), "tag"}
                << Rule{rx(R"(([A-Za-z-]+)\s*(?=:))"), "attribute", 1}
                << Rule{rx(R"(#[0-9A-Fa-f]{3,8}\b)"), "constant"}
                << Rule{rx(R"(-?\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|s|ms|deg|fr)?\b)"), "number"}
                << Rule{rx(R"(@[\w-]+)"), "keyword"} << Rule{rx(R"(!important)"), "keyword"}
                << Rule{rx(doubleString), "string"} << Rule{rx(singleString), "string"};
        g.blocks << Block{rx(R"(/\*)"), rx(R"(\*/)"), "comment"};
    } else if (language == "json") {
        g.rules << Rule{rx(doubleString), "string"} << Rule{rx(R"(("(?:[^"\\]|\\.)*")\s*:)"), "attribute", 1}
                << Rule{rx(number), "number"} << Rule{rx(words({"true", "false", "null"})), "constant"};
    } else if (language == "markdown") {
        g.rules << Rule{rx(R"(^#{1,6}\s.*$)"), "heading"} << Rule{rx(R"(\*\*[^*]+\*\*|__[^_]+__)"), "strong"}
                << Rule{rx(R"((?<!\*)\*[^*\s][^*]*\*(?!\*))"), "emphasis"} << Rule{rx(R"(`[^`]+`)"), "string"}
                << Rule{rx(R"(\[[^\]]+\]\([^)]+\))"), "function"} << Rule{rx(R"(^\s*(?:[-*+]|\d+\.)\s)"), "keyword"}
                << Rule{rx(R"(^>.*$)"), "comment"};
        g.blocks << Block{rx("^```"), rx("^```"), "string"};
    } else if (language == "yaml" || language == "toml" || language == "ini") {
        g.rules << Rule{rx(R"(^\s*\[.*\]\s*$)"), "heading"} << Rule{rx(R"(^\s*([\w.-]+)\s*(?=[:=]))"), "attribute", 1}
                << Rule{rx(number), "number"} << Rule{rx(words({"true", "false", "null", "yes", "no"})), "constant"}
                << Rule{rx(doubleString), "string"} << Rule{rx(singleString), "string"}
                << Rule{rx(R"((?:^|\s)[#;].*$)"), "comment"};
    }
    return g;
}

void Highlighter::highlightBlock(const QString &text) {
    for (const auto &rule : m_grammar.rules) {
        auto it = rule.pattern.globalMatch(text);
        while (it.hasNext()) {
            const auto m = it.next();
            if (m.capturedLength(rule.group) > 0)
                setFormat(int(m.capturedStart(rule.group)), int(m.capturedLength(rule.group)), m_formats.value(rule.role));
        }
    }

    // Multi-line regions (block comments, triple-quoted strings): a block
    // state of n + 1 means the line ends inside region n.
    setCurrentBlockState(0);
    auto findStart = [&](int from, int *region, int *at, int *after) {
        *region = -1;
        for (int i = 0; i < m_grammar.blocks.size(); ++i) {
            const auto m = m_grammar.blocks[i].start.match(text, from);
            if (m.hasMatch() && (*region < 0 || m.capturedStart() < *at)) {
                *region = i;
                *at = int(m.capturedStart());
                *after = int(m.capturedEnd());
            }
        }
    };
    int region = -1, at = 0, after = 0;
    if (previousBlockState() > 0) {
        region = previousBlockState() - 1;
        at = after = 0;
    } else {
        findStart(0, &region, &at, &after);
    }
    while (region >= 0) {
        const auto end = m_grammar.blocks[region].end.match(text, after);
        if (!end.hasMatch()) {
            setFormat(at, int(text.length()) - at, m_formats.value(m_grammar.blocks[region].role));
            setCurrentBlockState(region + 1);
            return;
        }
        setFormat(at, int(end.capturedEnd()) - at, m_formats.value(m_grammar.blocks[region].role));
        findStart(int(end.capturedEnd()), &region, &at, &after);
    }
}
