#pragma once

#include <QHash>
#include <QRegularExpression>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QVector>

class Theme;

// Colours code by pattern: keywords, strings, numbers, comments, calls, and
// the markup of HTML, CSS, JSON and Markdown. Not a parser — fast, forgiving,
// and good enough to read code at a glance.
class Highlighter : public QSyntaxHighlighter {
    Q_OBJECT

public:
    Highlighter(const QString &language, Theme *theme, QTextDocument *document);

    struct Rule {
        QRegularExpression pattern;
        QString role;
        int group = 0;
    };
    struct Block {
        QRegularExpression start;
        QRegularExpression end;
        QString role;
    };
    struct Grammar {
        QVector<Rule> rules;
        QVector<Block> blocks; // multi-line comments and strings
    };

    static Grammar grammarFor(const QString &language);
    void refreshColors();

protected:
    void highlightBlock(const QString &text) override;

private:
    Grammar m_grammar;
    Theme *m_theme;
    QHash<QString, QTextCharFormat> m_formats;
};
