import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

// The live preview beside the code: HTML and SVG render as you type, Markdown
// as formatted text, and a picture referenced under the cursor shows itself.
Rectangle {
    id: pane
    property var editor: null
    readonly property var doc: editor ? editor.document : null
    readonly property string kind: !doc ? "" : doc.language === "html" ? "html"
                                   : doc.path.toLowerCase().endsWith(".svg") ? "svg"
                                   : doc.language === "markdown" ? "markdown" : "image"
    // An image path under the cursor in any file ("logo.png", url(img/a.jpg)…).
    property string cursorImage: ""
    color: theme.surface

    function folderOf(path) { return path.substring(0, path.lastIndexOf("/") + 1) }

    function refresh() {
        if (!editor || !visible) return
        const text = editor.textEdit.text
        if (kind === "html") web.loadHtml(text, "file://" + folderOf(doc.path))
        else if (kind === "svg") web.loadHtml("<html><body style='margin:0;display:grid;place-items:center;min-height:100vh;background:#fff'>" + text + "</body></html>", "file://" + folderOf(doc.path))
        findCursorImage()
    }

    function findCursorImage() {
        if (!editor) { cursorImage = ""; return }
        const edit = editor.textEdit
        const pos = edit.cursorPosition
        const around = edit.getText(Math.max(0, pos - 200), Math.min(edit.length, pos + 200))
        const offset = pos - Math.max(0, pos - 200)
        const re = /["'(]([^"'()\s]+\.(?:png|jpe?g|gif|webp|svg|bmp|ico|avif))["')]/gi
        let m, found = ""
        while ((m = re.exec(around)) !== null) {
            if (m.index <= offset && offset <= m.index + m[0].length) { found = m[1]; break }
        }
        if (!found) { cursorImage = ""; return }
        cursorImage = found.startsWith("/") ? found : (found.startsWith("http") ? found : "file://" + folderOf(doc.path) + found)
        if (cursorImage.startsWith("/")) cursorImage = "file://" + cursorImage
    }

    Timer { id: debounce; interval: 250; onTriggered: pane.refresh() }
    Connections {
        target: pane.editor ? pane.editor.textEdit : null
        function onTextChanged() { debounce.restart() }
        function onCursorPositionChanged() { pane.findCursorImage() }
    }
    onEditorChanged: refresh()
    onVisibleChanged: refresh()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.leftMargin: 14
            Layout.rightMargin: 8
            spacing: 8
            Icon { name: "eye"; size: 15; color: theme.highlight }
            Text { text: "Aperçu en direct"; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true
                text: pane.kind === "html" ? "HTML · à chaque frappe" : pane.kind === "svg" ? "SVG" : pane.kind === "markdown" ? "Markdown" : ""
                color: theme.textFaint
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Rectangle {
                width: 26; height: 26; radius: 6
                color: closeHover.containsMouse ? theme.raised : "transparent"
                Icon { anchors.centerIn: parent; name: "close"; size: 12; color: theme.textDim }
                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; onClicked: win.previewVisible = false }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }

        // The picture referenced at the cursor, whatever the language.
        Rectangle {
            visible: pane.cursorImage !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            color: theme.background
            Image {
                anchors.fill: parent
                anchors.margins: 10
                fillMode: Image.PreserveAspectFit
                source: pane.cursorImage
                asynchronous: true
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 6
                text: pane.cursorImage.substring(pane.cursorImage.lastIndexOf("/") + 1)
                color: theme.textDim
                font.pixelSize: 11
            }
        }

        WebEngineView {
            id: web
            visible: pane.kind === "html" || pane.kind === "svg"
            Layout.fillWidth: true
            Layout.fillHeight: true
            profile: WebEngineProfile { offTheRecord: true }
            settings.javascriptCanOpenWindows: false
            onNavigationRequested: (request) => {
                const url = request.url.toString()
                if (!request.isMainFrame || url.startsWith("file://") || url.startsWith("data:") || url === "about:blank") return
                request.reject()
                Qt.openUrlExternally(request.url)
            }
        }

        ScrollView {
            visible: pane.kind === "markdown"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            TextArea {
                readOnly: true
                textFormat: TextEdit.MarkdownText
                wrapMode: TextEdit.Wrap
                text: pane.kind === "markdown" && pane.editor ? pane.editor.textEdit.text : ""
                color: theme.text
                background: null
                font.pixelSize: 14
                leftPadding: 18
                rightPadding: 18
                topPadding: 14
            }
        }

        ColumnLayout {
            visible: pane.kind !== "html" && pane.kind !== "svg" && pane.kind !== "markdown"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                Layout.margins: 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: pane.cursorImage ? "" : "Les pages HTML, les SVG et le Markdown s'affichent ici pendant que tu écris. Dans n'importe quel fichier, place le curseur sur le chemin d'une image (\"logo.png\", url(img/fond.jpg)…) pour la voir."
                color: theme.textDim
                font.pixelSize: 12
            }
            Item { Layout.fillHeight: true }
        }
    }
}
