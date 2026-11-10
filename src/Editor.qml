import QtQuick
import QtQuick.Controls

// One file being edited: line numbers, the current line, and the keys a
// code editor needs (indentation, auto-indent, comment toggling).
Item {
    id: editor
    required property var document
    property alias textEdit: edit
    readonly property int indent: 4
    // The first coding font installed, so the editor never falls back to a
    // proportional face.
    readonly property string monoFamily: ["JetBrains Mono", "JetBrainsMono Nerd Font", "Fira Code", "Source Code Pro",
                                          "DejaVu Sans Mono", "Noto Sans Mono"].find(f => Qt.fontFamilies().indexOf(f) >= 0) || "monospace"
    readonly property real lineHeight: edit.lineCount > 0
                                        ? (edit.contentHeight - edit.topPadding - edit.bottomPadding) / edit.lineCount
                                        : metrics.lineSpacing
    readonly property int currentLine: Math.max(0, Math.floor((edit.cursorRectangle.y - edit.topPadding) / lineHeight))
    readonly property int currentColumn: Math.round((edit.cursorRectangle.x - edit.leftPadding) / metrics.averageCharacterWidth) + 1

    FontMetrics { id: metrics; font: edit.font }

    function ensureVisible() {
        const r = edit.cursorRectangle
        if (r.y < flick.contentY + lineHeight) flick.contentY = Math.max(0, r.y - lineHeight)
        else if (r.y + r.height > flick.contentY + flick.height - lineHeight) flick.contentY = r.y + r.height - flick.height + lineHeight
        if (r.x < flick.contentX + 20) flick.contentX = Math.max(0, r.x - 40)
        else if (r.x > flick.contentX + flick.width - 40) flick.contentX = r.x - flick.width + 80
    }

    // Start and end offsets of the full lines covered by the selection or cursor.
    function lineRange() {
        const start = Math.min(edit.selectionStart, edit.selectionEnd)
        let end = Math.max(edit.selectionStart, edit.selectionEnd)
        const before = edit.getText(Math.max(0, start - 4000), start)
        const lineStart = start - (before.length - before.lastIndexOf("\n") - 1)
        // A selection ending at a line start doesn't include that line.
        if (end > start && edit.getText(end - 1, end) === "\n") end -= 1
        const after = edit.getText(end, Math.min(edit.length, end + 4000))
        const nl = after.indexOf("\n")
        const lineEnd = nl < 0 ? end + after.length : end + nl
        return [lineStart, lineEnd]
    }

    function replaceLines(transform) {
        const [a, b] = lineRange()
        const original = edit.getText(a, b)
        const changed = original.split("\n").map(transform).join("\n")
        if (changed === original) return
        edit.remove(a, b)
        edit.insert(a, changed)
        edit.select(a, a + changed.length)
    }

    function indentLines() { replaceLines(line => " ".repeat(indent) + line) }
    function outdentLines() { replaceLines(line => line.replace(new RegExp("^ {1," + indent + "}|^\\t"), "")) }

    function toggleComment() {
        const token = editor.document.commentToken
        if (!token) return
        const [a, b] = lineRange()
        const lines = edit.getText(a, b).split("\n")
        const allCommented = lines.filter(l => l.trim() !== "").every(l => l.trim().startsWith(token))
        replaceLines(line => {
            if (line.trim() === "") return line
            if (allCommented) return line.replace(new RegExp("^(\\s*)" + token.replace(/[/#;]/g, "\\$&") + " ?"), "$1")
            const lead = line.match(/^\s*/)[0]
            return lead + token + " " + line.substring(lead.length)
        })
    }

    function newlineWithIndent() {
        const pos = edit.cursorPosition
        const before = edit.getText(Math.max(0, pos - 4000), pos)
        const line = before.substring(before.lastIndexOf("\n") + 1)
        let lead = line.match(/^\s*/)[0]
        // One level deeper after an opening bracket or a Python block.
        if (/[{\[(:]\s*$/.test(line)) lead += " ".repeat(indent)
        if (edit.selectedText.length) edit.remove(edit.selectionStart, edit.selectionEnd)
        edit.insert(edit.cursorPosition, "\n" + lead)
    }

    // Changed on disk while edited here.
    Rectangle {
        id: banner
        visible: editor.document.changedOnDisk || editor.document.error !== ""
        anchors.top: parent.top
        width: parent.width
        height: visible ? 38 : 0
        color: theme.alpha(editor.document.error ? theme.danger : theme.warning, 0.12)
        z: 2
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "alert"; size: 15; color: editor.document.error ? theme.danger : theme.warning }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: editor.document.error || "Ce fichier a été modifié sur le disque pendant que tu l'éditais."
                color: theme.text
                font.pixelSize: 12
            }
            Button {
                visible: !editor.document.error
                anchors.verticalCenter: parent.verticalCenter
                text: "Recharger"
                flat: true
                onClicked: editor.document.reload()
            }
            Button {
                visible: !editor.document.error
                anchors.verticalCenter: parent.verticalCenter
                text: "Garder ma version"
                flat: true
                onClicked: editor.document.save()
            }
        }
    }

    // Line numbers
    Rectangle {
        id: gutter
        anchors.top: banner.bottom
        anchors.bottom: parent.bottom
        width: Math.max(3, String(edit.lineCount).length) * metrics.averageCharacterWidth + 34
        color: theme.background

        ListView {
            anchors.fill: parent
            anchors.rightMargin: 14
            interactive: false
            clip: true
            model: edit.lineCount
            contentY: flick.contentY - edit.topPadding
            delegate: Text {
                required property int index
                width: ListView.view.width
                height: editor.lineHeight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: index + 1
                font.family: edit.font.family
                font.pixelSize: edit.font.pixelSize - 1
                color: index === editor.currentLine ? theme.text : theme.alpha(theme.textFaint, 0.8)
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: banner.bottom
        anchors.bottom: parent.bottom
        anchors.left: gutter.right
        anchors.right: parent.right
        clip: true
        contentWidth: Math.max(width, edit.contentWidth + 80)
        // Scroll past the end so the last line can sit mid-screen.
        contentHeight: edit.contentHeight + height * 0.5
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ScrollBar.horizontal: ScrollBar {}

        // The cursor's line
        Rectangle {
            y: edit.topPadding + editor.currentLine * editor.lineHeight
            width: Math.max(flick.width, edit.contentWidth + 80)
            height: editor.lineHeight
            color: theme.alpha(theme.text, 0.035)
            visible: edit.selectedText.length === 0
        }

        TextEdit {
            id: edit
            width: Math.max(flick.width, contentWidth + 80)
            height: Math.max(flick.height, contentHeight)
            topPadding: 10
            bottomPadding: 10
            leftPadding: 6
            font.family: editor.monoFamily
            font.pixelSize: workspace.fontSize
            color: theme.text
            selectionColor: theme.alpha(theme.highlight, 0.32)
            selectedTextColor: theme.text
            wrapMode: TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: true
            focus: true
            tabStopDistance: metrics.averageCharacterWidth * editor.indent
            cursorDelegate: Rectangle {
                width: 2
                color: theme.highlight
                visible: edit.activeFocus
                SequentialAnimation on opacity {
                    running: edit.activeFocus
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 530 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 530 }
                }
            }

            Component.onCompleted: {
                editor.document.attach(edit.textDocument)
                // Loading leaves the cursor at the end; files open at the top.
                edit.cursorPosition = 0
                flick.contentY = 0
            }
            onCursorRectangleChanged: editor.ensureVisible()

            Keys.onPressed: (event) => {
                const ctrl = event.modifiers & Qt.ControlModifier
                if (event.key === Qt.Key_Tab && !ctrl) {
                    if (edit.selectedText.indexOf(" ") >= 0 || edit.selectedText.indexOf("\n") >= 0) editor.indentLines()
                    else edit.insert(edit.cursorPosition, " ".repeat(editor.indent))
                    event.accepted = true
                } else if (event.key === Qt.Key_Backtab) {
                    editor.outdentLines()
                    event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !ctrl) {
                    editor.newlineWithIndent()
                    event.accepted = true
                } else if (ctrl && (event.key === Qt.Key_Slash || event.key === Qt.Key_Colon)) {
                    // Ctrl+/ on QWERTY, Ctrl+: on AZERTY where / needs Shift.
                    editor.toggleComment()
                    event.accepted = true
                }
            }
        }
    }
}
