#include "workspace.h"

#include <QCollator>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QLocale>
#include <QProcess>
#include <QSet>
#include <QUrl>
#include <QVariantMap>
#include <algorithm>

// Folders nobody wants to browse or search in an editor.
static const QSet<QString> &skipped() {
    static const QSet<QString> names{".git", "node_modules", "build", "dist", "target", "__pycache__", ".venv",
                                     "venv", ".cache", ".dart_tool", ".gradle", ".idea", "pkg"};
    return names;
}

// ---------------------------------------------------------------- FileTree

FileTree::FileTree(QObject *parent) : QAbstractListModel(parent) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(200);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &FileTree::refresh);
}

int FileTree::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : int(m_rows.size()); }

QVariant FileTree::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const auto &n = m_rows[index.row()];
    switch (role) {
    case NameRole: return n.name;
    case PathRole: return n.path;
    case IsDirRole: return n.isDir;
    case DepthRole: return n.depth;
    case ExpandedRole: return n.expanded;
    }
    return {};
}

QHash<int, QByteArray> FileTree::roleNames() const {
    return {{NameRole, "name"}, {PathRole, "path"}, {IsDirRole, "isDir"}, {DepthRole, "depth"},
            {ExpandedRole, "expanded"}};
}

QVector<QFileInfo> FileTree::childrenOf(const QString &directory) {
    auto entries = QDir(directory).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden).toVector();
    entries.erase(std::remove_if(entries.begin(), entries.end(), [](const QFileInfo &i) { return i.fileName() == ".git"; }),
                  entries.end());
    QCollator collator(QLocale(QLocale::French));
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(entries.begin(), entries.end(), [&](const QFileInfo &a, const QFileInfo &b) {
        if (a.isDir() != b.isDir())
            return a.isDir();
        return collator.compare(a.fileName(), b.fileName()) < 0;
    });
    return entries;
}

void FileTree::setRoot(const QString &root) {
    m_root = root;
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    beginResetModel();
    m_rows.clear();
    if (!root.isEmpty()) {
        m_watcher.addPath(root);
        for (const auto &info : childrenOf(root))
            m_rows.append({info.absoluteFilePath(), info.fileName(), info.isDir(), 0, false});
    }
    endResetModel();
    emit countChanged();
}

void FileTree::expand(int row) {
    auto &node = m_rows[row];
    if (!node.isDir || node.expanded)
        return;
    node.expanded = true;
    m_watcher.addPath(node.path);
    const auto children = childrenOf(node.path);
    const int depth = node.depth + 1;
    emit dataChanged(index(row), index(row), {ExpandedRole});
    if (children.isEmpty())
        return;
    beginInsertRows({}, row + 1, row + int(children.size()));
    for (int i = 0; i < children.size(); ++i)
        m_rows.insert(row + 1 + i, {children[i].absoluteFilePath(), children[i].fileName(), children[i].isDir(), depth, false});
    endInsertRows();
    emit countChanged();
}

void FileTree::collapse(int row) {
    auto &node = m_rows[row];
    if (!node.expanded)
        return;
    node.expanded = false;
    m_watcher.removePath(node.path);
    int last = row;
    while (last + 1 < m_rows.size() && m_rows[last + 1].depth > node.depth)
        ++last;
    emit dataChanged(index(row), index(row), {ExpandedRole});
    if (last == row)
        return;
    beginRemoveRows({}, row + 1, last);
    m_rows.remove(row + 1, last - row);
    endRemoveRows();
    emit countChanged();
}

void FileTree::toggle(int row) {
    if (row < 0 || row >= m_rows.size())
        return;
    if (m_rows[row].expanded)
        collapse(row);
    else
        expand(row);
}

int FileTree::reveal(const QString &path) {
    if (m_root.isEmpty() || !path.startsWith(m_root + "/"))
        return -1;
    // Open each ancestor folder, top down.
    const auto parts = path.mid(m_root.size() + 1).split('/');
    QString current = m_root;
    for (int i = 0; i < parts.size(); ++i) {
        current += "/" + parts[i];
        int row = -1;
        for (int r = 0; r < m_rows.size(); ++r)
            if (m_rows[r].path == current) {
                row = r;
                break;
            }
        if (row < 0)
            return -1;
        if (i == parts.size() - 1)
            return row;
        expand(row);
    }
    return -1;
}

void FileTree::refresh() {
    // Rebuild, keeping the same folders open.
    QStringList open;
    for (const auto &n : m_rows)
        if (n.expanded)
            open << n.path;
    setRoot(m_root);
    for (int r = 0; r < m_rows.size(); ++r)
        if (open.contains(m_rows[r].path))
            expand(r);
}

QString FileTree::pathAt(int row) const { return row >= 0 && row < m_rows.size() ? m_rows[row].path : QString(); }
bool FileTree::isDirAt(int row) const { return row >= 0 && row < m_rows.size() && m_rows[row].isDir; }

// ---------------------------------------------------------------- Workspace

Workspace::Workspace(const QString &settingsFile, QObject *parent)
    : QObject(parent),
      m_settings(settingsFile.isEmpty() ? QDir::homePath() + "/.config/flaircode/flaircode.conf" : settingsFile,
                 QSettings::IniFormat) {}

QStringList Workspace::recent() const {
    QStringList existing;
    for (const auto &path : m_settings.value("recent").toStringList())
        if (QFileInfo(path).isDir())
            existing << path;
    return existing;
}

void Workspace::forgetRecent(const QString &path) {
    auto list = m_settings.value("recent").toStringList();
    list.removeAll(path);
    m_settings.setValue("recent", list);
    emit recentChanged();
}

void Workspace::setMessage(const QString &message) {
    m_message = message;
    emit messageChanged();
}

QString Workspace::projectRootFor(const QString &path) {
    const QFileInfo info(path);
    QString dir = info.isDir() ? info.absoluteFilePath() : info.absolutePath();
    // The nearest folder holding .git is the project; otherwise the file's folder.
    for (QString d = dir; !d.isEmpty() && d != "/"; d = QFileInfo(d).absolutePath()) {
        if (QFileInfo(d + "/.git").exists())
            return d;
        if (d == QDir::homePath())
            break;
    }
    return dir;
}

QString Workspace::openPath(const QString &pathIn) {
    QString path = pathIn.trimmed();
    if (path.startsWith("file://"))
        path = QUrl(path).toLocalFile();
    if (path.startsWith("~"))
        path = QDir::homePath() + path.mid(1);
    const QFileInfo info(path);
    if (!info.exists()) {
        setMessage(tr("« %1 » n'existe pas.").arg(path));
        return {};
    }
    const auto root = info.isDir() ? QDir::cleanPath(info.absoluteFilePath()) : projectRootFor(path);
    if (root != m_root) {
        m_root = root;
        m_tree.setRoot(root);
        m_files.clear();
        auto list = m_settings.value("recent").toStringList();
        list.removeAll(root);
        list.prepend(root);
        m_settings.setValue("recent", list.mid(0, 12));
        emit recentChanged();
        emit rootChanged();
        refreshBranch();
    }
    return info.isFile() ? info.absoluteFilePath() : QString();
}

void Workspace::refreshBranch() {
    QProcess git;
    git.setWorkingDirectory(m_root);
    git.start("git", {"branch", "--show-current"});
    git.waitForFinished(2000);
    const auto branch = git.exitCode() == 0 ? QString::fromUtf8(git.readAllStandardOutput()).trimmed() : QString();
    if (branch != m_branch) {
        m_branch = branch;
        emit branchChanged();
    }
}

QStringList Workspace::listFiles(const QString &root, int limit) {
    QStringList files;
    QStringList queue{root};
    while (!queue.isEmpty() && files.size() < limit) {
        const QDir dir(queue.takeFirst());
        for (const auto &info : dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::NoSymLinks)) {
            if (info.isDir()) {
                if (!skipped().contains(info.fileName()))
                    queue << info.absoluteFilePath();
            } else if (files.size() < limit) {
                files << info.absoluteFilePath().mid(root.size() + 1);
            }
        }
    }
    return files;
}

int Workspace::fuzzyScore(const QString &queryIn, const QString &path) {
    const auto query = queryIn.toLower().remove(' ');
    if (query.isEmpty())
        return 0;
    const auto lower = path.toLower();
    const int nameStart = int(lower.lastIndexOf('/')) + 1;
    int score = 0, pos = 0, streak = 0;
    for (const auto c : query) {
        const int found = int(lower.indexOf(c, pos));
        if (found < 0)
            return -1;
        // Reward letters in a row, letters in the file name, and word starts.
        streak = found == pos ? streak + 1 : 0;
        score += 1 + streak * 3 + (found >= nameStart ? 4 : 0);
        if (found == 0 || QString("/_-. ").contains(lower[found - 1]))
            score += 5;
        pos = found + 1;
    }
    if (lower.mid(nameStart).startsWith(query))
        score += 20;
    return score * 100 / (int(path.size()) + 10);
}

QVariantList Workspace::quickOpen(const QString &query, int limit) {
    if (m_root.isEmpty())
        return {};
    if (m_files.isEmpty())
        m_files = listFiles(m_root, 30000);
    QVector<QPair<int, QString>> scored;
    for (const auto &file : m_files) {
        const int s = query.isEmpty() ? 0 : fuzzyScore(query, file);
        if (s >= 0)
            scored.append({s, file});
    }
    std::stable_sort(scored.begin(), scored.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
    QVariantList out;
    for (int i = 0; i < scored.size() && i < limit; ++i)
        out.append(QVariantMap{{"relative", scored[i].second},
                               {"name", QFileInfo(scored[i].second).fileName()},
                               {"path", m_root + "/" + scored[i].second}});
    return out;
}

QString Workspace::createFile(const QString &relative) {
    const auto path = QDir::cleanPath(m_root + "/" + relative.trimmed());
    if (relative.trimmed().isEmpty() || !path.startsWith(m_root + "/")) {
        setMessage(tr("Chemin invalide."));
        return {};
    }
    if (QFileInfo::exists(path)) {
        setMessage(tr("« %1 » existe déjà.").arg(relative));
        return path;
    }
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        setMessage(tr("Impossible de créer « %1 ».").arg(relative));
        return {};
    }
    file.close();
    m_files.clear();
    m_tree.refresh();
    return path;
}

bool Workspace::createFolder(const QString &relative) {
    const auto path = QDir::cleanPath(m_root + "/" + relative.trimmed());
    if (relative.trimmed().isEmpty() || !path.startsWith(m_root + "/") || !QDir().mkpath(path)) {
        setMessage(tr("Impossible de créer le dossier « %1 ».").arg(relative));
        return false;
    }
    m_tree.refresh();
    return true;
}

// ---------------------------------------------------------------- portal

void Workspace::pickFolder() {
    // xdg-desktop-portal's FileChooser, so the picker is the desktop's own.
    auto message = QDBusMessage::createMethodCall("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                                                  "org.freedesktop.portal.FileChooser", "OpenFile");
    QVariantMap options{{"directory", true}, {"modal", true}};
    message << QString() << tr("Ouvrir un dossier") << options;
    const QDBusReply<QDBusObjectPath> reply = QDBusConnection::sessionBus().call(message);
    if (!reply.isValid()) {
        setMessage(tr("Le sélecteur de fichiers du système ne répond pas (xdg-desktop-portal) : %1")
                       .arg(reply.error().message()));
        return;
    }
    QDBusConnection::sessionBus().connect("org.freedesktop.portal.Desktop", reply.value().path(),
                                          "org.freedesktop.portal.Request", "Response", this,
                                          SLOT(portalResponse(uint, QVariantMap)));
}

void Workspace::portalResponse(uint response, const QVariantMap &results) {
    if (response != 0)
        return; // cancelled
    const auto uris = results.value("uris").toStringList();
    if (!uris.isEmpty())
        emit folderPicked(QUrl(uris.first()).toLocalFile());
}
