#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTextBlock>
#include <QJsonObject>
#include <QTextDocument>
#include <QTextLayout>
#include <QtTest>

#include "ai.h"
#include "assistant.h"
#include "colorscheme.h"
#include "document.h"
#include "settings.h"
#include "snippets.h"
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
        EditorSettings settings(themeDir.path() + "/flaircode.conf");
        ColorScheme scheme(&theme, &settings);
        QTextDocument text;
        Highlighter highlighter("cpp", &scheme, &text);
        text.setPlainText("return 42; // done\n/* a\nb */ int x;");
        highlighter.rehighlight();
        auto formatAt = [&](int blockNumber, int column) {
            const auto block = text.findBlockByNumber(blockNumber);
            for (const auto &range : block.layout()->formats())
                if (column >= range.start && column < range.start + range.length)
                    return range.format.foreground().color();
            return QColor();
        };
        QCOMPARE(formatAt(0, 0), scheme.color("keyword"));
        QCOMPARE(formatAt(0, 7), scheme.color("number"));
        QCOMPARE(formatAt(0, 12), scheme.color("comment"));
        QCOMPARE(formatAt(2, 0), scheme.color("comment")); // inside the block comment
        QCOMPARE(formatAt(2, 5), scheme.color("keyword")); // int, after it closes
    }

    void schemeOverridesWinOverPresets() {
        QTemporaryDir dir;
        Theme theme(dir.path());
        EditorSettings settings(dir.path() + "/flaircode.conf");
        ColorScheme scheme(&theme, &settings);
        settings.set("appearance/scheme", "papier");
        QCOMPARE(scheme.color("background").name(), QString("#fbf8f3"));
        settings.set("syntax/keyword", "#123456");
        QCOMPARE(scheme.color("keyword").name(), QString("#123456"));
        QVERIFY(scheme.italic("comment"));
        settings.set("syntaxStyle/comment", "bold");
        QVERIFY(scheme.bold("comment"));
        QVERIFY(!scheme.italic("comment"));
        settings.resetGroup("syntax");
        QCOMPARE(scheme.color("keyword").name(), QString("#b4361a"));
    }

    void settingsStoreOnlyChanges() {
        QTemporaryDir dir;
        EditorSettings settings(dir.path() + "/flaircode.conf");
        QCOMPARE(settings.value("editor/tabWidth").toInt(), 4);
        settings.set("editor/tabWidth", 2);
        QVERIFY(settings.isCustom("editor/tabWidth"));
        settings.set("editor/tabWidth", 4); // back to the default: not stored
        QVERIFY(!settings.isCustom("editor/tabWidth"));
        QCOMPARE(EditorSettings::environmentVariableFor("gemini"), QString("GEMINI_API_KEY"));
    }

    void snippetsPlacePlaceholders() {
        const auto r = Snippets::render("for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n    $0\n}");
        QCOMPARE(r.value("text").toString(), QString("for (int i = 0; i < n; ++i) {\n    \n}"));
        QCOMPARE(r.value("selectionStart").toInt(), 9);
        QCOMPARE(r.value("selectionEnd").toInt(), 10);
        Snippets snippets;
        QVERIFY(!snippets.expand("python", "def").isEmpty());
        QVERIFY(snippets.expand("python", "nope").isEmpty());
        QVERIFY(!snippets.expand("typescript", "afn").isEmpty()); // shares the JavaScript library
    }

    void decodesProviderStreams() {
        QString error;
        QCOMPARE(AiClient::claudeText(R"({"type":"content_block_delta","delta":{"type":"text_delta","text":"a"}})", &error), QString("a"));
        QCOMPARE(AiClient::openAiText(R"({"choices":[{"delta":{"content":"b"}}]})", &error), QString("b"));
        QCOMPARE(AiClient::openAiText("[DONE]", &error), QString());
        QCOMPARE(AiClient::geminiText(R"({"candidates":[{"content":{"parts":[{"text":"c"},{"text":"d"}]}}]})", &error), QString("cd"));
        QVERIFY(error.isEmpty());
        AiClient::geminiText(R"({"error":{"message":"bad key"}})", &error);
        QVERIFY(error.contains("bad key"));
        const auto contents = AiClient::geminiContents({{"user", "q"}, {"assistant", "r"}});
        QCOMPARE(contents.at(1).toObject().value("role").toString(), QString("model"));
    }

    void splitsAnswersIntoCodeBlocks() {
        const auto parts = Assistant::segments("Voici :\n```cpp\nint x;\n```\nVoilà.");
        QCOMPARE(parts.size(), 3);
        QCOMPARE(parts[1].toMap().value("type").toString(), QString("code"));
        QCOMPARE(parts[1].toMap().value("language").toString(), QString("cpp"));
        QCOMPARE(parts[1].toMap().value("content").toString(), QString("int x;"));
        QCOMPARE(Assistant::unfence("```js\nlet a;\n```"), QString("let a;"));
        QCOMPARE(Assistant::unfence("let a;"), QString("let a;"));
    }

    void savesWithCleanup() {
        QTemporaryDir dir;
        const auto path = dir.path() + "/a.py";
        touch(path, "x = 1   \ny = 2");
        Document doc(path, nullptr);
        QTextDocument text;
        doc.attachDocument(&text);
        QVERIFY(doc.save(true, true));
        QCOMPARE(read(path), QByteArray("x = 1\ny = 2\n"));
        QCOMPARE(doc.lineAt(text.toPlainText().indexOf("y")), 1);
        QVERIFY(Document::isImageFile("/a/b.PNG"));
    }
};

QTEST_MAIN(FlairCodeTests)
#include "flaircode_tests.moc"
