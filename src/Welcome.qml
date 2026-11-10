import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// What shows with no file open: start something, or pick up where you were.
Rectangle {
    color: theme.background

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        spacing: 0

        RowLayout {
            spacing: 18
            Logo { size: 64 }
            ColumnLayout {
                spacing: 2
                Text { text: "Flair Code"; color: theme.text; font.pixelSize: 34; font.weight: Font.Bold; font.letterSpacing: -0.8 }
                Text { text: "L'éditeur de code de la suite flair."; color: theme.textDim; font.pixelSize: 14 }
            }
        }

        // With a project open but no file, point at the ways to open one.
        ColumnLayout {
            visible: workspace.root !== ""
            Layout.topMargin: 36
            spacing: 10
            Text { text: workspace.name; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            Repeater {
                model: [["Ctrl+P", "Aller à un fichier"], ["Ctrl+N", "Nouveau fichier"], ["Ctrl+Maj+P", "Toutes les commandes, par leur nom"],
                        ["Ctrl+L", "Assistant IA (Claude, OpenAI, Gemini, local)"], ["Ctrl+K", "Réécrire une sélection avec l'IA"],
                        ["Ctrl+Maj+V", "Aperçu en direct (HTML, SVG, Markdown, images)"], ["Ctrl+,", "Réglages et couleurs"], ["F1", "Aide, snippets et astuces"]]
                delegate: RowLayout {
                    required property var modelData
                    spacing: 12
                    Item { Layout.preferredWidth: 70; Layout.preferredHeight: 20; Keycap { anchors.verticalCenter: parent.verticalCenter; text: modelData[0] } }
                    Text { text: modelData[1]; color: theme.textDim; font.pixelSize: 13 }
                }
            }
        }

        // No project yet.
        ColumnLayout {
            visible: workspace.root === ""
            Layout.topMargin: 36
            Layout.fillWidth: true
            spacing: 10
            RowLayout {
                spacing: 10
                PrimaryButton {
                    text: "Ouvrir un dossier"
                    onClicked: workspace.pickFolder()
                }
                Button { text: "Ouvrir un chemin…"; flat: true; onClicked: prompt.ask("path") }
                Keycap { text: "Ctrl+O" }
                Keycap { text: "Ctrl+Maj+O" }
            }
            Text {
                visible: workspace.recent.length > 0
                Layout.topMargin: 24
                text: "Récents"
                color: theme.textDim
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Repeater {
                model: workspace.recent
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: recentHover.containsMouse ? theme.surface : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12
                        Icon { name: "folder"; size: 17; color: theme.kindColor("dossier") }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: modelData.substring(modelData.lastIndexOf("/") + 1); color: theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            Text { Layout.fillWidth: true; text: modelData; color: theme.textFaint; font.pixelSize: 11; elide: Text.ElideMiddle }
                        }
                    }
                    MouseArea { id: recentHover; anchors.fill: parent; hoverEnabled: true; onClicked: win.openFolder(modelData) }
                }
            }
        }
    }
}
