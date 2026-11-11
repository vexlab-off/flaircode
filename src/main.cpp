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
#include <QQuickWindow>
#include <QTimer>
#include <QSettings>
#include <QUrl>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "ai.h"
#include "assistant.h"
#include "colorscheme.h"
#include "document.h"
#include "settings.h"
#include "snippets.h"
#include "theme.h"
#include "workspace.h"

// The accent is shared with flair by default: whatever colour flair's
// settings pick, the editor wears too, live. A colour chosen in Flair Code's
// own settings takes over.
static void followAccent(Theme *theme, EditorSettings *settings, QFileSystemWatcher *watcher) {
    const auto file = QDir::homePath() + "/.config/flair/flair.conf";
    auto apply = [theme, settings, watcher, file] {
        // In sync, the suite's colours come from flair's settings; otherwise
        // Flair Code's own (where "flair" still means "like flair").
        QSettings flair(file, QSettings::IniFormat);
        const bool sync = flair.value("appearance/sync", "true").toString() == "true";
        theme->setLogoStyle(flair.value("appearance/logoStyle", "plein").toString());
        theme->setFolderColor(flair.value("appearance/folderColor", "accent").toString());
        const auto flairAccent = flair.value("appearance/accent", "#ff8a3d").toString();
        const auto flairMode = flair.value("appearance/mode", "auto").toString();
        const auto ownAccent = settings->value("appearance/accent").toString();
        const auto ownMode = settings->value("appearance/mode").toString();
        theme->setOverride(sync || ownAccent == "flair" ? flairAccent : ownAccent);
        theme->setMode(sync || ownMode == "flair" ? flairMode : ownMode);
        if (QFileInfo::exists(file) && !watcher->files().contains(file))
            watcher->addPath(file);
    };
    QObject::connect(watcher, &QFileSystemWatcher::fileChanged, theme, apply);
    QObject::connect(watcher, &QFileSystemWatcher::directoryChanged, theme, apply);
    QObject::connect(settings, &EditorSettings::changed, theme, apply);
    QDir().mkpath(QFileInfo(file).absolutePath());
    watcher->addPath(QFileInfo(file).absolutePath());
    apply();
}

int main(int argc, char *argv[]) {
    // The live preview runs Chromium, which must be set up before the app.
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    app.setApplicationName("flaircode");
    app.setApplicationDisplayName("Flair Code");
    app.setApplicationVersion("0.1.0");
    // Matches the window to flaircode.desktop for the compositor and launcher.
    app.setDesktopFileName("flaircode");
    app.setWindowIcon(QIcon::fromTheme("flaircode"));

    // Compact Material controls: editors want dense fields, not 56 px inputs.
    qputenv("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense");
    QQuickStyle::setStyle("Material");
    QFont font("Inter");
    font.setPixelSize(13);
    font.setHintingPreference(QFont::PreferNoHinting);
    app.setFont(font);

    Theme theme;
    EditorSettings settings;
    QFileSystemWatcher accentWatcher;
    followAccent(&theme, &settings, &accentWatcher);
    ColorScheme scheme(&theme, &settings);
    Workspace workspace;
    DocumentList documents(&scheme);
    AiClient ai(&settings);
    Assistant assistant(&ai, &settings);
    Snippets snippets;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("workspace", &workspace);
    engine.rootContext()->setContextProperty("documents", &documents);
    engine.rootContext()->setContextProperty("settings", &settings);
    engine.rootContext()->setContextProperty("scheme", &scheme);
    engine.rootContext()->setContextProperty("assistant", &assistant);
    engine.rootContext()->setContextProperty("snippets", &snippets);
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
    // Development aid: FLAIRCODE_SNAPSHOT=out.png [FLAIRCODE_SNAPSHOT_DELAY=ms]
    // renders the window to an image and quits — works offscreen, so the UI
    // can be checked without opening a window on anyone's screen.
    const auto snapshot = qEnvironmentVariable("FLAIRCODE_SNAPSHOT");
    if (!snapshot.isEmpty()) {
        const int delay = qEnvironmentVariableIntValue("FLAIRCODE_SNAPSHOT_DELAY");
        QTimer::singleShot(delay > 0 ? delay : 2500, &app, [&engine, snapshot] {
            if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
                window->grabWindow().save(snapshot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
