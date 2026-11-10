#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QFileInfo>
#include <QSettings>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVector>

// The project's files as an expandable tree, flattened into rows for a list
// view: each row knows its depth and whether it's open.
class FileTree : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role { NameRole = Qt::UserRole + 1, PathRole, IsDirRole, DepthRole, ExpandedRole };

    explicit FileTree(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setRoot(const QString &root);
    Q_INVOKABLE void toggle(int row);
    // Opens every folder on the way to a file and returns its row.
    Q_INVOKABLE int reveal(const QString &path);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString pathAt(int row) const;
    Q_INVOKABLE bool isDirAt(int row) const;

    static QVector<QFileInfo> childrenOf(const QString &directory);

signals:
    void countChanged();

private:
    struct Node {
        QString path;
        QString name;
        bool isDir = false;
        int depth = 0;
        bool expanded = false;
    };
    void expand(int row);
    void collapse(int row);

    QString m_root;
    QVector<Node> m_rows;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};

class Workspace : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString root READ root NOTIFY rootChanged)
    Q_PROPERTY(QString name READ name NOTIFY rootChanged)
    Q_PROPERTY(QString branch READ branch NOTIFY branchChanged)
    Q_PROPERTY(QStringList recent READ recent NOTIFY recentChanged)
    Q_PROPERTY(FileTree *tree READ tree CONSTANT)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)

public:
    explicit Workspace(const QString &settingsFile = {}, QObject *parent = nullptr);

    QString root() const { return m_root; }
    QString name() const { return QFileInfo(m_root).fileName(); }
    QString branch() const { return m_branch; }
    QStringList recent() const;
    FileTree *tree() { return &m_tree; }
    QString message() const { return m_message; }

    // Opens a folder, or the project around a file (its git root, or its
    // folder). Returns the file to open, if a file was given.
    Q_INVOKABLE QString openPath(const QString &path);
    // Up to `limit` project files matching the query, best first.
    Q_INVOKABLE QVariantList quickOpen(const QString &query, int limit = 40);
    Q_INVOKABLE QString createFile(const QString &relativePath);
    Q_INVOKABLE bool createFolder(const QString &relativePath);
    Q_INVOKABLE void refreshBranch();
    // Asks the desktop for a folder through xdg-desktop-portal.
    Q_INVOKABLE void pickFolder();
    Q_INVOKABLE void forgetRecent(const QString &path);

    static QStringList listFiles(const QString &root, int limit);
    // Higher is better; negative means the query's letters aren't all there in order.
    static int fuzzyScore(const QString &query, const QString &relativePath);
    static QString projectRootFor(const QString &path);

signals:
    void rootChanged();
    void branchChanged();
    void recentChanged();
    void messageChanged();
    void folderPicked(const QString &path);

private slots:
    void portalResponse(uint response, const QVariantMap &results);

private:
    void setMessage(const QString &message);

    QSettings m_settings;
    QString m_root;
    QString m_branch;
    QString m_message;
    FileTree m_tree;
    QStringList m_files;
};
