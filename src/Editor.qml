import QtQuick
import QtQuick.Controls

// One file being edited: line numbers, the current line, and the keys a code
// editor needs — indentation, auto-indent, closing brackets, comment toggling
// and snippets. Every colour and option comes from the settings.
Item {
    id: editor
    required property var document
    property alias textEdit: edit

    // Settings, re-read whenever they change (revision is the dependency).
    readonly property int rev: settings.revision
    function opt(key) { return rev, settings.value(key) }
    readonly property int indent: opt("editor/tabWidth")
    readonly property bool useSpaces: opt("editor/insertSpaces")
    readonly property string indentUnit: useSpaces ? " ".repeat(indent) : "\t"
    readonly property bool wrap: opt("editor/wordWrap")
    readonly property bool showNumbers: opt("editor/lineNumbers") && !wrap
    function c(role) { return scheme.revision, scheme.color(role) }

    // The chosen coding font, or the first one installed, never a proportional face.
    readonly property string monoFamily: {
        const chosen = opt("editor/fontFamily")
        if (chosen && Qt.fontFamilies().indexOf(chosen) >= 0) return chosen
        return ["JetBrains Mono", "JetBrainsMono Nerd Font", "Fira Code", "Source Code Pro", "DejaVu Sans Mono",
                "Noto Sans Mono"].find(f => Qt.fontFamilies().indexOf(f) >= 0) || "monospace"
    }
    readonly property real lineHeight: edit.lineCount > 0
                                        ? (edit.contentHeight - edit.topPadding - edit.bottomPadding) / edit.lineCount
                                        : metrics.lineSpacing
    readonly property int visualLine: Math.max(0, Math.floor((edit.cursorRectangle.y - edit.topPadding) / lineHeight))
    readonly property int currentLine: (edit.cursorPosition, document.lineAt(edit.cursorPosition))
    readonly property int currentColumn: (edit.cursorPosition, document.columnAt(edit.cursorPosition) + 1)

    FontMetrics { id: metrics; font: edit.font }

    // Auto-save one second after the last keystroke, when enabled.
    Timer { id: autosave; interval: 1000; onTriggered: if (editor.document.dirty) win.saveDocument(editor.document) }
    Connections {
        target: edit
        function onTextChanged() { if (editor.opt("editor/autoSave")) autosave.restart() }
    }

    function ensureVisible() {
        const r = edit.cursorRectangle
        if (r.y < flick.contentY + lineHeight) flick.contentY = Math.max(0, r.y - lineHeight)
        else if (r.y + r.height > flick.contentY + flick.height - lineHeight) flick.contentY = r.y + r.height - flick.height + lineHeight
        if (r.x < flick.contentX + 20) flick.contentX = Math.max(0, r.x - 40)
        else if (r.x > flick.contentX + flick.width - 40) flick.contentX = r.x - flick.width + 80
    }

    function goToLine(line) {
        const text = edit.text
        let pos = 0
        for (let i = 1; i < line && pos >= 0; i++) pos = text.indexOf("\n", pos) + 1
        edit.cursorPosition = Math.max(0, pos)
        edit.forceActiveFocus()
    }

    // Start and end offsets of the full lines covered by the selection or cursor.
    function lineRange() {
        const start = Math.min(edit.selectionStart, edit.selectionEnd)
        let end = Math.max(edit.selectionStart, edit.selectionEnd)
        const before = edit.getText(Math.max(0, start - 4000), start)
        const lineStart = start - (before.length - before.lastIndexOf("\n") - 1)
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

    function indentLines() { replaceLines(line => indentUnit + line) }
    function outdentLines() { replaceLines(line => line.replace(new RegExp("^ {1," + indent + "}|^\\t"), "")) }
    function duplicateLine() {
        const [a, b] = lineRange()
        const text = edit.getText(a, b)
        edit.insert(b, "\n" + text)
    }
    function deleteLine() {
        const [a, b] = lineRange()
        edit.remove(a, Math.min(edit.length, b + 1))
    }
    function moveLines(direction) {
        const [a, b] = lineRange()
        const text = edit.getText(a, b)
        if (direction < 0) {
            if (a === 0) return
            const before = edit.getText(Math.max(0, a - 4000), a - 1)
            const prevStart = a - 1 - (before.length - before.lastIndexOf("\n") - 1)
            const prev = edit.getText(prevStart, a - 1)
            edit.remove(prevStart, b)
            edit.insert(prevStart, text + "\n" + prev)
            edit.select(prevStart, prevStart + text.length)
        } else {
            if (b >= edit.length) return
            const after = edit.getText(b + 1, Math.min(edit.length, b + 4000))
            const nl = after.indexOf("\n")
            const next = nl < 0 ? after : after.substring(0, nl)
            edit.remove(a, b + 1 + next.length)
            edit.insert(a, next + "\n" + text)
            edit.select(a + next.length + 1, a + next.length + 1 + text.length)
        }
    }

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
        let lead = opt("editor/autoIndent") ? line.match(/^\s*/)[0] : ""
        const opens = /[{\[(:]\s*$/.test(line) && opt("editor/autoIndent")
        const next = edit.getText(pos, Math.min(edit.length, pos + 1))
        if (edit.selectedText.length) edit.remove(edit.selectionStart, edit.selectionEnd)
        // Between a pair of brackets, open them onto their own lines.
        if (opens && "}])".indexOf(next) >= 0 && next !== "") {
            edit.insert(edit.cursorPosition, "\n" + lead + indentUnit + "\n" + lead)
            edit.cursorPosition = pos + 1 + lead.length + indentUnit.length
            return
        }
        if (opens) lead += indentUnit
        edit.insert(edit.cursorPosition, "\n" + lead)
    }

    // The word just before the cursor, if it's a snippet prefix, becomes the snippet.
    function tryExpandSnippet() {
        if (!opt("editor/snippets") || edit.selectedText.length) return false
        const pos = edit.cursorPosition
        const before = edit.getText(Math.max(0, pos - 40), pos)
        const match = before.match(/([A-Za-z_][\w]*)$/)
        if (!match) return false
        const result = snippets.expand(editor.document.language, match[1])
        if (!result.text) return false
        // Indent every following line of the snippet like the current line.
        const lineText = edit.getText(Math.max(0, pos - 4000), pos)
        const lead = lineText.substring(lineText.lastIndexOf("\n") + 1).match(/^\s*/)[0]
        const body = result.text.split("\n").map((l, i) => i === 0 ? l : lead + l.replace(/^ {4}/gm, indentUnit)).join("\n")
        const start = pos - match[1].length
        edit.remove(start, pos)
        edit.insert(start, body)
        const shift = s => { // account for indentation added before the selection
            const linesBefore = result.text.substring(0, s).split("\n").length - 1
            return s + linesBefore * lead.length
        }
        edit.select(start + shift(result.selectionStart), start + shift(result.selectionEnd))
        return true
    }

    readonly property var pairs: ({ "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`" })

    // Changed on disk while edited here, or not editable.
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
            Button { visible: !editor.document.error; anchors.verticalCenter: parent.verticalCenter; text: "Recharger"; flat: true; onClicked: editor.document.reload() }
            Button { visible: !editor.document.error; anchors.verticalCenter: parent.verticalCenter; text: "Garder ma version"; flat: true; onClicked: editor.document.save() }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: banner.height
        color: editor.c("background")
    }

    // Line numbers
    Rectangle {
        id: gutter
        anchors.top: banner.bottom
        anchors.bottom: parent.bottom
        width: editor.showNumbers ? Math.max(3, String(edit.lineCount).length) * metrics.averageCharacterWidth + 34 : 12
        color: editor.c("gutter")

        ListView {
            visible: editor.showNumbers
            anchors.fill: parent
            anchors.rightMargin: 14
            interactive: false
            clip: true
            model: editor.showNumbers ? edit.lineCount : 0
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
                color: index === editor.visualLine ? editor.c("gutterActive") : editor.c("gutterText")
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
        contentWidth: editor.wrap ? width : Math.max(width, edit.contentWidth + 80)
        // Scroll past the end so the last line can sit mid-screen.
        contentHeight: edit.contentHeight + height * 0.5
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ScrollBar.horizontal: ScrollBar { visible: !editor.wrap }

        // The cursor's line
        Rectangle {
            y: edit.cursorRectangle.y
            width: Math.max(flick.width, edit.contentWidth + 80)
            height: editor.lineHeight
            color: editor.c("currentLine")
            visible: editor.opt("editor/highlightLine") && edit.selectedText.length === 0
        }

        TextEdit {
            id: edit
            width: editor.wrap ? flick.width : Math.max(flick.width, contentWidth + 80)
            height: Math.max(flick.height, contentHeight)
            topPadding: 10
            bottomPadding: 10
            leftPadding: 6
            rightPadding: 16
            font.family: editor.monoFamily
            font.pixelSize: editor.opt("editor/fontSize")
            color: editor.c("text")
            selectionColor: editor.c("selection")
            selectedTextColor: editor.c("text")
            wrapMode: editor.wrap ? TextEdit.Wrap : TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: true
            focus: true
            tabStopDistance: metrics.averageCharacterWidth * editor.indent
            cursorDelegate: Rectangle {
                width: 2
                color: editor.c("cursor")
                visible: edit.activeFocus
                SequentialAnimation on opacity {
                    running: edit.activeFocus && editor.opt("editor/cursorBlink")
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 530 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 530 }
                    onStopped: parent.opacity = 1
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
                const alt = event.modifiers & Qt.AltModifier
                const shift = event.modifiers & Qt.ShiftModifier
                if (event.key === Qt.Key_Tab && !ctrl) {
                    if (edit.selectedText.indexOf(String.fromCharCode(0x2029)) >= 0 || edit.selectedText.indexOf("\n") >= 0) editor.indentLines()
                    else if (!editor.tryExpandSnippet()) edit.insert(edit.cursorPosition, editor.indentUnit)
                    event.accepted = true
                } else if (event.key === Qt.Key_Backtab) {
                    editor.outdentLines(); event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !ctrl) {
                    editor.newlineWithIndent(); event.accepted = true
                } else if (ctrl && (event.key === Qt.Key_Slash || event.key === Qt.Key_Colon)) {
                    // Ctrl+/ on QWERTY, Ctrl+: on AZERTY where / needs Shift.
                    editor.toggleComment(); event.accepted = true
                } else if (ctrl && shift && event.key === Qt.Key_D) {
                    editor.duplicateLine(); event.accepted = true
                } else if (ctrl && shift && event.key === Qt.Key_K) {
                    editor.deleteLine(); event.accepted = true
                } else if (alt && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                    editor.moveLines(event.key === Qt.Key_Up ? -1 : 1); event.accepted = true
                } else if (!ctrl && !alt && editor.opt("editor/autoClose") && editor.pairs[event.text] !== undefined) {
                    const open = event.text, close = editor.pairs[open]
                    const next = edit.getText(edit.cursorPosition, edit.cursorPosition + 1)
                    // Typing the closing quote over an auto-inserted one just steps past it.
                    if (open === close && next === close && !edit.selectedText) {
                        edit.cursorPosition += 1
                    } else if (edit.selectedText) {
                        const s = edit.selectionStart, e = edit.selectionEnd, inner = edit.selectedText
                        edit.remove(s, e)
                        edit.insert(s, open + inner + close)
                        edit.select(s + 1, s + 1 + inner.length)
                    } else {
                        edit.insert(edit.cursorPosition, open + close)
                        edit.cursorPosition -= 1
                    }
                    event.accepted = true
                } else if (!ctrl && editor.opt("editor/autoClose") && ")]}".indexOf(event.text) >= 0 && event.text !== ""
                           && edit.getText(edit.cursorPosition, edit.cursorPosition + 1) === event.text) {
                    edit.cursorPosition += 1
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace && !ctrl && !edit.selectedText && editor.opt("editor/autoClose")) {
                    // Deleting an opening bracket also deletes its empty partner.
                    const prev = edit.getText(edit.cursorPosition - 1, edit.cursorPosition)
                    const next = edit.getText(edit.cursorPosition, edit.cursorPosition + 1)
                    if (editor.pairs[prev] !== undefined && editor.pairs[prev] === next) {
                        edit.remove(edit.cursorPosition - 1, edit.cursorPosition + 1)
                        event.accepted = true
                    }
                }
            }
        }
    }
}
