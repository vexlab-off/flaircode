#pragma once

#include <QObject>
#include <QSettings>
#include <QVariantMap>

// Everything the user can tune in Flair Code, stored in
// ~/.config/flaircode/flaircode.conf (mode 0600: it can hold API keys).
// Values are read through value()/set() so QML can bind to any key, and a
// single changed() signal tells views to re-read.
class EditorSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    explicit EditorSettings(const QString &file = {}, QObject *parent = nullptr);

    int revision() const { return m_revision; }

    Q_INVOKABLE QVariant value(const QString &key) const;
    Q_INVOKABLE void set(const QString &key, const QVariant &value);
    Q_INVOKABLE void reset(const QString &key);
    // Removes every key under a group ("colors", "syntax"…), back to defaults.
    Q_INVOKABLE void resetGroup(const QString &group);
    Q_INVOKABLE bool isCustom(const QString &key) const;

    // API key for a provider: the environment wins, then this app's settings,
    // then flair's (so a key entered in flair works here too).
    Q_INVOKABLE QString apiKey(const QString &provider) const;
    Q_INVOKABLE bool keyFromEnvironment(const QString &provider) const;
    static QString environmentVariableFor(const QString &provider);

    static QVariant defaultValue(const QString &key);

signals:
    void changed();

private:
    QSettings m_settings;
    int m_revision = 0;
};
