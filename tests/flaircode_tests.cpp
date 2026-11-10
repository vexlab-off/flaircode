#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextLayout>
#include <QtTest>

#include "document.h"
#include "highlighter.h"
#include "theme.h"
#include "workspace.h"

static void touch(const QString &path, const QByteArray &content = "x") {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(content);
}

static QByteArray read(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

class FlairCodeTests : public QObject {
    Q_OBJECT

private slots:
    void loadsEditsAndSavesAtomically() {
        QTemporaryDir dir;
        const auto path = dir.path() + "/main.cpp";
        touch(path, "int main() {}\n");
        Document doc(path, nullptr);
        QTextDocument text;
        doc.attachDocument(&text);
        QCOMPARE(text.toPlainText(), QString("int main() {}\n"));
        QVERIFY(!doc.dirty());
        QTextCursor cursor(&text);
        cursor.insertText("// hi\n");
        QVERIFY(doc.dirty());
        QVERIFY(doc.save());
        QVERIFY(!doc.dirty());
        QCOMPARE(read(path), QByteArray("// hi\nint main() {}\n"));
    }

    void refusesBinaryFiles() {
        QTemporaryDir dir;
        touch(dir.path() + "/blob.bin", QByteArray("ab\0cd", 5));
        Document doc(dir.path() + "/blob.bin", nullptr);
        QTextDocument text;
        doc.attachDocument(&text);
        QVERIFY(!doc.error().isEmpty());
        QVERIFY(!doc.save());
        QCOMPARE(read(dir.path() + "/blob.bin"), QByteArray("ab\0cd", 5));
    }

    void detectsLanguages() {
        QCOMPARE(Document::languageFor("/a/b.qml"), QString("qml"));
        QCOMPARE(Document::languageFor("/a/PKGBUILD"), QString("shell"));
        QCOMPARE(Document::languageFor("/a/x.unknown"), QString("text"));
        QCOMPARE(Document::commentFor("python"), QString("#"));
        QCOMPARE(Document::commentFor("cpp"), QString("//"));
        QCOMPARE(Document::languageNameFor("cpp"), QString("C++"));
    }

    void documentListReusesTabs() {
        QTemporaryDir dir;
        touch(dir.path() + "/a.txt");
        touch(dir.path() + "/b.txt");
        DocumentList list(nullptr);
        QCOMPARE(list.open(dir.path() + "/a.txt"), 0);
        QCOMPARE(list.open(dir.path() + "/b.txt"), 1);
        QCOMPARE(list.open(dir.path() + "/a.txt"), 0);
        QCOMPARE(list.rowCount(), 2);
        QCOMPARE(list.current(), 0);
        list.close(0);
        QCOMPARE(list.rowCount(), 1);
        QCOMPARE(list.current(), 0);
        QCOMPARE(list.open(dir.path() + "/missing.txt"), -1);
    }

    void fuzzyFindsByNameFirst() {
        QVERIFY(Workspace::fuzzyScore("bkd", "src/backend.cpp") > 0);
        QVERIFY(Workspace::fuzzyScore("xyz", "src/backend.cpp") < 0);
        QVERIFY(Workspace::fuzzyScore("main", "src/main.cpp") > Workspace::fuzzyScore("main", "docs/domain/notes.md"));
    }

    void listsFilesSkippingNoise() {
        QTemporaryDir dir;
        touch(dir.path() + "/src/a.cpp");
        touch(dir.path() + "/node_modules/x/y.js");
        touch(dir.path() + "/.git/HEAD");
        touch(dir.path() + "/.env");
        auto files = Workspace::listFiles(dir.path(), 100);
        files.sort();
        QCOMPARE(files, (QStringList{".env", "src/a.cpp"}));
    }

    void treeExpandsAndReveals() {
        QTemporaryDir dir;
        touch(dir.path() + "/src/deep/file.qml");
        touch(dir.path() + "/README.md");
        FileTree tree;
        tree.setRoot(dir.path());
        QCOMPARE(tree.rowCount(), 2); // src/, README.md
        const int row = tree.reveal(dir.path() + "/src/deep/file.qml");
        QVERIFY(row > 0);
        QCOMPARE(tree.pathAt(row), dir.path() + "/src/deep/file.qml");
        tree.toggle(0); // collapse src
        QCOMPARE(tree.rowCount(), 2);
    }

    void projectRootIsTheGitRepository() {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("repo/.git");
        touch(dir.path() + "/repo/src/x.cpp");
        QCOMPARE(Workspace::projectRootFor(dir.path() + "/repo/src/x.cpp"), dir.path() + "/repo");
    }

    void highlightsKeywordsAndComments() {
        QTemporaryDir themeDir;
        Theme theme(themeDir.path());
        QTextDocument text;
        Highlighter highlighter("cpp", &theme, &text);
        text.setPlainText("return 42; // done\n/* a\nb */ int x;");
        highlighter.rehighlight();
        auto formatAt = [&](int blockNumber, int column) {
            const auto block = text.findBlockByNumber(blockNumber);
            for (const auto &range : block.layout()->formats())
                if (column >= range.start && column < range.start + range.length)
                    return range.format.foreground().color();
            return QColor();
        };
        QCOMPARE(formatAt(0, 0), theme.syntax("keyword"));
        QCOMPARE(formatAt(0, 7), theme.syntax("number"));
        QCOMPARE(formatAt(0, 12), theme.syntax("comment"));
        QCOMPARE(formatAt(2, 0), theme.syntax("comment")); // inside the block comment
        QCOMPARE(formatAt(2, 5), theme.syntax("keyword")); // int, after it closes
    }
};

QTEST_MAIN(FlairCodeTests)
#include "flaircode_tests.moc"
