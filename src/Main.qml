import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "brands.js" as Brands

ApplicationWindow {
    id: win
    width: 1480
    height: 900
    minimumWidth: 760
    minimumHeight: 480
    visible: true
    title: (documents.currentDocument ? documents.currentDocument.name + " — " : "")
           + (workspace.root ? workspace.name + " — " : "") + "Flair Code"
    color: theme.background

    Material.theme: theme.isDark ? Material.Dark : Material.Light
    Material.accent: theme.highlight
    Material.background: theme.surface
    Material.foreground: theme.text

    property bool sidebarVisible: true
    property bool assistantVisible: false
    property bool previewVisible: false
    property bool quitting: false
    readonly property var currentTab: editors.count > 0 && documents.current >= 0 ? editors.itemAt(documents.current) : null
    readonly property var currentEditor: currentTab && currentTab.item && currentTab.item.textEdit ? currentTab.item : null
    function opt(key) { return settings.revision, settings.value(key) }

    // ------------------------------------------------------------ actions
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
    function saveDocument(doc) {
        if (doc && doc.save(opt("editor/trimTrailing"), opt("editor/finalNewline"))) {
            status.flash("Enregistré : " + doc.name)
            workspace.refreshBranch()
        }
    }
    function save() { saveDocument(documents.currentDocument) }
    function closeTab(index) {
        const doc = documents.at(index)
        if (!doc) return
        if (doc.dirty) { confirmClose.ask(index); return }
        documents.close(index)
    }
    function goToLine(line) { if (currentEditor) currentEditor.goToLine(line) }
    function showAssistant() {
        assistantVisible = true
        Qt.callLater(() => assistantPanel.focusInput())
    }
    function quickAI(kind) {
        if (!currentEditor) { status.flash("Ouvre d'abord un fichier."); return }
        assistantVisible = true
        assistantPanel.quick(kind)
    }
    function setFontSize(size) { settings.set("editor/fontSize", Math.max(9, Math.min(32, size))) }
    function insertSnippet(prefix) {
        if (!currentEditor) return
        const edit = currentEditor.textEdit
        edit.insert(edit.cursorPosition, prefix)
        currentEditor.tryExpandSnippet()
        edit.forceActiveFocus()
    }

    // Every command, for the palette, the shortcuts, the help and the settings.
    readonly property bool hasEditor: currentEditor !== null
    readonly property var commands: [
        // Files
        { id: "openFolder", category: "Fichiers", name: "Ouvrir un dossier", description: "Choisir un projet avec le sélecteur du système", shortcut: "Ctrl+O", sequence: "Ctrl+O", run: () => workspace.pickFolder() },
        { id: "openPath", category: "Fichiers", name: "Ouvrir un chemin", description: "Taper le chemin d'un dossier ou d'un fichier", shortcut: "Ctrl+Maj+O", sequence: "Ctrl+Shift+O", run: () => prompt.ask("path") },
        { id: "quickOpen", category: "Fichiers", name: "Aller à un fichier", description: "Trouver un fichier du projet par quelques lettres", shortcut: "Ctrl+P", sequence: "Ctrl+P", run: () => quickOpen.show(), enabled: () => workspace.root !== "" },
        { id: "newFile", category: "Fichiers", name: "Nouveau fichier", description: "Créer un fichier dans le projet", shortcut: "Ctrl+N", sequence: "Ctrl+N", run: () => prompt.ask("file"), enabled: () => workspace.root !== "" },
        { id: "newFolder", category: "Fichiers", name: "Nouveau dossier", description: "Créer un dossier dans le projet", run: () => prompt.ask("folder"), enabled: () => workspace.root !== "" },
        { id: "save", category: "Fichiers", name: "Enregistrer", description: "Enregistrer le fichier courant", shortcut: "Ctrl+S", sequence: "Ctrl+S", run: () => win.save() },
        { id: "saveAll", category: "Fichiers", name: "Tout enregistrer", description: "Enregistrer tous les fichiers modifiés", shortcut: "Ctrl+Maj+S", sequence: "Ctrl+Shift+S", run: () => { if (documents.saveAll()) status.flash("Tout est enregistré.") } },
        { id: "close", category: "Fichiers", name: "Fermer l'onglet", description: "Fermer le fichier courant (demande s'il n'est pas enregistré)", shortcut: "Ctrl+W", sequence: "Ctrl+W", run: () => win.closeTab(documents.current) },
        { id: "nextTab", category: "Fichiers", name: "Onglet suivant", description: "Passer à l'onglet de droite", shortcut: "Ctrl+Tab", sequence: "Ctrl+Tab", run: () => documents.next(1) },
        { id: "prevTab", category: "Fichiers", name: "Onglet précédent", description: "Passer à l'onglet de gauche", shortcut: "Ctrl+Maj+Tab", sequence: "Ctrl+Shift+Tab", run: () => documents.next(-1) },
        { id: "refreshTree", category: "Fichiers", name: "Actualiser l'arborescence", description: "Relire les fichiers du projet", shortcut: "F5", sequence: "F5", run: () => workspace.tree.refresh() },
        // Editing
        { id: "comment", category: "Édition", name: "Commenter les lignes", description: "Ajouter ou retirer le commentaire des lignes sélectionnées", shortcut: "Ctrl+/  ·  Ctrl+:", run: () => win.currentEditor.toggleComment(), enabled: () => win.hasEditor },
        { id: "duplicate", category: "Édition", name: "Dupliquer la ligne", description: "Copier la ligne (ou les lignes) juste en dessous", shortcut: "Ctrl+Maj+D", run: () => win.currentEditor.duplicateLine(), enabled: () => win.hasEditor },
        { id: "deleteLine", category: "Édition", name: "Supprimer la ligne", description: "Effacer la ligne entière", shortcut: "Ctrl+Maj+K", run: () => win.currentEditor.deleteLine(), enabled: () => win.hasEditor },
        { id: "moveUp", category: "Édition", name: "Monter la ligne", description: "Déplacer la ligne d'un cran vers le haut", shortcut: "Alt+↑", run: () => win.currentEditor.moveLines(-1), enabled: () => win.hasEditor },
        { id: "moveDown", category: "Édition", name: "Descendre la ligne", description: "Déplacer la ligne d'un cran vers le bas", shortcut: "Alt+↓", run: () => win.currentEditor.moveLines(1), enabled: () => win.hasEditor },
        { id: "indent", category: "Édition", name: "Indenter", description: "Décaler les lignes vers la droite (ou développer un snippet)", shortcut: "Tab", run: () => win.currentEditor.indentLines(), enabled: () => win.hasEditor },
        { id: "outdent", category: "Édition", name: "Désindenter", description: "Décaler les lignes vers la gauche", shortcut: "Maj+Tab", run: () => win.currentEditor.outdentLines(), enabled: () => win.hasEditor },
        { id: "undo", category: "Édition", name: "Annuler", description: "Défaire la dernière modification", shortcut: "Ctrl+Z", run: () => win.currentEditor.textEdit.undo(), enabled: () => win.hasEditor },
        { id: "redo", category: "Édition", name: "Rétablir", description: "Refaire ce qui a été annulé", shortcut: "Ctrl+Maj+Z", run: () => win.currentEditor.textEdit.redo(), enabled: () => win.hasEditor },
        { id: "selectAll", category: "Édition", name: "Tout sélectionner", description: "Sélectionner tout le fichier", shortcut: "Ctrl+A", run: () => win.currentEditor.textEdit.selectAll(), enabled: () => win.hasEditor },
        // Navigation
        { id: "find", category: "Recherche", name: "Rechercher", description: "Chercher du texte dans le fichier", shortcut: "Ctrl+F", sequence: "Ctrl+F", run: () => findBar.show(false), enabled: () => win.hasEditor },
        { id: "replace", category: "Recherche", name: "Remplacer", description: "Chercher et remplacer dans le fichier", shortcut: "Ctrl+H", sequence: "Ctrl+H", run: () => findBar.show(true), enabled: () => win.hasEditor },
        { id: "findNext", category: "Recherche", name: "Résultat suivant", description: "Aller à l'occurrence suivante", shortcut: "F3", sequence: "F3", run: () => findBar.find(true) },
        { id: "findPrev", category: "Recherche", name: "Résultat précédent", description: "Aller à l'occurrence précédente", shortcut: "Maj+F3", sequence: "Shift+F3", run: () => findBar.find(false) },
        { id: "goto", category: "Recherche", name: "Aller à la ligne", description: "Sauter à un numéro de ligne", shortcut: "Ctrl+G", sequence: "Ctrl+G", run: () => palette.show(":"), enabled: () => win.hasEditor },
        { id: "palette", category: "Recherche", name: "Palette de commandes", description: "Trouver n'importe quelle commande par son nom", shortcut: "Ctrl+Maj+P", sequence: "Ctrl+Shift+P", run: () => palette.show("") },
        // AI
        { id: "assistant", category: "IA", name: "Assistant IA", description: "Discuter avec Claude, OpenAI, Gemini ou un modèle local à propos du code", shortcut: "Ctrl+L", sequences: ["Ctrl+L", "Ctrl+I"], run: () => win.assistantVisible && assistantPanel.activeFocus ? (win.assistantVisible = false) : win.showAssistant() },
        { id: "inline", category: "IA", name: "Modifier avec l'IA", description: "Réécrire la sélection (ou écrire au curseur) en décrivant le changement", shortcut: "Ctrl+K", sequence: "Ctrl+K", run: () => inlineEdit.show(), enabled: () => win.hasEditor },
        { id: "explain", category: "IA", name: "IA : expliquer", description: "Expliquer la sélection ou le fichier", run: () => win.quickAI("explain"), enabled: () => win.hasEditor },
        { id: "fix", category: "IA", name: "IA : corriger les bugs", description: "Trouver et corriger les erreurs", run: () => win.quickAI("fix"), enabled: () => win.hasEditor },
        { id: "doc", category: "IA", name: "IA : documenter", description: "Ajouter commentaires et documentation", run: () => win.quickAI("document"), enabled: () => win.hasEditor },
        { id: "tests", category: "IA", name: "IA : écrire des tests", description: "Générer des tests unitaires", run: () => win.quickAI("tests"), enabled: () => win.hasEditor },
        { id: "optimize", category: "IA", name: "IA : optimiser", description: "Simplifier et accélérer le code", run: () => win.quickAI("optimize"), enabled: () => win.hasEditor },
        { id: "review", category: "IA", name: "IA : revue de code", description: "Bugs, sécurité et lisibilité", run: () => win.quickAI("review"), enabled: () => win.hasEditor },
        // View
        { id: "sidebar", category: "Affichage", name: "Arborescence", description: "Afficher ou masquer les fichiers du projet", shortcut: "Ctrl+B", sequence: "Ctrl+B", run: () => win.sidebarVisible = !win.sidebarVisible },
        { id: "preview", category: "Affichage", name: "Aperçu en direct", description: "HTML, SVG, Markdown et images à côté du code, mis à jour à chaque frappe", shortcut: "Ctrl+Maj+V", sequence: "Ctrl+Shift+V", run: () => win.previewVisible = !win.previewVisible },
        { id: "zoomIn", category: "Affichage", name: "Agrandir le texte", description: "Augmenter la taille du code", shortcut: "Ctrl+=", sequences: ["Ctrl+=", "Ctrl++"], run: () => win.setFontSize(win.opt("editor/fontSize") + 1) },
        { id: "zoomOut", category: "Affichage", name: "Réduire le texte", description: "Diminuer la taille du code", shortcut: "Ctrl+-", sequence: "Ctrl+-", run: () => win.setFontSize(win.opt("editor/fontSize") - 1) },
        { id: "zoomReset", category: "Affichage", name: "Taille par défaut", description: "Revenir à 14 px", shortcut: "Ctrl+0", sequence: "Ctrl+0", run: () => win.setFontSize(14) },
        { id: "wrap", category: "Affichage", name: "Retour à la ligne", description: "Activer ou couper le retour à la ligne automatique", shortcut: "Alt+Z", sequence: "Alt+Z", run: () => settings.set("editor/wordWrap", !win.opt("editor/wordWrap")) },
        { id: "theme", category: "Affichage", name: "Changer de thème", description: "Passer au thème d'éditeur suivant (Vex, Braise, Minuit, Contraste, Papier)", shortcut: "Ctrl+Maj+T", sequence: "Ctrl+Shift+T", run: () => { const keys = ["vex", "braise", "minuit", "contraste", "papier"]; settings.set("appearance/scheme", keys[(keys.indexOf(scheme.scheme) + 1) % keys.length]); status.flash("Thème : " + scheme.scheme) } },
        // App
        { id: "settings", category: "Application", name: "Réglages", description: "Couleurs, éditeur, IA, raccourcis", shortcut: "Ctrl+,", sequence: "Ctrl+,", run: () => settingsDialog.openAt("appearance") },
        { id: "colors", category: "Application", name: "Réglages : couleurs du code", description: "Une couleur et un style par élément de syntaxe", run: () => settingsDialog.openAt("syntax") },
        { id: "aiSettings", category: "Application", name: "Réglages : IA", description: "Clés et modèles de Claude, OpenAI, Gemini, local", run: () => settingsDialog.openAt("ai") },
        { id: "help", category: "Application", name: "Aide", description: "Raccourcis, snippets, IA et astuces", shortcut: "F1", sequence: "F1", run: () => help.visible ? (help.visible = false) : help.show("keys") },
        { id: "snippetHelp", category: "Application", name: "Liste des snippets", description: "Tous les raccourcis de code du langage courant", run: () => help.show("snippets") },
        { id: "quit", category: "Application", name: "Quitter", description: "Fermer Flair Code (demande pour les fichiers non enregistrés)", shortcut: "Ctrl+Q", sequence: "Ctrl+Q", run: () => win.close() }
    ]

    // The palette also offers the current language's snippets.
    function paletteCommands() {
        const list = commands.slice()
        if (currentEditor) {
            for (const s of snippets.forLanguage(currentEditor.document.language))
                list.push({ id: "snippet-" + s.prefix, category: "Snippets", name: "Snippet " + s.prefix + " : " + s.description,
                            description: s.preview.split("\n")[0], shortcut: s.prefix + " ⇥", run: ((p) => () => win.insertSnippet(p))(s.prefix) })
        }
        return list
    }

    Instantiator {
        model: win.commands.filter(c => c.sequence || c.sequences)
        delegate: Shortcut {
            required property var modelData
            sequences: modelData.sequences || [modelData.sequence]
            context: Qt.ApplicationShortcut
            enabled: !modelData.enabled || modelData.enabled()
            onActivated: modelData.run()
        }
    }
    Shortcut {
        sequence: "Escape"; context: Qt.ApplicationShortcut
        enabled: help.visible || findBar.visible
        onActivated: { help.visible = false; findBar.hide() }
    }

    onClosing: (close) => {
        if (documents.dirtyCount > 0 && !quitting) {
            close.accepted = false
            confirmQuit.open()
        }
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
                    spacing: 8
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
                    IconButton { icon: "refresh"; tip: "Actualiser (F5)"; onClicked: workspace.tree.refresh() }
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
                        readonly property bool isImage: !isDir && /\.(png|jpe?g|gif|webp|bmp|ico|avif|tiff?)$/i.test(name)
                        width: ListView.view.width
                        height: 26
                        color: active ? theme.alpha(theme.highlight, 0.14) : (nodeHover.containsMouse ? theme.alpha(theme.text, 0.04) : "transparent")
                        Row {
                            x: 10 + node.depth * 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron"; size: 12
                                opacity: node.isDir ? 1 : 0
                                rotation: node.expanded ? 90 : 0
                                color: theme.textFaint
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: node.isDir ? "folder" : (node.isImage ? "image" : "file")
                                brand: node.brand
                                size: 14
                                color: node.isDir ? theme.kindColor("dossier") : (node.isImage ? theme.kindColor("image") : theme.textDim)
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

            // Tabs and the toolbar on their right
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: theme.sidebar
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.line }
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    ListView {
                        id: tabs
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: /\.(png|jpe?g|gif|webp|bmp|ico|avif)$/i.test(tab.name) ? "image" : "file"; brand: Brands.forFile(tab.name); size: 14; color: theme.textDim }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.name
                                    color: tab.active ? theme.text : theme.textDim
                                    font.pixelSize: 12
                                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                                }
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
                    Row {
                        Layout.rightMargin: 8
                        spacing: 2
                        IconButton { icon: "search"; tip: "Palette de commandes (Ctrl+Maj+P)"; onClicked: palette.show("") }
                        IconButton { icon: "eye"; tip: "Aperçu en direct (Ctrl+Maj+V)"; active: win.previewVisible; onClicked: win.previewVisible = !win.previewVisible }
                        IconButton { icon: "sparkle"; tip: "Assistant IA (Ctrl+L)"; active: win.assistantVisible; onClicked: win.assistantVisible ? (win.assistantVisible = false) : win.showAssistant() }
                        IconButton { icon: "sliders"; tip: "Réglages (Ctrl+,)"; onClicked: settingsDialog.openAt("appearance") }
                        IconButton { icon: "info"; tip: "Aide (F1)"; onClicked: help.show("keys") }
                    }
                }
            }

            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal
                handle: Rectangle {
                    implicitWidth: 1
                    color: SplitHandle.hovered || SplitHandle.pressed ? theme.highlight : theme.line
                }

                // Editors and image views, one per open file.
                Item {
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 320
                    StackLayout {
                        id: stack
                        anchors.fill: parent
                        visible: documents.count > 0
                        currentIndex: documents.current
                        Repeater {
                            id: editors
                            model: documents
                            delegate: Loader {
                                required property var document
                                // The loaded view's own `document` is set from here.
                                Component.onCompleted: setSource(document.isImage ? "qrc:/ImageView.qml" : "qrc:/Editor.qml", { document: document })
                            }
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
                    Welcome {
                        anchors.fill: parent
                        visible: documents.count === 0
                    }
                }

                PreviewPane {
                    id: previewPane
                    visible: win.previewVisible
                    SplitView.preferredWidth: 460
                    SplitView.minimumWidth: 260
                    editor: win.currentEditor
                }

                AssistantPanel {
                    id: assistantPanel
                    visible: win.assistantVisible
                    SplitView.preferredWidth: 420
                    SplitView.minimumWidth: 300
                    editor: win.currentEditor
                }
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
                        text: status.message || (assistant.busy ? "L'assistant écrit…" : "")
                        color: theme.textDim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    StatusItem {
                        visible: win.currentEditor !== null
                        text: win.currentEditor ? "Ln " + (win.currentEditor.currentLine + 1) + ", Col " + win.currentEditor.currentColumn : ""
                        onClicked: palette.show(":")
                    }
                    StatusItem {
                        visible: win.currentEditor !== null
                        text: (win.opt("editor/insertSpaces") ? "Espaces : " : "Tabulations : ") + win.opt("editor/tabWidth")
                        onClicked: settingsDialog.openAt("editor")
                    }
                    StatusItem { visible: win.currentEditor !== null; text: "UTF-8" }
                    StatusItem {
                        visible: !!documents.currentDocument
                        text: documents.currentDocument ? documents.currentDocument.languageName : ""
                        onClicked: help.show("snippets")
                    }
                    Icon { name: "sparkle"; size: 11; color: theme.highlight }
                    StatusItem {
                        text: (assistant.provider === "openai" ? "OpenAI" : assistant.provider === "gemini" ? "Gemini" : assistant.provider === "local" ? "Local" : "Claude")
                        onClicked: win.showAssistant()
                    }
                    Text {
                        visible: documents.dirtyCount > 0
                        text: documents.dirtyCount + " non enregistré" + (documents.dirtyCount > 1 ? "s" : "")
                        color: theme.highlight
                        font.pixelSize: 11
                    }
                    Row {
                        spacing: 4
                        Keycap { text: "Ctrl+Maj+P" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "commandes"; color: theme.textFaint; font.pixelSize: 11 }
                    }
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon
        property string tip
        property bool active: false
        signal clicked()
        width: 28; height: 28; radius: 6
        color: active ? theme.alpha(theme.highlight, 0.16) : (ibHover.containsMouse ? theme.raised : "transparent")
        Icon { anchors.centerIn: parent; name: ib.icon; size: 14; color: ib.active ? theme.highlight : theme.textDim }
        ToolTip.visible: ibHover.containsMouse
        ToolTip.text: ib.tip
        ToolTip.delay: 400
        MouseArea { id: ibHover; anchors.fill: parent; hoverEnabled: true; onClicked: ib.clicked() }
    }

    component StatusItem: Text {
        id: si
        signal clicked()
        color: siHover.containsMouse ? theme.text : theme.textDim
        font.pixelSize: 11
        font.features: { "tnum": 1 }
        MouseArea { id: siHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: si.clicked() }
    }

    QuickOpen { id: quickOpen; onPicked: (path) => { win.openFile(path); workspace.tree.reveal(path) } }
    CommandPalette { id: palette; commands: win.paletteCommands() }
    InlineEdit { id: inlineEdit; editor: win.currentEditor }
    SettingsDialog { id: settingsDialog }

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
            PrimaryButton { text: "Enregistrer"; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            onClicked: (button) => {
                const role = button.DialogButtonBox.buttonRole
                const doc = documents.at(confirmClose.index)
                if (role === DialogButtonBox.AcceptRole && doc && !doc.save(win.opt("editor/trimTrailing"), win.opt("editor/finalNewline"))) return
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
            PrimaryButton { text: "Tout enregistrer"; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
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
