// Flair Code — the code editor of the flair suite.

#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QFont>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QUrl>

#include "document.h"
#include "theme.h"
#include "workspace.h"

// The accent is shared with flair: whatever colour flair's settings pick,
// the editor wears too, and it follows changes live.
static void followSuiteAccent(Theme *theme, QFileSystemWatcher *watcher) {
    const auto file = QDir::homePath() + "/.config/flair/flair.conf";
    auto apply = [theme, watcher, file] {
        QSettings flair(file, QSettings::IniFormat);
        theme->setOverride(flair.value("appearance/accent", "#ff8a3d").toString());
        if (QFileInfo::exists(file) && !watcher->files().contains(file))
            watcher->addPath(file);
    };
    QObject::connect(watcher, &QFileSystemWatcher::fileChanged, theme, apply);
    QObject::connect(watcher, &QFileSystemWatcher::directoryChanged, theme, apply);
    QDir().mkpath(QFileInfo(file).absolutePath());
    watcher->addPath(QFileInfo(file).absolutePath());
    apply();
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("flaircode");
    app.setApplicationDisplayName("Flair Code");
    app.setApplicationVersion("0.1.0");
    // Matches the window to flaircode.desktop for the compositor and launcher.
    app.setDesktopFileName("flaircode");
    app.setWindowIcon(QIcon::fromTheme("flaircode"));

    QQuickStyle::setStyle("Material");
    QFont font("Inter");
    font.setPixelSize(13);
    font.setHintingPreference(QFont::PreferNoHinting);
    app.setFont(font);

    Theme theme;
    QFileSystemWatcher accentWatcher;
    followSuiteAccent(&theme, &accentWatcher);
    Workspace workspace;
    DocumentList documents(&theme);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("workspace", &workspace);
    engine.rootContext()->setContextProperty("documents", &documents);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    // `flaircode <folder>` opens the folder; `flaircode <file>` opens its project
    // with the file in a tab.
    const auto args = app.arguments().mid(1);
    if (!args.isEmpty()) {
        const auto file = workspace.openPath(args.first());
        if (!file.isEmpty()) {
            documents.open(file);
            workspace.tree()->reveal(file);
        }
    }
    return app.exec();
}
