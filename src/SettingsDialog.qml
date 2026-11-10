import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Every setting, grouped, each with a sentence on what it changes. Changes
// apply as you make them, so you see the editor change behind the dialog.
Popup {
    id: dialog
    modal: true
    focus: true
    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 980)
    height: Math.min(parent.height - 40, 760)
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.alpha(theme.background, 0.6) }
    background: Rectangle { color: theme.surface; radius: 16; border.color: theme.line }

    property string section: "appearance"
    function openAt(name) { section = name || "appearance"; open() }
    function v(key) { return settings.revision, settings.value(key) }

    readonly property var sections: [
        { key: "appearance", label: "Apparence", icon: "eye" },
        { key: "editorColors", label: "Couleurs de l'éditeur", icon: "image" },
        { key: "syntax", label: "Coloration syntaxique", icon: "code" },
        { key: "editor", label: "Éditeur", icon: "texte" },
        { key: "help", label: "Aide à l'écriture", icon: "sparkle" },
        { key: "ai", label: "IA", icon: "chat" },
        { key: "keys", label: "Raccourcis", icon: "sliders" }
    ]
    readonly property var swatches: ["#ff8a3d", "#f5b942", "#f05252", "#ec5fa6", "#9b7bff", "#5c9df5", "#3ecf8e", "#4fd6c4",
                                     "#ffffff", "#d6dbe4", "#9aa5b5", "#5c6675", "#2a2520", "#15110e", "#0d1117", "#000000",
                                     "#ff7b8a", "#ffb86b", "#b5d67a", "#7cc4ff", "#c49bff", "#e6a3ff", "#ffd479", "#8fd6a0"]

    // ------------------------------------------------------------ pieces
    component Heading: ColumnLayout {
        property string title
        property string intro
        Layout.fillWidth: true
        spacing: 4
        Text { text: parent.title; color: theme.text; font.pixelSize: 20; font.weight: Font.Bold; font.letterSpacing: -0.3 }
        Text { Layout.fillWidth: true; text: parent.intro; color: theme.textDim; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.2; textFormat: Text.StyledText }
    }

    component Setting: RowLayout {
        id: setting
        property string label
        property string help
        default property alias control: holder.data
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: setting.label; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; visible: text !== ""; text: setting.help; color: theme.textDim; font.pixelSize: 12; wrapMode: Text.Wrap; textFormat: Text.StyledText }
        }
        Item {
            id: holder
            Layout.preferredWidth: Math.max(childrenRect.width, 10)
            Layout.preferredHeight: childrenRect.height
        }
    }

    component Toggle: Setting {
        id: toggle
        property string key
        Switch {
            Material.accent: theme.highlight
            checked: dialog.v(toggle.key)
            onToggled: settings.set(toggle.key, checked)
        }
    }

    // A colour: swatch, hex value, quick palette, reset.
    component ColorField: RowLayout {
        id: field
        property color current
        property bool custom: false
        signal picked(string color)
        signal reset()
        spacing: 6
        Rectangle {
            width: 28; height: 28; radius: 7
            color: field.current
            border.color: theme.line
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: quick.open() }
            Popup {
                id: quick
                y: parent.height + 6
                padding: 8
                background: Rectangle { color: theme.surface; radius: 10; border.color: theme.line }
                Grid {
                    columns: 8
                    spacing: 6
                    Repeater {
                        model: dialog.swatches
                        delegate: Rectangle {
                            required property string modelData
                            width: 22; height: 22; radius: 6
                            color: modelData
                            border.color: theme.line
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { field.picked(modelData); quick.close() } }
                        }
                    }
                }
            }
        }
        TextField {
            Layout.preferredWidth: 92
            text: field.current.toString().length > 7 && field.current.a < 1 ? field.current.toString() : field.current.toString().substring(0, 7)
            font.family: "monospace"
            font.pixelSize: 12
            onEditingFinished: if (/^#[0-9a-fA-F]{6}$/.test(text)) field.picked(text.toLowerCase())
        }
        Rectangle {
            width: 26; height: 26; radius: 6
            opacity: field.custom ? 1 : 0.25
            color: resetHover.containsMouse && field.custom ? theme.raised : "transparent"
            Icon { anchors.centerIn: parent; name: "refresh"; size: 13; color: theme.textDim }
            ToolTip.visible: resetHover.containsMouse && field.custom
            ToolTip.text: "Revenir à la couleur du thème"
            MouseArea { id: resetHover; anchors.fill: parent; hoverEnabled: true; enabled: field.custom; onClicked: field.reset() }
        }
    }

    component Divider: Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; height: 1; color: theme.line }

    // ------------------------------------------------------------ layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Navigation
        Rectangle {
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            color: theme.sidebar
            radius: 16
            Rectangle { anchors.right: parent.right; width: 16; height: parent.height; color: theme.sidebar }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 2
                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 4
                    spacing: 10
                    Logo { size: 28 }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "Réglages"; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold }
                        Text { text: "Flair Code"; color: theme.textFaint; font.pixelSize: 11 }
                    }
                }
                Repeater {
                    model: dialog.sections
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: dialog.section === modelData.key
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: active ? theme.alpha(theme.highlight, 0.14) : (navHover.containsMouse ? theme.alpha(theme.text, 0.04) : "transparent")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 10
                            Icon { name: modelData.icon; size: 15; color: parent.parent.active ? theme.highlight : theme.textDim }
                            Text { Layout.fillWidth: true; text: modelData.label; color: parent.parent.active ? theme.text : theme.textDim; font.pixelSize: 13; font.weight: parent.parent.active ? Font.DemiBold : Font.Normal }
                        }
                        MouseArea { id: navHover; anchors.fill: parent; hoverEnabled: true; onClicked: { dialog.section = modelData.key; scroller.contentItem.contentY = 0 } }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: "Les changements s'appliquent tout de suite."
                    color: theme.textFaint
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
                Button { Layout.fillWidth: true; text: "Fermer"; flat: true; onClicked: dialog.close() }
            }
        }

        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                x: 28
                width: scroller.availableWidth - 56
                spacing: 18

                Item { height: 10 }

                // ---------------------------------------------- appearance
                ColumnLayout {
                    visible: dialog.section === "appearance"
                    Layout.fillWidth: true
                    spacing: 18
                    Heading { title: "Apparence"; intro: "Le thème des couleurs du code et la couleur d'accent de l'interface (onglet actif, curseur, boutons, logo)." }

                    Setting {
                        label: "Mode"
                        help: "Clair ou sombre pour toute l'interface. « Comme flair » suit le réglage de flair ; « Automatique » suit Vex. Le thème « Vex » de l'éditeur s'adapte aussi."
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [["flair", "Comme flair", "sparkle"], ["auto", "Automatique", "refresh"], ["light", "Clair", "sun"], ["dark", "Sombre", "moon"]]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool chosen: dialog.v("appearance/mode") === modelData[0]
                                width: modeRow.implicitWidth + 24; height: 34; radius: 17
                                color: chosen ? theme.alpha(theme.highlight, 0.16) : theme.background
                                border.color: chosen ? theme.highlight : theme.line
                                Row { id: modeRow; anchors.centerIn: parent; spacing: 8
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData[2]; size: 15; color: parent.parent.chosen ? theme.highlight : theme.textDim }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: theme.text; font.pixelSize: 12 } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.set("appearance/mode", modelData[0]) }
                            }
                        }
                    }
                    Divider {}
                    Text { text: "Thème de l'éditeur"; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 10
                        rowSpacing: 10
                        Repeater {
                            model: scheme.presets()
                            delegate: Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool chosen: (scheme.revision, scheme.scheme) === modelData.key
                                Layout.fillWidth: true
                                Layout.preferredHeight: 128
                                radius: 10
                                color: (scheme.revision, scheme.presetColor(modelData.key, "background"))
                                border.color: chosen ? theme.highlight : theme.line
                                border.width: chosen ? 2 : 1
                                Column {
                                    x: 12; y: 12
                                    spacing: 3
                                    Repeater {
                                        model: [[["keyword", "function "], ["function", "save"], ["text", "() {"]],
                                                [["text", "  "], ["keyword", "return "], ["string", "\"ok\""], ["text", ";"]],
                                                [["comment", "  // " + modelData.name.toLowerCase()]], [["text", "}"]]]
                                        delegate: Row {
                                            required property var modelData
                                            Repeater {
                                                model: parent.modelData
                                                delegate: Text {
                                                    required property var modelData
                                                    text: modelData[1]
                                                    font.family: "monospace"
                                                    font.pixelSize: 11
                                                    color: (scheme.revision, scheme.presetColor(card.modelData.key, modelData[0]))
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 38
                                    radius: 10
                                    color: theme.alpha(theme.background, 0.85)
                                    Column {
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: modelData.name; color: theme.text; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        Text { text: modelData.description; color: theme.textDim; font.pixelSize: 10 }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.set("appearance/scheme", modelData.key) }
                            }
                        }
                    }

                    Divider {}
                    Setting {
                        label: "Couleur d'accent"
                        help: "« Comme flair » reprend la couleur choisie dans les réglages de flair et change avec elle. Sinon, choisis-en une pour Flair Code seul."
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            readonly property bool chosen: dialog.v("appearance/accent") === "flair"
                            width: flairRow.implicitWidth + 20; height: 32; radius: 16
                            color: chosen ? theme.alpha(theme.highlight, 0.16) : theme.background
                            border.color: chosen ? theme.highlight : theme.line
                            Row { id: flairRow; anchors.centerIn: parent; spacing: 8
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "sparkle"; size: 14; color: theme.highlight }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Comme flair"; color: theme.text; font.pixelSize: 12 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.set("appearance/accent", "flair") }
                        }
                        Repeater {
                            model: [["Orange", "#ff8a3d"], ["Ambre", "#f5b942"], ["Rouge", "#f05252"], ["Rose", "#ec5fa6"], ["Violet", "#9b7bff"], ["Bleu", "#5c9df5"], ["Vert", "#3ecf8e"], ["Turquoise", "#4fd6c4"]]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool chosen: dialog.v("appearance/accent") === modelData[1]
                                width: swRow.implicitWidth + 20; height: 32; radius: 16
                                color: chosen ? theme.alpha(modelData[1], 0.16) : theme.background
                                border.color: chosen ? modelData[1] : theme.line
                                Row { id: swRow; anchors.centerIn: parent; spacing: 8
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: modelData[1] }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: theme.text; font.pixelSize: 12 } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.set("appearance/accent", modelData[1]) }
                            }
                        }
                    }
                }

                // ---------------------------------------------- editor colours
                ColumnLayout {
                    visible: dialog.section === "editorColors"
                    Layout.fillWidth: true
                    spacing: 16
                    Heading { title: "Couleurs de l'éditeur"; intro: "Chaque partie de la surface d'écriture. Par défaut, elles viennent du thème choisi dans Apparence ; une couleur changée ici le remplace, et ↺ la remet." }
                    Repeater {
                        model: scheme.editorRoles()
                        delegate: Setting {
                            required property var modelData
                            label: modelData.name
                            help: modelData.description
                            ColorField {
                                current: (scheme.revision, scheme.color(modelData.key))
                                custom: (settings.revision, settings.isCustom("colors/" + modelData.key))
                                onPicked: (c) => settings.set("colors/" + modelData.key, c)
                                onReset: settings.reset("colors/" + modelData.key)
                            }
                        }
                    }
                    Button { text: "Tout remettre aux couleurs du thème"; flat: true; onClicked: settings.resetGroup("colors") }
                }

                // ---------------------------------------------- syntax colours
                ColumnLayout {
                    visible: dialog.section === "syntax"
                    Layout.fillWidth: true
                    spacing: 14
                    Heading { title: "Coloration syntaxique"; intro: "Une couleur et un style pour chaque élément du code, dans tous les langages. <b>G</b> met en gras, <i>I</i> en italique." }
                    Repeater {
                        model: scheme.syntaxRoles()
                        delegate: RowLayout {
                            id: roleRow
                            required property var modelData
                            readonly property string styleKey: "syntaxStyle/" + modelData.key
                            readonly property bool isBold: (scheme.revision, scheme.bold(modelData.key))
                            readonly property bool isItalic: (scheme.revision, scheme.italic(modelData.key))
                            Layout.fillWidth: true
                            spacing: 14
                            ColumnLayout {
                                Layout.preferredWidth: 260
                                spacing: 2
                                Text { text: roleRow.modelData.name; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text {
                                    text: roleRow.modelData.sample
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: roleRow.isBold
                                    font.italic: roleRow.isItalic
                                    color: (scheme.revision, scheme.color(roleRow.modelData.key))
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: [["G", "bold"], ["I", "italic"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool on: modelData[1] === "bold" ? roleRow.isBold : roleRow.isItalic
                                    width: 26; height: 26; radius: 6
                                    color: on ? theme.alpha(theme.highlight, 0.18) : theme.background
                                    border.color: on ? theme.highlight : theme.line
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData[0]
                                        color: parent.on ? theme.highlight : theme.textDim
                                        font.bold: modelData[1] === "bold"
                                        font.italic: modelData[1] === "italic"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const bold = modelData[1] === "bold" ? !roleRow.isBold : roleRow.isBold
                                            const italic = modelData[1] === "italic" ? !roleRow.isItalic : roleRow.isItalic
                                            settings.set(roleRow.styleKey, bold && italic ? "bold-italic" : bold ? "bold" : italic ? "italic" : "normal")
                                        }
                                    }
                                }
                            }
                            ColorField {
                                current: (scheme.revision, scheme.color(roleRow.modelData.key))
                                custom: (settings.revision, settings.isCustom("syntax/" + roleRow.modelData.key) || settings.isCustom(roleRow.styleKey))
                                onPicked: (c) => settings.set("syntax/" + roleRow.modelData.key, c)
                                onReset: { settings.reset("syntax/" + roleRow.modelData.key); settings.reset(roleRow.styleKey) }
                            }
                        }
                    }
                    RowLayout {
                        Button { text: "Tout remettre au thème"; flat: true; onClicked: { settings.resetGroup("syntax"); settings.resetGroup("syntaxStyle") } }
                    }
                }

                // ---------------------------------------------- editor
                ColumnLayout {
                    visible: dialog.section === "editor"
                    Layout.fillWidth: true
                    spacing: 16
                    Heading { title: "Éditeur"; intro: "Le texte, l'indentation et ce qui s'affiche autour du code." }
                    Setting {
                        label: "Police du code"
                        help: "Les polices à chasse fixe installées. « Automatique » prend la première police de code disponible."
                        ComboBox {
                            width: 260
                            readonly property var fonts: ["Automatique"].concat(Qt.fontFamilies().filter(f => /mono|code|courier|consol|hack|iosevka|fira|jetbrains|source code|menlo|cascadia/i.test(f)))
                            model: fonts
                            currentIndex: Math.max(0, fonts.indexOf(dialog.v("editor/fontFamily")))
                            onActivated: (i) => settings.set("editor/fontFamily", i === 0 ? "" : fonts[i])
                        }
                    }
                    Setting {
                        label: "Taille du texte"
                        help: "Aussi avec Ctrl+= et Ctrl+- dans l'éditeur, Ctrl+0 pour revenir à 14."
                        RowLayout {
                            Slider { from: 9; to: 32; stepSize: 1; value: dialog.v("editor/fontSize"); Material.accent: theme.highlight; onMoved: settings.set("editor/fontSize", Math.round(value)) }
                            Text { text: dialog.v("editor/fontSize") + " px"; color: theme.text; font.pixelSize: 12; Layout.preferredWidth: 40 }
                        }
                    }
                    Setting {
                        label: "Largeur d'indentation"
                        help: "Le nombre d'espaces d'un niveau d'indentation (Tab, Maj+Tab, indentation automatique)."
                        SpinBox { from: 1; to: 8; value: dialog.v("editor/tabWidth"); onValueModified: settings.set("editor/tabWidth", value) }
                    }
                    Toggle { key: "editor/insertSpaces"; label: "Indenter avec des espaces"; help: "Désactivé, Tab insère un vrai caractère de tabulation (utile pour les Makefile et le Go)." }
                    Divider {}
                    Toggle { key: "editor/lineNumbers"; label: "Numéros de ligne"; help: "La colonne des numéros à gauche du code. Masquée quand le retour à la ligne est actif." }
                    Toggle { key: "editor/highlightLine"; label: "Surligner la ligne courante"; help: "Un léger fond sur la ligne du curseur, pour ne pas la perdre." }
                    Toggle { key: "editor/wordWrap"; label: "Retour à la ligne automatique"; help: "Les lignes longues continuent sur la ligne suivante au lieu de défiler à droite." }
                    Toggle { key: "editor/cursorBlink"; label: "Curseur clignotant"; help: "Désactivé, le curseur reste fixe." }
                }

                // ---------------------------------------------- writing help
                ColumnLayout {
                    visible: dialog.section === "help"
                    Layout.fillWidth: true
                    spacing: 16
                    Heading { title: "Aide à l'écriture"; intro: "Ce que l'éditeur fait pour toi pendant que tu tapes." }
                    Toggle { key: "editor/autoIndent"; label: "Indentation automatique"; help: "Entrée garde l'indentation de la ligne, et ajoute un niveau après { [ ( ou :." }
                    Toggle { key: "editor/autoClose"; label: "Fermer les parenthèses et guillemets"; help: "Taper ( [ { \" ' ajoute aussitôt la fermeture. Avec une sélection, l'entoure. Retour arrière supprime la paire vide." }
                    Toggle { key: "editor/snippets"; label: "Snippets avec Tab"; help: "Tape un mot court puis Tab pour obtenir une structure complète (for, if, class, fn, html…). La liste complète est dans l'aide (F1 → Snippets)." }
                    Divider {}
                    Toggle { key: "editor/autoSave"; label: "Enregistrement automatique"; help: "Enregistre le fichier une seconde après ta dernière frappe." }
                    Toggle { key: "editor/trimTrailing"; label: "Supprimer les espaces en fin de ligne"; help: "À l'enregistrement, retire les espaces invisibles laissés en bout de ligne." }
                    Toggle { key: "editor/finalNewline"; label: "Terminer par une ligne vide"; help: "À l'enregistrement, garantit un saut de ligne final, comme l'attendent Git et la plupart des outils." }
                }

                // ---------------------------------------------- AI
                ColumnLayout {
                    visible: dialog.section === "ai"
                    Layout.fillWidth: true
                    spacing: 16
                    Heading {
                        title: "IA"
                        intro: "L'assistant (Ctrl+L), la réécriture d'une sélection (Ctrl+K) et les actions rapides. Chaque fournisseur demande sa clé, sauf le modèle local. Le code envoyé part chez le fournisseur choisi ; avec le modèle local, rien ne quitte ta machine."
                    }
                    Setting {
                        label: "Fournisseur par défaut"
                        help: "Utilisé par l'assistant et Ctrl+K. Tu peux en changer à tout moment en haut du panneau de l'assistant."
                        ComboBox {
                            width: 200
                            readonly property var keys: ["claude", "openai", "gemini", "local"]
                            model: ["Claude", "OpenAI", "Gemini", "Local (LM Studio / Ollama)"]
                            currentIndex: Math.max(0, keys.indexOf(dialog.v("ai/provider")))
                            onActivated: (i) => settings.set("ai/provider", keys[i])
                        }
                    }
                    Toggle { key: "ai/includeFile"; label: "Joindre le fichier ouvert"; help: "L'assistant reçoit le fichier entier en plus de ta sélection, pour mieux comprendre le contexte (les très gros fichiers sont tronqués)." }

                    Repeater {
                        model: [
                            { key: "claude", name: "Claude (Anthropic)", model: "ai/claudeModel", where: "console.anthropic.com → API Keys", env: "ANTHROPIC_API_KEY" },
                            { key: "openai", name: "OpenAI", model: "ai/openaiModel", where: "platform.openai.com → API keys", env: "OPENAI_API_KEY" },
                            { key: "gemini", name: "Gemini (Google)", model: "ai/geminiModel", where: "aistudio.google.com → Get API key", env: "GEMINI_API_KEY" }
                        ]
                        delegate: Rectangle {
                            id: provider
                            required property var modelData
                            property var models: []
                            property string loadError: ""
                            readonly property bool fromEnv: (settings.revision, settings.keyFromEnvironment(modelData.key))
                            Layout.fillWidth: true
                            implicitHeight: providerColumn.implicitHeight + 28
                            radius: 12
                            color: theme.background
                            border.color: theme.line
                            Connections {
                                target: assistant
                                function onModelsLoaded(key, list, error) {
                                    if (key !== provider.modelData.key) return
                                    provider.models = list
                                    provider.loadError = error
                                }
                            }
                            ColumnLayout {
                                id: providerColumn
                                x: 16; y: 14
                                width: parent.width - 32
                                spacing: 10
                                RowLayout {
                                    Rectangle { width: 8; height: 8; radius: 4; color: (settings.revision, settings.apiKey(provider.modelData.key)) ? theme.success : theme.textFaint }
                                    Text { text: provider.modelData.name; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: provider.fromEnv ? "Clé fournie par la variable " + provider.modelData.env + "."
                                                           : "Crée une clé sur <b>" + provider.modelData.where + "</b>, puis colle-la ici. Elle reste sur ta machine (fichier lisible par toi seul)."
                                    color: theme.textDim
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    textFormat: Text.StyledText
                                }
                                TextField {
                                    Layout.fillWidth: true
                                    visible: !provider.fromEnv
                                    echoMode: TextInput.Password
                                    placeholderText: provider.modelData.key === "claude" ? "sk-ant-… (ou celle de flair)" : "Clé API"
                                    text: (settings.revision, settings.value("keys/" + provider.modelData.key) || "")
                                    onEditingFinished: settings.set("keys/" + provider.modelData.key, text.trim())
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "Modèle"; color: theme.text; font.pixelSize: 12; Layout.preferredWidth: 60 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        editable: true
                                        model: provider.models
                                        editText: (settings.revision, settings.value(provider.modelData.model))
                                        onAccepted: settings.set(provider.modelData.model, editText.trim())
                                        onActivated: settings.set(provider.modelData.model, currentText)
                                    }
                                    Button { text: "Charger les modèles"; flat: true; onClicked: { provider.loadError = ""; assistant.loadModels(provider.modelData.key) } }
                                }
                                Text {
                                    visible: provider.loadError !== "" || provider.models.length > 0
                                    Layout.fillWidth: true
                                    text: provider.loadError || (provider.models.length + " modèles disponibles : choisis-en un dans la liste.")
                                    color: provider.loadError ? theme.danger : theme.textDim
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: localColumn.implicitHeight + 28
                        radius: 12
                        color: theme.background
                        border.color: theme.line
                        property var models: []
                        id: localBox
                        Connections {
                            target: assistant
                            function onModelsLoaded(key, list, error) { if (key === "local") localBox.models = list }
                        }
                        ColumnLayout {
                            id: localColumn
                            x: 16; y: 14
                            width: parent.width - 32
                            spacing: 10
                            Text { text: "Local (LM Studio, Ollama)"; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
                            Text {
                                Layout.fillWidth: true
                                text: "Un modèle qui tourne sur ta machine : gratuit et privé, plus lent. LM Studio : <b>http://localhost:1234</b> ; Ollama : <b>http://localhost:11434</b>."
                                color: theme.textDim; font.pixelSize: 12; wrapMode: Text.Wrap; textFormat: Text.StyledText
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: dialog.v("ai/localUrl")
                                onEditingFinished: settings.set("ai/localUrl", text.trim())
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Modèle"; color: theme.text; font.pixelSize: 12; Layout.preferredWidth: 60 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    editable: true
                                    model: localBox.models
                                    editText: dialog.v("ai/localModel")
                                    onAccepted: settings.set("ai/localModel", editText.trim())
                                    onActivated: settings.set("ai/localModel", currentText)
                                }
                                Button { text: "Charger les modèles"; flat: true; onClicked: assistant.loadModels("local") }
                            }
                        }
                    }
                }

                // ---------------------------------------------- shortcuts
                ColumnLayout {
                    visible: dialog.section === "keys"
                    Layout.fillWidth: true
                    spacing: 10
                    Heading { title: "Raccourcis"; intro: "Tous les raccourcis de Flair Code. La palette de commandes (Ctrl+Maj+P) les retrouve aussi par leur nom." }
                    Repeater {
                        model: win.commands.filter(c => c.shortcut)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12
                            Item { Layout.preferredWidth: 170; Layout.preferredHeight: 22; Keycap { anchors.verticalCenter: parent.verticalCenter; text: modelData.shortcut } }
                            Text { text: modelData.name; color: theme.text; font.pixelSize: 12; Layout.preferredWidth: 240 }
                            Text { Layout.fillWidth: true; text: modelData.description; color: theme.textDim; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                    }
                }

                Item { height: 20 }
            }
        }
    }
}
