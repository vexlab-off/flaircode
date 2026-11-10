import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Find and replace in the current file.
Rectangle {
    id: bar
    property var editor: null
    property bool replacing: false
    property bool caseSensitive: false
    property int matches: 0

    visible: false
    width: 460
    height: column.implicitHeight + 16
    radius: 10
    color: theme.surface
    border.color: theme.line

    function show(withReplace) {
        replacing = withReplace
        visible = true
        if (editor && editor.textEdit.selectedText && editor.textEdit.selectedText.indexOf(" ") < 0)
            query.text = editor.textEdit.selectedText
        query.forceActiveFocus()
        query.selectAll()
        count()
    }
    function hide() {
        visible = false
        if (editor) editor.textEdit.forceActiveFocus()
    }
    function haystack() { return caseSensitive ? editor.textEdit.text : editor.textEdit.text.toLowerCase() }
    function needle() { return caseSensitive ? query.text : query.text.toLowerCase() }
    function count() {
        if (!editor || !query.text) { matches = 0; return }
        const h = haystack(), n = needle()
        let c = 0, i = h.indexOf(n)
        while (i >= 0 && c < 10000) { c++; i = h.indexOf(n, i + n.length) }
        matches = c
    }
    function find(forward) {
        if (!editor || !query.text) return
        const edit = editor.textEdit, h = haystack(), n = needle()
        let at
        if (forward) {
            at = h.indexOf(n, edit.selectionEnd)
            if (at < 0) at = h.indexOf(n) // wrap around
        } else {
            at = h.lastIndexOf(n, edit.selectionStart - 1)
            if (at < 0) at = h.lastIndexOf(n)
        }
        if (at >= 0) edit.select(at, at + n.length)
    }
    function replaceOne() {
        const edit = editor.textEdit
        const selected = caseSensitive ? edit.selectedText : edit.selectedText.toLowerCase()
        if (selected === needle() && selected !== "") {
            const at = edit.selectionStart
            edit.remove(edit.selectionStart, edit.selectionEnd)
            edit.insert(at, replacement.text)
            edit.select(at + replacement.text.length, at + replacement.text.length)
        }
        find(true)
        count()
    }
    function replaceAll() {
        if (!query.text) return
        const edit = editor.textEdit
        const flags = caseSensitive ? "g" : "gi"
        const pattern = new RegExp(query.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), flags)
        const next = edit.text.replace(pattern, () => replacement.text)
        if (next === edit.text) return
        const cursor = edit.cursorPosition
        edit.remove(0, edit.length)
        edit.insert(0, next)
        edit.cursorPosition = Math.min(cursor, edit.length)
        count()
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
        RowLayout {
            spacing: 6
            Icon { name: "search"; size: 14; color: theme.textFaint; Layout.leftMargin: 4 }
            TextField {
                id: query
                Layout.fillWidth: true
                placeholderText: "Rechercher"
                background: null
                onTextChanged: { bar.count(); bar.find(true) }
                onAccepted: bar.find(true)
                Keys.onEscapePressed: bar.hide()
            }
            Text {
                text: query.text ? (bar.matches === 0 ? "Aucun" : bar.matches + " résultat" + (bar.matches > 1 ? "s" : "")) : ""
                color: bar.matches === 0 && query.text ? theme.danger : theme.textFaint
                font.pixelSize: 11
            }
            Toggle { label: "Aa"; tip: "Respecter la casse"; on: bar.caseSensitive; onClicked: { bar.caseSensitive = !bar.caseSensitive; bar.count() } }
            Toggle { label: "↑"; tip: "Précédent (Maj+F3)"; onClicked: bar.find(false) }
            Toggle { label: "↓"; tip: "Suivant (F3, Entrée)"; onClicked: bar.find(true) }
            Toggle { label: "⇄"; tip: "Remplacer (Ctrl+H)"; on: bar.replacing; onClicked: bar.replacing = !bar.replacing }
        }
        RowLayout {
            visible: bar.replacing
            spacing: 6
            Item { width: 18 }
            TextField {
                id: replacement
                Layout.fillWidth: true
                placeholderText: "Remplacer par"
                background: null
                onAccepted: bar.replaceOne()
                Keys.onEscapePressed: bar.hide()
            }
            Button { text: "Remplacer"; flat: true; onClicked: bar.replaceOne() }
            Button { text: "Tout"; flat: true; onClicked: bar.replaceAll() }
        }
    }

    component Toggle: Rectangle {
        id: t
        property string label
        property string tip
        property bool on: false
        signal clicked()
        width: 26; height: 26; radius: 6
        color: on ? theme.alpha(theme.highlight, 0.16) : (th.containsMouse ? theme.raised : "transparent")
        Text { anchors.centerIn: parent; text: t.label; color: t.on ? theme.highlight : theme.textDim; font.pixelSize: 12; font.weight: Font.DemiBold }
        ToolTip.visible: th.containsMouse
        ToolTip.text: t.tip
        ToolTip.delay: 400
        MouseArea { id: th; anchors.fill: parent; hoverEnabled: true; onClicked: t.clicked() }
    }
}
