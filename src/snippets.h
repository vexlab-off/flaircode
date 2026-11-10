#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

// Code templates: type a short prefix, press Tab, get the whole construct
// with the cursor on the first thing to fill in.
class Snippets : public QObject {
    Q_OBJECT

public:
    explicit Snippets(QObject *parent = nullptr);

    struct Snippet {
        QString prefix;
        QString description;
        QString body; // ${1:placeholder} marks what to fill, $0 the final cursor
    };

    // {text, selectionStart, selectionEnd} relative to where the prefix began,
    // or an empty map when the prefix isn't a snippet for this language.
    Q_INVOKABLE QVariantMap expand(const QString &language, const QString &prefix) const;
    // [{prefix, description, preview}] for the help and the palette.
    Q_INVOKABLE QVariantList forLanguage(const QString &language) const;
    Q_INVOKABLE QStringList languages() const;

    static QVariantMap render(const QString &body);
    static QList<Snippet> library(const QString &language);
};
