import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ctrl+Maj+P: every command, searchable, with its shortcut and what it does.
// Also inserts snippets, and ":42" jumps to line 42.
Popup {
    id: palette
    property var commands: []   // [{id, name, description, shortcut, category, run}]
    property var results: []

    modal: true
    focus: true
    x: (parent.width - width) / 2
    y: 70
    width: Math.min(parent.width - 80, 680)
    height: Math.min(parent.height - 140, column.implicitHeight + 16)
    padding: 8
    Overlay.modal: Rectangle { color: theme.alpha(theme.background, 0.5) }
    background: Rectangle { color: theme.surface; radius: 12; border.color: theme.line }

    function show(prefix) {
        field.text = prefix || ""
        filter()
        open()
        field.forceActiveFocus()
    }

    function score(query, item) {
        if (!query) return 1
        const hay = (item.name + " " + item.description + " " + item.category).toLowerCase()
        const words = query.toLowerCase().split(/\s+/).filter(w => w)
        let s = 0
        for (const w of words) {
            const i = hay.indexOf(w)
            if (i < 0) return -1
            s += item.name.toLowerCase().startsWith(w) ? 30 : (i < item.name.length ? 15 : 5)
        }
        return s
    }

    function filter() {
        const q = field.text.trim()
        if (/^:\d+$/.test(q)) {
            results = [{ id: "line", name: "Aller à la ligne " + q.substring(1), description: "Entrée pour y aller", shortcut: "Ctrl+G", category: "Navigation",
                         run: () => win.goToLine(parseInt(q.substring(1))) }]
        } else {
            const scored = []
            for (const c of commands) {
                if (c.enabled && !c.enabled()) continue
                const s = score(q, c)
                if (s >= 0) scored.push({ s: s, c: c })
            }
            scored.sort((a, b) => b.s - a.s)
            results = scored.slice(0, 80).map(x => x.c)
        }
        list.currentIndex = 0
    }

    function accept() {
        const item = results[list.currentIndex]
        if (!item) return
        close()
        Qt.callLater(item.run)
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { name: "sparkle"; size: 15; color: theme.highlight; Layout.leftMargin: 6 }
            TextField {
                id: field
                Layout.fillWidth: true
                placeholderText: "Que veux-tu faire ? (« enregistrer », « commenter », « snippet for », « :42 »…)"
                background: null
                font.pixelSize: 14
                onTextChanged: palette.filter()
                onAccepted: palette.accept()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onEscapePressed: palette.close()
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 460)
            clip: true
            model: palette.results
            highlightMoveDuration: 0
            section.property: "category"
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 46
                radius: 7
                color: ListView.isCurrentItem ? theme.alpha(theme.highlight, 0.14) : (hit.containsMouse ? theme.raised : "transparent")
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            spacing: 8
                            Text { text: modelData.name; color: theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            Text { text: modelData.category; color: theme.textFaint; font.pixelSize: 10 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.description
                            color: theme.textDim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    Keycap { visible: !!modelData.shortcut; text: modelData.shortcut || "" }
                }
                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: { list.currentIndex = index; palette.accept() } }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Aucune commande ne correspond."
                color: theme.textFaint
            }
        }
    }
}
