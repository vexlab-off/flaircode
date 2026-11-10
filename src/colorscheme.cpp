#include "colorscheme.h"

#include "settings.h"
#include "theme.h"

#include <QVariantMap>

using Palette = QHash<QString, QString>;

// The built-in schemes. Every one defines every role, so overrides are the
// only thing that ever mixes them.
static const QHash<QString, Palette> &presetPalettes() {
    static const QHash<QString, Palette> presets{
        {"braise",
         {{"background", "#15110e"}, {"text", "#ece3d9"}, {"gutter", "#15110e"}, {"gutterText", "#5c524a"},
          {"gutterActive", "#ece3d9"}, {"currentLine", "#1f1915"}, {"selection", "#5a3418"}, {"cursor", "#ff8a3d"},
          {"match", "#7a4a1d"}, {"keyword", "#ff8a3d"}, {"type", "#e6a3ff"}, {"function", "#7cc4ff"},
          {"string", "#b5d67a"}, {"number", "#f5b942"}, {"constant", "#ffb27a"}, {"comment", "#7a6d62"},
          {"operator", "#b8aa9c"}, {"tag", "#ff7a6b"}, {"attribute", "#f5b942"}, {"preprocessor", "#ff9f66"},
          {"heading", "#ff8a3d"}, {"emphasis", "#ece3d9"}, {"strong", "#ece3d9"}}},
        {"minuit",
         {{"background", "#0d1117"}, {"text", "#d6dbe4"}, {"gutter", "#0d1117"}, {"gutterText", "#4a5361"},
          {"gutterActive", "#d6dbe4"}, {"currentLine", "#151b24"}, {"selection", "#264066"}, {"cursor", "#6cb6ff"},
          {"match", "#3d4f1f"}, {"keyword", "#c49bff"}, {"type", "#4fd6c4"}, {"function", "#6cb6ff"},
          {"string", "#8fd6a0"}, {"number", "#ffb86b"}, {"constant", "#ff9e7a"}, {"comment", "#5c6675"},
          {"operator", "#9aa5b5"}, {"tag", "#ff7b8a"}, {"attribute", "#ffd479"}, {"preprocessor", "#c49bff"},
          {"heading", "#6cb6ff"}, {"emphasis", "#d6dbe4"}, {"strong", "#d6dbe4"}}},
        {"contraste",
         {{"background", "#000000"}, {"text", "#ffffff"}, {"gutter", "#000000"}, {"gutterText", "#8a8a8a"},
          {"gutterActive", "#ffffff"}, {"currentLine", "#141414"}, {"selection", "#1f4fa8"}, {"cursor", "#ffd400"},
          {"match", "#6b5a00"}, {"keyword", "#ffd400"}, {"type", "#5ce1ff"}, {"function", "#7db8ff"},
          {"string", "#7dff8a"}, {"number", "#ff9f40"}, {"constant", "#ff9f40"}, {"comment", "#a0a0a0"},
          {"operator", "#ffffff"}, {"tag", "#ff6b6b"}, {"attribute", "#ffd400"}, {"preprocessor", "#ff8cff"},
          {"heading", "#ffd400"}, {"emphasis", "#ffffff"}, {"strong", "#ffffff"}}},
        {"papier",
         {{"background", "#fbf8f3"}, {"text", "#2a2520"}, {"gutter", "#f4efe7"}, {"gutterText", "#a39a8e"},
          {"gutterActive", "#2a2520"}, {"currentLine", "#f1ebe1"}, {"selection", "#f6d2b5"}, {"cursor", "#c2410c"},
          {"match", "#fbe3a1"}, {"keyword", "#b4361a"}, {"type", "#7a3fb3"}, {"function", "#1f5fbf"},
          {"string", "#3d7a2f"}, {"number", "#9a5b00"}, {"constant", "#b04a00"}, {"comment", "#8a8278"},
          {"operator", "#5c544b"}, {"tag", "#b4361a"}, {"attribute", "#9a5b00"}, {"preprocessor", "#7a3fb3"},
          {"heading", "#b4361a"}, {"emphasis", "#2a2520"}, {"strong", "#2a2520"}}},
    };
    return presets;
}

ColorScheme::ColorScheme(Theme *theme, EditorSettings *settings, QObject *parent)
    : QObject(parent), m_theme(theme), m_settings(settings) {
    auto bump = [this] {
        ++m_revision;
        emit changed();
    };
    connect(theme, &Theme::changed, this, bump);
    connect(settings, &EditorSettings::changed, this, bump);
}

QStringList ColorScheme::presetKeys() { return {"vex", "braise", "minuit", "contraste", "papier"}; }

QString ColorScheme::scheme() const {
    const auto key = m_settings->value("appearance/scheme").toString();
    return presetKeys().contains(key) ? key : QString("vex");
}

QColor ColorScheme::fromPreset(const QString &scheme, const QString &role) const {
    if (scheme != "vex") {
        const auto value = presetPalettes().value(scheme).value(role);
        if (!value.isEmpty())
            return QColor(value);
    }
    // "vex": the live desktop theme.
    if (role == "background" || role == "gutter")
        return m_theme->background();
    if (role == "text" || role == "gutterActive" || role == "emphasis" || role == "strong")
        return m_theme->text();
    if (role == "gutterText")
        return m_theme->alpha(m_theme->textFaint(), 0.8);
    if (role == "currentLine")
        return m_theme->alpha(m_theme->text(), 0.035);
    if (role == "selection")
        return m_theme->alpha(m_theme->highlight(), 0.32);
    if (role == "cursor")
        return m_theme->highlight();
    if (role == "match")
        return m_theme->alpha(m_theme->warning(), 0.3);
    return m_theme->syntax(role);
}

QColor ColorScheme::presetColor(const QString &scheme, const QString &role) const { return fromPreset(scheme, role); }

QColor ColorScheme::color(const QString &role) const {
    // Overrides live under colors/<role> for the surface, syntax/<role> for code.
    for (const auto &group : {"colors/", "syntax/"}) {
        const QColor custom(m_settings->value(QString(group) + role).toString());
        if (custom.isValid())
            return custom;
    }
    return fromPreset(scheme(), role);
}

bool ColorScheme::bold(const QString &role) const {
    const auto style = m_settings->value("syntaxStyle/" + role).toString();
    if (!style.isEmpty())
        return style.contains("bold");
    return role == "heading" || role == "strong";
}

bool ColorScheme::italic(const QString &role) const {
    const auto style = m_settings->value("syntaxStyle/" + role).toString();
    if (!style.isEmpty())
        return style.contains("italic");
    return role == "comment" || role == "emphasis";
}

QVariantList ColorScheme::presets() const {
    return {
        QVariantMap{{"key", "vex"}, {"name", tr("Vex")}, {"description", tr("Suit le thème de ton bureau, en direct.")}},
        QVariantMap{{"key", "braise"}, {"name", tr("Braise")}, {"description", tr("Sombre et chaud, aux couleurs de flair.")}},
        QVariantMap{{"key", "minuit"}, {"name", tr("Minuit")}, {"description", tr("Sombre et froid, reposant le soir.")}},
        QVariantMap{{"key", "contraste"}, {"name", tr("Contraste")}, {"description", tr("Noir pur et couleurs franches, pour bien lire.")}},
        QVariantMap{{"key", "papier"}, {"name", tr("Papier")}, {"description", tr("Clair, pour la pleine lumière.")}}};
}

QVariantList ColorScheme::editorRoles() const {
    auto role = [](const QString &key, const QString &name, const QString &description) {
        return QVariantMap{{"key", key}, {"name", name}, {"description", description}};
    };
    return {role("background", tr("Fond de l'éditeur"), tr("La surface sur laquelle s'écrit le code.")),
            role("text", tr("Texte"), tr("Le texte qui n'a pas de couleur de syntaxe.")),
            role("gutter", tr("Marge des numéros"), tr("Le fond de la colonne des numéros de ligne.")),
            role("gutterText", tr("Numéros de ligne"), tr("Les numéros des autres lignes.")),
            role("gutterActive", tr("Numéro de la ligne courante"), tr("Le numéro de la ligne où est le curseur.")),
            role("currentLine", tr("Ligne courante"), tr("Le surlignage de la ligne du curseur.")),
            role("selection", tr("Sélection"), tr("Le fond du texte sélectionné.")),
            role("cursor", tr("Curseur"), tr("La barre clignotante.")),
            role("match", tr("Résultats de recherche"), tr("Le surlignage des occurrences trouvées."))};
}

QVariantList ColorScheme::syntaxRoles() const {
    auto role = [](const QString &key, const QString &name, const QString &sample) {
        return QVariantMap{{"key", key}, {"name", name}, {"sample", sample}};
    };
    return {role("keyword", tr("Mots-clés"), "if return class"),
            role("type", tr("Types et classes"), "QString Document"),
            role("function", tr("Fonctions et méthodes"), "save() open()"),
            role("string", tr("Chaînes de texte"), "\"bonjour\""),
            role("number", tr("Nombres"), "42 3.14 0xff"),
            role("constant", tr("Constantes"), "true null nullptr"),
            role("comment", tr("Commentaires"), "// note"),
            role("operator", tr("Opérateurs"), "+ - = =>"),
            role("preprocessor", tr("Directives et décorateurs"), "#include @property"),
            role("tag", tr("Balises HTML/XML"), "<div> </p>"),
            role("attribute", tr("Attributs et clés"), "class= \"key\":"),
            role("heading", tr("Titres Markdown"), "# Titre")};
}
