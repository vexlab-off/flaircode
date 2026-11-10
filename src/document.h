#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QVector>

class Highlighter;
class QQuickTextDocument;
class QTextDocument;
class Theme;

// One open file. The editor's QTextDocument holds the text and its undo
// history; this object loads it, saves it atomically, and says whether it
// has unsaved changes or was changed on disk by someone else.
class Document : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString language READ language CONSTANT)
    Q_PROPERTY(QString languageName READ languageName CONSTANT)
    Q_PROPERTY(QString commentToken READ commentToken CONSTANT)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)
    Q_PROPERTY(bool changedOnDisk READ changedOnDisk NOTIFY changedOnDiskChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    Document(const QString &path, Theme *theme, QObject *parent = nullptr);

    QString path() const { return m_path; }
    QString name() const;
    QString language() const { return m_language; }
    QString languageName() const { return languageNameFor(m_language); }
    QString commentToken() const { return commentFor(m_language); }
    bool dirty() const;
    bool changedOnDisk() const { return m_changedOnDisk; }
    QString error() const { return m_error; }

    // Called by the editor once its text document exists.
    Q_INVOKABLE void attach(QQuickTextDocument *document);
    Q_INVOKABLE bool save();
    Q_INVOKABLE void reload();
    // Attach to a plain QTextDocument (tests, and the work attach() does).
    void attachDocument(QTextDocument *document);
    QString text() const;

    static QString languageFor(const QString &path);
    static QString languageNameFor(const QString &language);
    static QString commentFor(const QString &language);

signals:
    void dirtyChanged();
    void changedOnDiskChanged();
    void errorChanged();
    void saved();

private:
    bool load();
    void setError(const QString &error);

    QString m_path;
    QString m_language;
    Theme *m_theme;
    QPointer<QTextDocument> m_document;
    Highlighter *m_highlighter = nullptr;
    QFileSystemWatcher m_watcher;
    bool m_changedOnDisk = false;
    bool m_saving = false;
    QString m_error;
};

// The open files, in tab order.
class DocumentList : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int current READ current WRITE setCurrent NOTIFY currentChanged)
    Q_PROPERTY(Document *currentDocument READ currentDocument NOTIFY currentChanged)
    Q_PROPERTY(int dirtyCount READ dirtyCount NOTIFY dirtyCountChanged)

public:
    enum Role { DocumentRole = Qt::UserRole + 1, NameRole, PathRole, DirtyRole, LanguageRole };

    explicit DocumentList(Theme *theme, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int current() const { return m_current; }
    void setCurrent(int index);
    Document *currentDocument() const;
    int dirtyCount() const;

    // Opens a file, or switches to it when it's already open. Returns its index.
    Q_INVOKABLE int open(const QString &path);
    Q_INVOKABLE void close(int index);
    Q_INVOKABLE int indexOf(const QString &path) const;
    Q_INVOKABLE Document *at(int index) const;
    Q_INVOKABLE bool saveAll();
    Q_INVOKABLE void next(int step);

signals:
    void countChanged();
    void currentChanged();
    void dirtyCountChanged();

private:
    Theme *m_theme;
    QVector<Document *> m_documents;
    int m_current = -1;
};
