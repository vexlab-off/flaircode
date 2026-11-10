#include "document.h"

#include "highlighter.h"
#include "colorscheme.h"

#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QQuickTextDocument>
#include <QSaveFile>
#include <QRegularExpression>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>

Document::Document(const QString &path, ColorScheme *scheme, QObject *parent)
    : QObject(parent), m_path(QFileInfo(path).absoluteFilePath()), m_language(languageFor(path)), m_scheme(scheme) {
    m_watcher.addPath(m_path);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
        // Editors and git replace files; keep watching the new one.
        if (QFileInfo::exists(m_path) && !m_watcher.files().contains(m_path))
            m_watcher.addPath(m_path);
        if (m_saving)
            return;
        if (!dirty()) {
            // Nothing to lose: follow the file.
            reload();
        } else if (!m_changedOnDisk) {
            m_changedOnDisk = true;
            emit changedOnDiskChanged();
        }
    });
}

QString Document::name() const { return QFileInfo(m_path).fileName(); }

bool Document::dirty() const { return m_document && m_document->isModified(); }

bool Document::isImageFile(const QString &path) {
    static const QStringList images{"png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "avif", "tif", "tiff"};
    return images.contains(QFileInfo(path).suffix().toLower());
}

bool Document::previewable() const {
    const auto suffix = QFileInfo(m_path).suffix().toLower();
    return m_language == "html" || m_language == "markdown" || suffix == "svg" || isImage();
}

int Document::lineAt(int position) const {
    return m_document ? m_document->findBlock(position).blockNumber() : 0;
}

int Document::columnAt(int position) const {
    return m_document ? position - m_document->findBlock(position).position() : 0;
}

QString Document::text() const { return m_document ? m_document->toPlainText() : QString(); }

void Document::setError(const QString &error) {
    m_error = error;
    emit errorChanged();
}

void Document::attach(QQuickTextDocument *document) {
    if (document)
        attachDocument(document->textDocument());
}

void Document::attachDocument(QTextDocument *document) {
    if (m_document == document)
        return;
    m_document = document;
    connect(document, &QTextDocument::modificationChanged, this, &Document::dirtyChanged);
    if (m_scheme)
        m_highlighter = new Highlighter(m_language, m_scheme, document);
    load();
}

bool Document::load() {
    if (isImage()) {
        emit reloaded();
        return true;
    }
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly)) {
        setError(tr("Impossible de lire « %1 ».").arg(name()));
        return false;
    }
    const auto bytes = file.readAll();
    if (bytes.left(8000).contains('\0')) {
        setError(tr("« %1 » est un fichier binaire : Flair Code ne l'ouvre pas pour ne pas l'abîmer.").arg(name()));
        m_document->setPlainText(QString());
        m_document->setModified(false);
        return false;
    }
    m_document->setUndoRedoEnabled(false);
    m_document->setPlainText(QString::fromUtf8(bytes));
    m_document->setUndoRedoEnabled(true);
    m_document->setModified(false);
    if (m_changedOnDisk) {
        m_changedOnDisk = false;
        emit changedOnDiskChanged();
    }
    if (!m_error.isEmpty())
        setError({});
    emit reloaded();
    return true;
}

void Document::reload() {
    if (m_document || isImage())
        load();
}

bool Document::save(bool trimTrailing, bool finalNewline) {
    if (!m_document || !m_error.isEmpty())
        return false;
    if (trimTrailing || finalNewline) {
        QTextCursor cursor(m_document);
        cursor.beginEditBlock();
        if (trimTrailing) {
            static const QRegularExpression trailing("[ \t]+$");
            for (auto block = m_document->begin(); block.isValid(); block = block.next()) {
                const auto match = trailing.match(block.text());
                if (match.hasMatch()) {
                    cursor.setPosition(block.position() + int(match.capturedStart()));
                    cursor.setPosition(block.position() + int(match.capturedEnd()), QTextCursor::KeepAnchor);
                    cursor.removeSelectedText();
                }
            }
        }
        if (finalNewline && !m_document->isEmpty() && !m_document->toPlainText().endsWith('\n')) {
            cursor.movePosition(QTextCursor::End);
            cursor.insertText("\n");
        }
        cursor.endEditBlock();
    }
    // Write beside the file, then rename over it: a crash never leaves half a file.
    m_saving = true;
    QSaveFile file(m_path);
    const bool ok = file.open(QIODevice::WriteOnly) && file.write(m_document->toPlainText().toUtf8()) >= 0 &&
                    file.commit();
    m_saving = false;
    if (!m_watcher.files().contains(m_path))
        m_watcher.addPath(m_path);
    if (!ok) {
        setError(tr("Impossible d'enregistrer « %1 » : %2").arg(name(), file.errorString()));
        return false;
    }
    m_document->setModified(false);
    if (m_changedOnDisk) {
        m_changedOnDisk = false;
        emit changedOnDiskChanged();
    }
    emit saved();
    return true;
}

QString Document::languageFor(const QString &path) {
    static const QHash<QString, QString> byExtension{
        {"c", "c"},          {"h", "cpp"},          {"cpp", "cpp"},       {"cc", "cpp"},         {"cxx", "cpp"},
        {"hpp", "cpp"},      {"hh", "cpp"},         {"js", "javascript"}, {"mjs", "javascript"}, {"cjs", "javascript"},
        {"jsx", "javascript"}, {"ts", "typescript"}, {"tsx", "typescript"}, {"qml", "qml"},       {"py", "python"},
        {"rs", "rust"},      {"go", "go"},          {"java", "java"},     {"kt", "kotlin"},      {"dart", "dart"},
        {"cs", "csharp"},    {"swift", "swift"},    {"sh", "shell"},      {"bash", "shell"},     {"zsh", "shell"},
        {"html", "html"},    {"htm", "html"},       {"xml", "xml"},       {"svg", "xml"},        {"ui", "xml"},
        {"qrc", "xml"},      {"css", "css"},        {"scss", "css"},      {"json", "json"},      {"md", "markdown"},
        {"markdown", "markdown"}, {"yaml", "yaml"}, {"yml", "yaml"},      {"toml", "toml"},      {"ini", "ini"},
        {"conf", "ini"},     {"pro", "ini"},        {"desktop", "ini"}};
    const QFileInfo info(path);
    const auto lower = info.fileName().toLower();
    if (lower == "pkgbuild" || lower.endsWith("rc") && lower.startsWith('.'))
        return "shell";
    if (lower == "makefile" || lower == "dockerfile")
        return "shell";
    return byExtension.value(info.suffix().toLower(), "text");
}

QString Document::languageNameFor(const QString &language) {
    static const QHash<QString, QString> names{
        {"c", "C"},           {"cpp", "C++"},        {"javascript", "JavaScript"}, {"typescript", "TypeScript"},
        {"qml", "QML"},       {"python", "Python"},  {"rust", "Rust"},             {"go", "Go"},
        {"java", "Java"},     {"kotlin", "Kotlin"},  {"dart", "Dart"},             {"csharp", "C#"},
        {"swift", "Swift"},   {"shell", "Shell"},    {"html", "HTML"},             {"xml", "XML"},
        {"css", "CSS"},       {"json", "JSON"},      {"markdown", "Markdown"},     {"yaml", "YAML"},
        {"toml", "TOML"},     {"ini", "INI"},        {"text", "Texte"}};
    return names.value(language, "Texte");
}

QString Document::commentFor(const QString &language) {
    if (language == "python" || language == "shell" || language == "yaml" || language == "toml")
        return "#";
    if (language == "ini")
        return ";";
    if (language == "html" || language == "xml" || language == "markdown" || language == "json" ||
        language == "css" || language == "text")
        return {};
    return "//";
}

// ---------------------------------------------------------------- DocumentList

DocumentList::DocumentList(ColorScheme *scheme, QObject *parent) : QAbstractListModel(parent), m_scheme(scheme) {}

int DocumentList::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : int(m_documents.size());
}

QVariant DocumentList::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_documents.size())
        return {};
    auto *d = m_documents[index.row()];
    switch (role) {
    case DocumentRole: return QVariant::fromValue(d);
    case NameRole: return d->name();
    case PathRole: return d->path();
    case DirtyRole: return d->dirty();
    case LanguageRole: return d->language();
    }
    return {};
}

QHash<int, QByteArray> DocumentList::roleNames() const {
    return {{DocumentRole, "document"}, {NameRole, "name"}, {PathRole, "path"}, {DirtyRole, "dirty"},
            {LanguageRole, "language"}};
}

void DocumentList::setCurrent(int index) {
    if (index < -1 || index >= m_documents.size() || index == m_current)
        return;
    m_current = index;
    emit currentChanged();
}

Document *DocumentList::currentDocument() const {
    return m_current >= 0 && m_current < m_documents.size() ? m_documents[m_current] : nullptr;
}

Document *DocumentList::at(int index) const {
    return index >= 0 && index < m_documents.size() ? m_documents[index] : nullptr;
}

int DocumentList::dirtyCount() const {
    int n = 0;
    for (auto *d : m_documents)
        n += d->dirty();
    return n;
}

int DocumentList::indexOf(const QString &path) const {
    const auto absolute = QFileInfo(path).absoluteFilePath();
    for (int i = 0; i < m_documents.size(); ++i)
        if (m_documents[i]->path() == absolute)
            return i;
    return -1;
}

int DocumentList::open(const QString &path) {
    int index = indexOf(path);
    if (index < 0) {
        if (!QFileInfo(path).isFile())
            return -1;
        // Pictures are viewed, not edited, so they never need a text document.
        auto *d = new Document(path, m_scheme, this);
        connect(d, &Document::dirtyChanged, this, [this, d] {
            const int row = int(m_documents.indexOf(d));
            if (row >= 0)
                emit dataChanged(this->index(row), this->index(row), {DirtyRole});
            emit dirtyCountChanged();
        });
        index = int(m_documents.size());
        beginInsertRows({}, index, index);
        m_documents.append(d);
        endInsertRows();
        emit countChanged();
    }
    m_current = -2; // force the notification even when reopening the same index
    setCurrent(index);
    return index;
}

void DocumentList::close(int index) {
    if (index < 0 || index >= m_documents.size())
        return;
    beginRemoveRows({}, index, index);
    auto *d = m_documents.takeAt(index);
    endRemoveRows();
    d->deleteLater();
    emit countChanged();
    emit dirtyCountChanged();
    const int next = m_documents.isEmpty() ? -1 : qMin(index, int(m_documents.size()) - 1);
    m_current = -2;
    setCurrent(next);
}

bool DocumentList::saveAll() {
    bool ok = true;
    for (auto *d : m_documents)
        if (d->dirty())
            ok = d->save() && ok;
    return ok;
}

void DocumentList::next(int step) {
    if (m_documents.isEmpty())
        return;
    const int n = int(m_documents.size());
    setCurrent(((m_current + step) % n + n) % n);
}
