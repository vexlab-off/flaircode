import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "brands.js" as Brands

ApplicationWindow {
    id: win
    width: 1400
    height: 880
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: (documents.currentDocument ? documents.currentDocument.name + " — " : "")
           + (workspace.root ? workspace.name + " — " : "") + "Flair Code"
    color: theme.background

    Material.theme: Material.Dark
    Material.accent: theme.highlight
    Material.background: theme.surface
    Material.foreground: theme.text

    property bool sidebarVisible: true
    property bool quitting: false
    readonly property var currentEditor: editors.count > 0 && documents.current >= 0 ? editors.itemAt(documents.current) : null

    function openFile(path) {
        if (!path) return
        const i = documents.open(path)
        if (i < 0) { status.flash("Impossible d'ouvrir ce fichier."); return }
        Qt.callLater(() => { if (win.currentEditor) win.currentEditor.textEdit.forceActiveFocus() })
    }
    function openFolder(path) {
        const file = workspace.openPath(path)
        if (file) openFile(file)
    }
    function save() {
        const doc = documents.currentDocument
        if (doc && doc.save()) status.flash("Enregistré : " + doc.name)
    }
    function closeTab(index) {
        const doc = documents.at(index)
        if (!doc) return
        if (doc.dirty) { confirmClose.ask(index); return }
        documents.close(index)
    }

    onClosing: (close) => {
        if (documents.dirtyCount > 0 && !quitting) {
            close.accepted = false
            confirmQuit.open()
        }
    }

    // Typing goes to the editor, so shortcuts all carry Ctrl, or are F-keys.
    Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; onActivated: win.save() }
    Shortcut { sequence: "Ctrl+Shift+S"; context: Qt.ApplicationShortcut; onActivated: { if (documents.saveAll()) status.flash("Tout est enregistré.") } }
    Shortcut { sequence: "Ctrl+W"; context: Qt.ApplicationShortcut; onActivated: win.closeTab(documents.current) }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.ApplicationShortcut; onActivated: documents.next(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; context: Qt.ApplicationShortcut; onActivated: documents.next(-1) }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; enabled: workspace.root !== ""; onActivated: quickOpen.show() }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: win.currentEditor !== null; onActivated: findBar.show(false) }
    Shortcut { sequence: "Ctrl+H"; context: Qt.ApplicationShortcut; enabled: win.currentEditor !== null; onActivated: findBar.show(true) }
    Shortcut { sequence: "F3"; context: Qt.ApplicationShortcut; onActivated: findBar.find(true) }
    Shortcut { sequence: "Shift+F3"; context: Qt.ApplicationShortcut; onActivated: findBar.find(false) }
    Shortcut { sequence: "Ctrl+O"; context: Qt.ApplicationShortcut; onActivated: workspace.pickFolder() }
    Shortcut { sequence: "Ctrl+L"; context: Qt.ApplicationShortcut; onActivated: prompt.ask("path") }
    Shortcut { sequence: "Ctrl+N"; context: Qt.ApplicationShortcut; enabled: workspace.root !== ""; onActivated: prompt.ask("file") }
    Shortcut { sequence: "Ctrl+B"; context: Qt.ApplicationShortcut; onActivated: win.sidebarVisible = !win.sidebarVisible }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; context: Qt.ApplicationShortcut; onActivated: workspace.fontSize += 1 }
    Shortcut { sequence: "Ctrl+-"; context: Qt.ApplicationShortcut; onActivated: workspace.fontSize -= 1 }
    Shortcut { sequence: "Ctrl+0"; context: Qt.ApplicationShortcut; onActivated: workspace.fontSize = 14 }
    Shortcut { sequence: "F1"; context: Qt.ApplicationShortcut; onActivated: help.visible = !help.visible }
    Shortcut { sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: win.close() }
    Shortcut {
        sequence: "Escape"; context: Qt.ApplicationShortcut
        enabled: help.visible || findBar.visible
        onActivated: { help.visible = false; findBar.hide() }
    }

    Connections {
        target: workspace
        function onFolderPicked(path) { win.openFolder(path) }
        function onMessageChanged() { if (workspace.message) status.flash(workspace.message) }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ sidebar
        Rectangle {
            visible: win.sidebarVisible && workspace.root !== ""
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: theme.sidebar

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 14
                    Layout.rightMargin: 8
                    spacing: 10
                    Logo { size: 22 }
                    Text {
                        Layout.fillWidth: true
                        text: workspace.name
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    IconButton { icon: "plus"; tip: "Nouveau fichier (Ctrl+N)"; onClicked: prompt.ask("file") }
                    IconButton { icon: "folder"; tip: "Nouveau dossier"; onClicked: prompt.ask("folder") }
                    IconButton { icon: "refresh"; tip: "Actualiser"; onClicked: workspace.tree.refresh() }
                }
                ListView {
                    id: tree
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: workspace.tree
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        id: node
                        required property int index
                        required property string name
                        required property string path
                        required property bool isDir
                        required property int depth
                        required property bool expanded
                        readonly property bool active: documents.currentDocument && documents.currentDocument.path === path
                        readonly property var brand: isDir ? null : Brands.forFile(name)
                        width: ListView.view.width
                        height: 26
                        color: active ? theme.alpha(theme.highlight, 0.14) : (nodeHover.containsMouse ? theme.alpha(theme.text, 0.04) : "transparent")
                        Row {
                            x: 10 + node.depth * 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron"
                                size: 12
                                opacity: node.isDir ? 1 : 0
                                rotation: node.expanded ? 90 : 0
                                color: theme.textFaint
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: node.isDir ? "folder" : "file"
                                brand: node.brand
                                size: 14
                                color: node.isDir ? theme.highlight : theme.textDim
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: node.name
                                color: node.active ? theme.text : (node.name.startsWith(".") ? theme.textFaint : theme.textDim)
                                font.pixelSize: 13
                                font.weight: node.active ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            id: nodeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: node.isDir ? workspace.tree.toggle(node.index) : win.openFile(node.path)
                        }
                    }
                }
            }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.line }
        }

        // ------------------------------------------------------------ main area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Tabs
            Rectangle {
                visible: documents.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: theme.sidebar
                ListView {
                    id: tabs
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    model: documents
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: documents.current
                    delegate: Rectangle {
                        id: tab
                        required property int index
                        required property string name
                        required property string path
                        required property bool dirty
                        readonly property bool active: index === documents.current
                        width: tabRow.implicitWidth + 28
                        height: 40
                        color: active ? theme.background : (tabHover.containsMouse ? theme.alpha(theme.text, 0.03) : "transparent")
                        Rectangle { visible: tab.active; width: parent.width; height: 2; color: theme.highlight }
                        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.line }
                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: (mouse) => mouse.button === Qt.MiddleButton ? win.closeTab(tab.index) : documents.current = tab.index
                        }
                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "file"; brand: Brands.forFile(tab.name); size: 14; color: theme.textDim }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.name
                                color: tab.active ? theme.text : theme.textDim
                                font.pixelSize: 12
                                font.weight: tab.active ? Font.DemiBold : Font.Normal
                            }
                            // A dot while unsaved, a cross on hover.
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16
                                Rectangle {
                                    visible: tab.dirty && !closeHover.containsMouse
                                    anchors.centerIn: parent
                                    width: 8; height: 8; radius: 4
                                    color: theme.highlight
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    visible: closeHover.containsMouse || (!tab.dirty && (tab.active || tabHover.containsMouse))
                                    color: closeHover.containsMouse ? theme.raised : "transparent"
                                    Icon { anchors.centerIn: parent; name: "close"; size: 11; color: theme.textDim }
                                }
                                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; onClicked: win.closeTab(tab.index) }
                            }
                        }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.line; z: -1 }
            }

            // Editors, one per open file, so each keeps its own undo history.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: documents.count > 0
                StackLayout {
                    id: stack
                    anchors.fill: parent
                    currentIndex: documents.current
                    Repeater {
                        id: editors
                        model: documents
                        // Editor's own required `document` is filled from the model role.
                        delegate: Editor {}
                    }
                }
                FindBar {
                    id: findBar
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 12
                    editor: win.currentEditor
                    z: 10
                }
            }

            Welcome {
                visible: documents.count === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Status bar
            Rectangle {
                id: status
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: theme.sidebar
                property string message: ""
                function flash(text) { message = text; clear.restart() }
                Timer { id: clear; interval: 4000; onTriggered: status.message = "" }
                Rectangle { width: parent.width; height: 1; color: theme.line }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 16
                    Row {
                        visible: workspace.branch !== ""
                        spacing: 5
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "branch"; size: 12; color: theme.highlight }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: workspace.branch; color: theme.textDim; font.pixelSize: 11 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: status.message
                        color: theme.textDim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: win.currentEditor !== null
                        text: win.currentEditor ? "Ln " + (win.currentEditor.currentLine + 1) + ", Col " + win.currentEditor.currentColumn : ""
                        color: theme.textDim
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                    Text { visible: win.currentEditor !== null; text: "Espaces : 4"; color: theme.textFaint; font.pixelSize: 11 }
                    Text { visible: win.currentEditor !== null; text: "UTF-8"; color: theme.textFaint; font.pixelSize: 11 }
                    Text {
                        visible: !!documents.currentDocument
                        text: documents.currentDocument ? documents.currentDocument.languageName : ""
                        color: theme.textDim
                        font.pixelSize: 11
                    }
                    Text {
                        visible: documents.dirtyCount > 0
                        text: documents.dirtyCount + " non enregistré" + (documents.dirtyCount > 1 ? "s" : "")
                        color: theme.highlight
                        font.pixelSize: 11
                    }
                    Row {
                        spacing: 4
                        Keycap { text: "F1" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "aide"; color: theme.textFaint; font.pixelSize: 11 }
                    }
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon
        property string tip
        signal clicked()
        width: 26; height: 26; radius: 6
        color: ibHover.containsMouse ? theme.raised : "transparent"
        Icon { anchors.centerIn: parent; name: ib.icon; size: 14; color: theme.textDim }
        ToolTip.visible: ibHover.containsMouse
        ToolTip.text: ib.tip
        ToolTip.delay: 400
        MouseArea { id: ibHover; anchors.fill: parent; hoverEnabled: true; onClicked: ib.clicked() }
    }

    QuickOpen { id: quickOpen; onPicked: (path) => { win.openFile(path); workspace.tree.reveal(path) } }

    // Names for new files and folders, or a path to open.
    Dialog {
        id: prompt
        property string mode
        modal: true
        anchors.centerIn: parent
        width: 460
        title: mode === "file" ? "Nouveau fichier" : (mode === "folder" ? "Nouveau dossier" : "Ouvrir un dossier ou un fichier")
        standardButtons: Dialog.Ok | Dialog.Cancel
        background: Rectangle { color: theme.surface; radius: 12; border.color: theme.line }
        function ask(kind) {
            mode = kind
            field.text = kind === "path" ? (workspace.root ? workspace.root + "/" : "~/") : ""
            open()
            field.forceActiveFocus()
        }
        onAccepted: {
            if (mode === "file") win.openFile(workspace.createFile(field.text))
            else if (mode === "folder") workspace.createFolder(field.text)
            else win.openFolder(field.text)
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: prompt.mode === "path" ? "Un dossier ouvre le projet ; un fichier ouvre son projet et le fichier."
                                             : "Chemin relatif au projet ; les dossiers manquants sont créés (ex. src/utils/date.js)."
                color: theme.textDim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            TextField { id: field; Layout.fillWidth: true; onAccepted: prompt.accept() }
        }
    }

    // Closing a tab with unsaved changes.
    Dialog {
        id: confirmClose
        property int index: -1
        modal: true
        anchors.centerIn: parent
        width: 460
        title: "Enregistrer « " + (documents.at(index) ? documents.at(index).name : "") + " » ?"
        background: Rectangle { color: theme.surface; radius: 12; border.color: theme.line }
        function ask(i) { index = i; open() }
        Text { width: parent.width; text: "Tes modifications seront perdues si tu fermes sans enregistrer."; color: theme.textDim; wrapMode: Text.Wrap }
        footer: DialogButtonBox {
            background: null
            Button { text: "Ne pas enregistrer"; flat: true; DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
            Button { text: "Annuler"; flat: true; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
            Button { text: "Enregistrer"; highlighted: true; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            onClicked: (button) => {
                const role = button.DialogButtonBox.buttonRole
                const doc = documents.at(confirmClose.index)
                if (role === DialogButtonBox.AcceptRole && doc && !doc.save()) return
                if (role !== DialogButtonBox.RejectRole) documents.close(confirmClose.index)
                confirmClose.close()
            }
        }
    }

    // Quitting with unsaved files.
    Dialog {
        id: confirmQuit
        modal: true
        anchors.centerIn: parent
        width: 480
        title: documents.dirtyCount + " fichier(s) non enregistré(s)"
        background: Rectangle { color: theme.surface; radius: 12; border.color: theme.line }
        Text { width: parent.width; text: "Enregistrer avant de quitter ?"; color: theme.textDim; wrapMode: Text.Wrap }
        footer: DialogButtonBox {
            background: null
            Button { text: "Quitter sans enregistrer"; flat: true; DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
            Button { text: "Annuler"; flat: true; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
            Button { text: "Tout enregistrer"; highlighted: true; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            onClicked: (button) => {
                const role = button.DialogButtonBox.buttonRole
                confirmQuit.close()
                if (role === DialogButtonBox.RejectRole) return
                if (role === DialogButtonBox.AcceptRole && !documents.saveAll()) return
                win.quitting = true
                Qt.quit()
            }
        }
    }

    HelpOverlay { id: help; anchors.fill: parent; visible: false }
}
