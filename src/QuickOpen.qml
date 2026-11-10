import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "brands.js" as Brands

// Ctrl+P: type a few letters of a file's name or path, Enter opens it.
Popup {
    id: quick
    signal picked(string path)
    property var results: []

    modal: true
    focus: true
    x: (parent.width - width) / 2
    y: 80
    width: Math.min(parent.width - 80, 620)
    height: Math.min(parent.height - 160, column.implicitHeight + 16)
    padding: 8
    Overlay.modal: Rectangle { color: theme.alpha(theme.background, 0.5) }
    background: Rectangle { color: theme.surface; radius: 12; border.color: theme.line }

    function show() {
        field.text = ""
        results = workspace.quickOpen("")
        list.currentIndex = 0
        open()
        field.forceActiveFocus()
    }
    function accept() {
        if (list.currentIndex >= 0 && list.currentIndex < results.length) {
            const path = results[list.currentIndex].path
            close()
            picked(path)
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { name: "search"; size: 15; color: theme.highlight; Layout.leftMargin: 6 }
            TextField {
                id: field
                Layout.fillWidth: true
                placeholderText: "Aller au fichier… (lettres du nom ou du chemin)"
                background: null
                font.pixelSize: 14
                onTextChanged: { quick.results = workspace.quickOpen(text); list.currentIndex = 0 }
                onAccepted: quick.accept()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onEscapePressed: quick.close()
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            clip: true
            model: quick.results
            highlightMoveDuration: 0
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 40
                radius: 7
                color: ListView.isCurrentItem ? theme.alpha(theme.highlight, 0.14) : (hit.containsMouse ? theme.raised : "transparent")
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    Icon { name: "file"; brand: Brands.forFile(modelData.name); size: 15; color: theme.textDim }
                    Text { text: modelData.name; color: theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.relative
                        color: theme.textFaint
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: { list.currentIndex = index; quick.accept() } }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Aucun fichier ne correspond."
                color: theme.textFaint
            }
        }
    }
}
