import QtQuick
import QtQuick.Layouts

// Every shortcut, shown with F1.
Rectangle {
    id: overlay
    color: theme.alpha(theme.background, 0.88)

    readonly property var groups: [
        { title: "Fichiers", icon: "file", keys: [
            ["Ctrl+O", "Ouvrir un dossier"], ["Ctrl+L", "Ouvrir un chemin"], ["Ctrl+P", "Aller à un fichier"],
            ["Ctrl+N", "Nouveau fichier"], ["Ctrl+S", "Enregistrer"], ["Ctrl+Maj+S", "Tout enregistrer"],
            ["Ctrl+W", "Fermer l'onglet"], ["Ctrl+Tab", "Onglet suivant"]
        ]},
        { title: "Édition", icon: "code", keys: [
            ["Ctrl+Z  ·  Ctrl+Maj+Z", "Annuler  ·  rétablir"], ["Tab  ·  Maj+Tab", "Indenter  ·  désindenter"],
            ["Ctrl+/  ·  Ctrl+:", "Commenter les lignes"], ["Ctrl+F", "Rechercher"], ["Ctrl+H", "Remplacer"],
            ["F3  ·  Maj+F3", "Résultat suivant  ·  précédent"]
        ]},
        { title: "Affichage", icon: "eye", keys: [
            ["Ctrl+B", "Arborescence"], ["Ctrl+= · Ctrl+-", "Taille du texte"], ["Ctrl+0", "Taille par défaut"],
            ["F1", "Cette aide"], ["Ctrl+Q", "Quitter"]
        ]}
    ]

    MouseArea { anchors.fill: parent; onClicked: overlay.visible = false }

    Rectangle {
        anchors.centerIn: parent
        width: grid.implicitWidth + 64
        height: grid.implicitHeight + 64
        radius: 16
        color: theme.surface
        border.color: theme.line
        GridLayout {
            id: grid
            anchors.centerIn: parent
            columns: 3
            columnSpacing: 48
            Repeater {
                model: overlay.groups
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Icon { name: modelData.icon; size: 16; color: theme.highlight }
                        Text { text: modelData.title; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
                    }
                    Repeater {
                        model: modelData.keys
                        delegate: RowLayout {
                            required property var modelData
                            spacing: 12
                            Item { Layout.preferredWidth: 150; Layout.preferredHeight: 20; Keycap { anchors.verticalCenter: parent.verticalCenter; text: modelData[0] } }
                            Text { text: modelData[1]; color: theme.textDim; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
