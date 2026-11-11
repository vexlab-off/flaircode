#include "settings.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>

EditorSettings::EditorSettings(const QString &file, QObject *parent)
    : QObject(parent),
      m_settings(file.isEmpty() ? QDir::homePath() + "/.config/flaircode/flaircode.conf" : file, QSettings::IniFormat) {
    // flair may change the suite's colours at any time; views re-read them.
    const auto suite = suiteFile();
    QDir().mkpath(QFileInfo(suite).absolutePath());
    m_suiteWatcher.addPath(QFileInfo(suite).absolutePath());
    if (QFileInfo::exists(suite))
        m_suiteWatcher.addPath(suite);
    auto bump = [this, suite] {
        if (QFileInfo::exists(suite) && !m_suiteWatcher.files().contains(suite))
            m_suiteWatcher.addPath(suite);
        ++m_revision;
        emit changed();
    };
    connect(&m_suiteWatcher, &QFileSystemWatcher::fileChanged, this, bump);
    connect(&m_suiteWatcher, &QFileSystemWatcher::directoryChanged, this, bump);
}

QString EditorSettings::suiteFile() { return QDir::homePath() + "/.config/flair/flair.conf"; }

QString EditorSettings::suiteValue(const QString &key, const QString &fallback) const {
    QSettings suite(suiteFile(), QSettings::IniFormat);
    const auto value = suite.value(key).toString().trimmed();
    return value.isEmpty() ? fallback : value;
}

void EditorSettings::setSuiteValue(const QString &key, const QString &value) {
    QSettings suite(suiteFile(), QSettings::IniFormat);
    suite.setValue(key, value);
    suite.sync();
    QFile::setPermissions(suite.fileName(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    ++m_revision;
    emit changed();
}

bool EditorSettings::suiteSync() const { return suiteValue("appearance/sync", "true") == "true"; }
void EditorSettings::setSuiteSync(bool sync) { setSuiteValue("appearance/sync", sync ? "true" : "false"); }

QVariant EditorSettings::defaultValue(const QString &key) {
    static const QHash<QString, QVariant> defaults{
        // Appearance
        {"appearance/scheme", "vex"},
        {"appearance/accent", "flair"}, // "flair" follows flair's accent, else #rrggbb
        {"appearance/mode", "flair"},   // "flair", "auto", "light" or "dark"
        // Editor
        {"editor/fontFamily", ""}, // empty: first coding font installed
        {"editor/fontSize", 14},
        {"editor/lineHeight", 1.0},
        {"editor/tabWidth", 4},
        {"editor/insertSpaces", true},
        {"editor/lineNumbers", true},
        {"editor/highlightLine", true},
        {"editor/wordWrap", false},
        {"editor/autoIndent", true},
        {"editor/autoClose", true},
        {"editor/snippets", true},
        {"editor/autoSave", false},
        {"editor/trimTrailing", false},
        {"editor/finalNewline", true},
        {"editor/cursorBlink", true},
        {"editor/minimap", false},
        // AI
        {"ai/provider", "claude"},
        {"ai/claudeModel", "claude-opus-5-5"},
        {"ai/openaiModel", ""},
        {"ai/geminiModel", ""},
        {"ai/localUrl", "http://localhost:1234"},
        {"ai/localModel", ""},
        {"ai/inlineProvider", "same"},
        {"ai/includeFile", true},
        {"ai/language", "fr"},
    };
    return defaults.value(key);
}

QVariant EditorSettings::value(const QString &key) const {
    const auto stored = m_settings.value(key);
    return stored.isValid() ? stored : defaultValue(key);
}

void EditorSettings::set(const QString &key, const QVariant &value) {
    if (m_settings.value(key) == value)
        return;
    // Storing the default keeps the file tidy and lets defaults improve later.
    if (value == defaultValue(key))
        m_settings.remove(key);
    else
        m_settings.setValue(key, value);
    m_settings.sync();
    QFile::setPermissions(m_settings.fileName(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    ++m_revision;
    emit changed();
}

void EditorSettings::reset(const QString &key) {
    if (!m_settings.contains(key))
        return;
    m_settings.remove(key);
    m_settings.sync();
    ++m_revision;
    emit changed();
}

void EditorSettings::resetGroup(const QString &group) {
    m_settings.beginGroup(group);
    m_settings.remove("");
    m_settings.endGroup();
    m_settings.sync();
    ++m_revision;
    emit changed();
}

bool EditorSettings::isCustom(const QString &key) const { return m_settings.contains(key); }

QString EditorSettings::environmentVariableFor(const QString &provider) {
    if (provider == "claude")
        return "ANTHROPIC_API_KEY";
    if (provider == "openai")
        return "OPENAI_API_KEY";
    if (provider == "gemini")
        return "GEMINI_API_KEY";
    return {};
}

bool EditorSettings::keyFromEnvironment(const QString &provider) const {
    const auto variable = environmentVariableFor(provider);
    return !variable.isEmpty() && !qEnvironmentVariable(variable.toUtf8()).trimmed().isEmpty();
}

QString EditorSettings::apiKey(const QString &provider) const {
    const auto variable = environmentVariableFor(provider);
    if (variable.isEmpty())
        return {};
    const auto env = qEnvironmentVariable(variable.toUtf8()).trimmed();
    if (!env.isEmpty())
        return env;
    if (provider == "gemini") {
        const auto google = qEnvironmentVariable("GOOGLE_API_KEY").trimmed();
        if (!google.isEmpty())
            return google;
    }
    const auto own = m_settings.value("keys/" + provider).toString().trimmed();
    if (!own.isEmpty())
        return own;
    if (provider == "claude") {
        QSettings flair(QDir::homePath() + "/.config/flair/flair.conf", QSettings::IniFormat);
        return flair.value("claude/apiKey").toString().trimmed();
    }
    return {};
}
