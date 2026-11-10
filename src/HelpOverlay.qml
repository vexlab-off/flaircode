import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// F1: everything there is to know, in four tabs — shortcuts, snippets for
// each language, how to use the AI, and tips.
Rectangle {
    id: overlay
    color: theme.alpha(theme.background, 0.9)
    property string tab: "keys"
    property string snippetLanguage: documents.currentDocument ? documents.currentDocument.language : "javascript"

    function show(which) {
        tab = which || "keys"
        if (documents.currentDocument && snippets.languages().indexOf(familyOf(documents.currentDocument.language)) >= 0)
            snippetLanguage = familyOf(documents.currentDocument.language)
        visible = true
    }
    function familyOf(language) {
        return language === "c" ? "cpp" : language === "typescript" ? "javascript" : language === "xml" ? "html" : language
    }

    MouseArea { anchors.fill: parent; onClicked: overlay.visible = false }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 980)
        height: Math.min(parent.height - 60, 720)
        radius: 16
        color: theme.surface
        border.color: theme.line
        MouseArea { anchors.fill: parent } // keep clicks inside

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Logo { size: 30 }
                Text { text: "Aide de Flair Code"; color: theme.text; font.pixelSize: 19; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [["keys", "Raccourcis"], ["snippets", "Snippets"], ["ai", "IA"], ["tips", "Astuces"]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: overlay.tab === modelData[0]
                        width: tabText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: active ? theme.highlight : theme.background
                        border.color: active ? theme.highlight : theme.line
                        Text { id: tabText; anchors.centerIn: parent; text: modelData[1]; color: parent.active ? theme.highlightText : theme.textDim; font.pixelSize: 12; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: overlay.tab = modelData[0] }
                    }
                }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: closeHover.containsMouse ? theme.raised : "transparent"
                    Icon { anchors.centerIn: parent; name: "close"; size: 14; color: theme.textDim }
                    MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; onClicked: overlay.visible = false }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }

            // ---------------------------------------------- shortcuts
            ScrollView {
                visible: overlay.tab === "keys"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 22
                    Repeater {
                        model: {
                            const groups = {}
                            for (const c of win.commands) if (c.shortcut) (groups[c.category] = groups[c.category] || []).push(c)
                            return Object.keys(groups).map(k => ({ title: k, items: groups[k] }))
                        }
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: modelData.title; color: theme.highlight; font.pixelSize: 13; font.weight: Font.Bold }
                            Repeater {
                                model: modelData.items
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Item { Layout.preferredWidth: 140; Layout.preferredHeight: 20; Keycap { anchors.verticalCenter: parent.verticalCenter; text: modelData.shortcut } }
                                    Text { Layout.fillWidth: true; text: modelData.name; color: theme.text; font.pixelSize: 12; elide: Text.ElideRight
                                        ToolTip.visible: tipArea.containsMouse; ToolTip.text: modelData.description
                                        MouseArea { id: tipArea; anchors.fill: parent; hoverEnabled: true } }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- snippets
            ColumnLayout {
                visible: overlay.tab === "snippets"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: "Tape le mot de gauche puis <b>Tab</b> : la structure complète apparaît, avec le premier élément à remplir sélectionné. Fonctionne aussi depuis la palette (Ctrl+Maj+P → « snippet »)."
                    textFormat: Text.StyledText
                    color: theme.textDim
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: snippets.languages()
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool active: overlay.snippetLanguage === modelData
                            width: langText.implicitWidth + 18
                            height: 26
                            radius: 13
                            color: active ? theme.alpha(theme.highlight, 0.16) : theme.background
                            border.color: active ? theme.highlight : theme.line
                            Text { id: langText; anchors.centerIn: parent; text: modelData; color: theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: overlay.snippetLanguage = modelData }
                        }
                    }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: snippets.forLanguage(overlay.snippetLanguage)
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: Math.max(48, preview.implicitHeight + 20)
                        radius: 8
                        color: theme.background
                        border.color: theme.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignTop
                                spacing: 4
                                Keycap { text: modelData.prefix + "  ⇥" }
                                Text { text: modelData.description; color: theme.textDim; font.pixelSize: 12 }
                            }
                            Text {
                                id: preview
                                Layout.fillWidth: true
                                text: modelData.preview
                                color: theme.text
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- AI
            ScrollView {
                visible: overlay.tab === "ai"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    Repeater {
                        model: [
                            ["Configurer", "Ctrl+, → IA : colle la clé de Claude, OpenAI ou Gemini, puis « Charger les modèles » et choisis-en un. Le modèle local (LM Studio, Ollama) ne demande pas de clé.", "Ctrl+,"],
                            ["Discuter avec ton code", "Ctrl+L ouvre l'assistant. Il voit le fichier ouvert et ta sélection. Pose ta question en français ; Entrée envoie, Maj+Entrée va à la ligne.", "Ctrl+L"],
                            ["Réécrire une sélection", "Sélectionne du code, Ctrl+K, décris le changement (« ajoute la gestion d'erreur »). L'avant et l'après s'affichent ; Ctrl+Entrée accepte, Échap annule. Sans sélection, Ctrl+K écrit du code au curseur.", "Ctrl+K"],
                            ["Actions en un clic", "Sous la conversation : Expliquer, Corriger, Documenter, Tests, Optimiser, Revue. Elles portent sur la sélection, ou sur tout le fichier sans sélection.", "Ctrl+Maj+P"],
                            ["Utiliser une réponse", "Chaque bloc de code de l'assistant a Copier, Insérer (au curseur) et Remplacer la sélection.", ""],
                            ["Changer de modèle", "Les pastilles en haut de l'assistant passent de Claude à OpenAI, Gemini ou local. Un point vert : prêt.", ""],
                            ["Confidentialité", "Le code envoyé part chez le fournisseur choisi. Pour du code privé, préfère le modèle local : rien ne quitte ta machine.", ""]
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 16
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                width: 32; height: 32; radius: 9
                                color: theme.alpha(theme.highlight, 0.14)
                                Icon { anchors.centerIn: parent; name: "sparkle"; size: 15; color: theme.highlight }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Text { text: modelData[0]; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
                                    Keycap { visible: modelData[2] !== ""; text: modelData[2] }
                                }
                                Text { Layout.fillWidth: true; text: modelData[1]; color: theme.textDim; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.2 }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- tips
            ScrollView {
                visible: overlay.tab === "tips"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 14
                    rowSpacing: 14
                    Repeater {
                        model: [
                            ["Tout retrouver", "Ctrl+Maj+P ouvre la palette : tape ce que tu veux faire (« commenter », « thème », « assistant »), même sans connaître le raccourci."],
                            ["Aller à une ligne", "Ctrl+G, ou « :42 » dans la palette."],
                            ["Déplacer des lignes", "Alt+↑ et Alt+↓ montent ou descendent la ligne, ou toutes les lignes sélectionnées."],
                            ["Dupliquer, supprimer", "Ctrl+Maj+D duplique la ligne, Ctrl+Maj+K la supprime."],
                            ["Entourer une sélection", "Sélectionne un mot et tape ( [ { ou \" : il est entouré au lieu d'être remplacé."],
                            ["Aperçu en direct", "Ctrl+Maj+V affiche le HTML, le SVG et le Markdown à côté du code, mis à jour à chaque frappe. Le curseur sur un chemin d'image (\"logo.png\") la montre."],
                            ["Images", "Un clic sur une image dans l'arborescence l'ouvre en aperçu, avec ses dimensions."],
                            ["Snippets", "for, if, class, fn, html, flex… puis Tab. La liste par langage est dans l'onglet Snippets."],
                            ["Couleurs", "Ctrl+, → Coloration syntaxique : une couleur et un style par élément. Les thèmes Braise, Minuit, Contraste et Papier sont dans Apparence."],
                            ["Fichier modifié ailleurs", "S'il n'a pas de changement en cours, il se recharge seul ; sinon un bandeau te laisse choisir."],
                            ["Projet Git", "Ouvrir un fichier ouvre tout son dépôt ; la branche s'affiche dans la barre d'état."],
                            ["Avec flair", "Dans flair, E ou le clic droit ouvrent un fichier ou un dossier directement dans Flair Code."]
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: tipColumn.implicitHeight + 24
                            radius: 10
                            color: theme.background
                            border.color: theme.line
                            ColumnLayout {
                                id: tipColumn
                                x: 14; y: 12
                                width: parent.width - 28
                                spacing: 4
                                Text { text: modelData[0]; color: theme.text; font.pixelSize: 13; font.weight: Font.Bold }
                                Text { Layout.fillWidth: true; text: modelData[1]; color: theme.textDim; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.2 }
                            }
                        }
                    }
                }
            }
        }
    }
}
