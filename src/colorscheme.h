#pragma once

#include <QColor>
#include <QHash>
#include <QObject>
#include <QVariantList>

class EditorSettings;
class Theme;

// The editor's colours: a preset (Vex, or one of the built-in schemes) with
// the user's per-role overrides on top. Covers both the editor surface
// (background, gutter, selection…) and every syntax role.
class ColorScheme : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QString scheme READ scheme NOTIFY changed)

public:
    ColorScheme(Theme *theme, EditorSettings *settings, QObject *parent = nullptr);

    int revision() const { return m_revision; }
    QString scheme() const;

    // Final colour for an editor or syntax role, overrides applied.
    Q_INVOKABLE QColor color(const QString &role) const;
    Q_INVOKABLE bool bold(const QString &role) const;
    Q_INVOKABLE bool italic(const QString &role) const;
    // The preset's own colour, for previews and "reset" hints.
    Q_INVOKABLE QColor presetColor(const QString &scheme, const QString &role) const;
    // [{key, name, description}] for the settings.
    Q_INVOKABLE QVariantList presets() const;
    // [{key, name, description, sample}] — editor surface roles.
    Q_INVOKABLE QVariantList editorRoles() const;
    // [{key, name, description, sample}] — syntax roles.
    Q_INVOKABLE QVariantList syntaxRoles() const;

    static QStringList presetKeys();

signals:
    void changed();

private:
    QColor fromPreset(const QString &scheme, const QString &role) const;

    Theme *m_theme;
    EditorSettings *m_settings;
    int m_revision = 0;
};
