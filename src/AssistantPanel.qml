import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The AI pair programmer beside the code: pick Claude, OpenAI, Gemini or a
// local model, ask about the open file or the selection, and drop the
// answer's code straight into the editor.
Rectangle {
    id: panel
    property var editor: null
    readonly property var doc: editor ? editor.document : null
    readonly property string selection: editor ? editor.textEdit.selectedText.split(String.fromCharCode(0x2029)).join("\n") : ""
    color: theme.surface

    function ask(question) {
        if (!question.trim()) return
        assistant.send(question, doc ? doc.name : "", doc ? doc.language : "", editor ? editor.textEdit.text : "", selection)
        input.text = ""
    }
    function quick(kind) {
        assistant.quickAction(kind, doc ? doc.name : "", doc ? doc.language : "", editor ? editor.textEdit.text : "", selection)
    }
    function focusInput() { input.forceActiveFocus() }
    function insertCode(code, replace) {
        if (!editor) return
        const edit = editor.textEdit
        if (replace && edit.selectedText.length) {
            const s = edit.selectionStart
            edit.remove(edit.selectionStart, edit.selectionEnd)
            edit.insert(s, code)
            edit.select(s, s + code.length)
        } else {
            edit.insert(edit.cursorPosition, code)
        }
        edit.forceActiveFocus()
    }
    function copy(text) {
        clipboard.text = text
        clipboard.selectAll()
        clipboard.copy()
    }
    TextEdit { id: clipboard; visible: false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header and provider picker
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: 14
            Layout.rightMargin: 8
            spacing: 8
            Icon { name: "sparkle"; size: 16; color: theme.highlight }
            Text { Layout.fillWidth: true; text: "Assistant IA"; color: theme.text; font.pixelSize: 13; font.weight: Font.Bold }
            Rectangle {
                width: 26; height: 26; radius: 6
                visible: assistant.messages.length > 0
                color: clearHover.containsMouse ? theme.raised : "transparent"
                Icon { anchors.centerIn: parent; name: "refresh"; size: 13; color: theme.textDim }
                ToolTip.visible: clearHover.containsMouse
                ToolTip.text: "Nouvelle conversation"
                MouseArea { id: clearHover; anchors.fill: parent; hoverEnabled: true; onClicked: assistant.clear() }
            }
            Rectangle {
                width: 26; height: 26; radius: 6
                color: closeHover.containsMouse ? theme.raised : "transparent"
                Icon { anchors.centerIn: parent; name: "close"; size: 12; color: theme.textDim }
                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; onClicked: win.assistantVisible = false }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 10
            spacing: 6
            Repeater {
                model: (settings.revision, assistant.providers())
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool chosen: assistant.provider === modelData.key
                    width: providerRow.implicitWidth + 18
                    height: 28
                    radius: 14
                    color: chosen ? theme.alpha(theme.highlight, 0.16) : theme.background
                    border.color: chosen ? theme.highlight : theme.line
                    Row {
                        id: providerRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: modelData.ready ? theme.success : theme.textFaint
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: theme.text; font.pixelSize: 11; font.weight: parent.parent.chosen ? Font.DemiBold : Font.Normal }
                    }
                    ToolTip.visible: providerHover.containsMouse
                    ToolTip.text: modelData.ready ? (modelData.model || "modèle à choisir dans les réglages") : "Pas configuré : Ctrl+, → IA"
                    MouseArea { id: providerHover; anchors.fill: parent; hoverEnabled: true; onClicked: assistant.provider = modelData.key }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }

        // Conversation
        ListView {
            id: messages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 14
            topMargin: 12
            bottomMargin: 12
            model: assistant.messages
            onCountChanged: positionViewAtEnd()
            Connections { target: assistant; function onMessagesChanged() { messages.positionViewAtEnd() } }
            delegate: Item {
                id: message
                required property var modelData
                readonly property bool mine: modelData.role === "user"
                width: ListView.view.width
                height: mine ? bubble.height : answer.implicitHeight
                Rectangle {
                    id: bubble
                    visible: message.mine
                    x: 12
                    width: parent.width - 24
                    height: question.implicitHeight + 20 + (contextLine.visible ? 18 : 0)
                    radius: 10
                    color: theme.alpha(theme.highlight, 0.12)
                    Text {
                        id: question
                        x: 12; y: 10
                        width: parent.width - 24
                        text: message.modelData.text
                        color: theme.text
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        id: contextLine
                        visible: !!message.modelData.file
                        x: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: (message.modelData.hasSelection ? "Sélection de " : "") + (message.modelData.file || "")
                        color: theme.textFaint
                        font.pixelSize: 10
                    }
                }
                ColumnLayout {
                    id: answer
                    visible: !message.mine
                    x: 12
                    width: parent.width - 24
                    spacing: 8
                    Text {
                        visible: !message.modelData.text
                        text: "Réflexion…"
                        color: theme.textFaint
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: message.mine ? [] : assistant.segments(message.modelData.text || "")
                        delegate: Loader {
                            required property var modelData
                            Layout.fillWidth: true
                            sourceComponent: modelData.type === "code" ? codeBlock : textBlock
                            Component {
                                id: textBlock
                                TextEdit {
                                    readOnly: true
                                    selectByMouse: true
                                    textFormat: TextEdit.MarkdownText
                                    wrapMode: TextEdit.Wrap
                                    text: modelData.content
                                    color: theme.text
                                    font.pixelSize: 13
                                }
                            }
                            Component {
                                id: codeBlock
                                Rectangle {
                                    implicitHeight: codeColumn.implicitHeight
                                    radius: 8
                                    color: theme.background
                                    border.color: theme.line
                                    ColumnLayout {
                                        id: codeColumn
                                        width: parent.width
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            Layout.leftMargin: 10
                                            Layout.rightMargin: 4
                                            spacing: 2
                                            Text { Layout.fillWidth: true; text: modelData.language || "code"; color: theme.textFaint; font.pixelSize: 11 }
                                            CodeAction { label: "Copier"; onClicked: panel.copy(modelData.content) }
                                            CodeAction { label: "Insérer"; onClicked: panel.insertCode(modelData.content, false) }
                                            CodeAction {
                                                label: "Remplacer la sélection"
                                                visible: panel.selection.length > 0
                                                accent: true
                                                onClicked: panel.insertCode(modelData.content, true)
                                            }
                                        }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }
                                        TextEdit {
                                            Layout.fillWidth: true
                                            Layout.margins: 10
                                            readOnly: true
                                            selectByMouse: true
                                            wrapMode: TextEdit.WrapAnywhere
                                            text: modelData.content
                                            color: theme.text
                                            font.family: editor ? editor.monoFamily : "monospace"
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state: what the assistant can do
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: messages.count === 0
                spacing: 10
                Icon { Layout.alignment: Qt.AlignHCenter; name: "sparkle"; size: 30; color: theme.textFaint; stroke: 1.3 }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pose une question sur ton code"
                    color: theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "L'assistant voit le fichier ouvert et ta sélection. Ctrl+K sur une sélection la réécrit sur place. Les boutons ci-dessous lancent les demandes courantes."
                    color: theme.textDim
                    font.pixelSize: 12
                }
            }
        }

        Text {
            visible: assistant.error !== ""
            Layout.fillWidth: true
            Layout.margins: 12
            text: assistant.error
            color: theme.danger
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        // Quick actions
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            spacing: 6
            Repeater {
                model: [["explain", "Expliquer"], ["fix", "Corriger"], ["document", "Documenter"], ["tests", "Tests"], ["optimize", "Optimiser"], ["review", "Revue"]]
                delegate: Rectangle {
                    required property var modelData
                    width: chip.implicitWidth + 18
                    height: 26
                    radius: 13
                    color: chipHover.containsMouse ? theme.raised : "transparent"
                    border.color: theme.line
                    Text { id: chip; anchors.centerIn: parent; text: modelData[1]; color: theme.textDim; font.pixelSize: 11 }
                    MouseArea { id: chipHover; anchors.fill: parent; hoverEnabled: true; enabled: !assistant.busy; onClicked: panel.quick(modelData[0]) }
                }
            }
        }

        // Input
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            Layout.preferredHeight: Math.min(160, input.implicitHeight + 40)
            radius: 10
            color: theme.background
            border.color: input.activeFocus ? theme.highlight : theme.line
            ScrollView {
                anchors.fill: parent
                anchors.margins: 4
                anchors.bottomMargin: 28
                TextArea {
                    id: input
                    wrapMode: TextEdit.Wrap
                    placeholderText: "Demande quelque chose… (Entrée pour envoyer, Maj+Entrée pour aller à la ligne)"
                    background: null
                    font.pixelSize: 13
                    Keys.onReturnPressed: (event) => {
                        if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return }
                        panel.ask(input.text)
                    }
                    Keys.onEscapePressed: if (panel.editor) panel.editor.textEdit.forceActiveFocus()
                }
            }
            RowLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 6
                anchors.leftMargin: 10
                Text {
                    Layout.fillWidth: true
                    text: panel.doc ? ("Contexte : " + panel.doc.name + (panel.selection ? " · sélection de " + panel.selection.split("\n").length + " ligne(s)" : "")) : "Aucun fichier ouvert"
                    color: theme.textFaint
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Button {
                    text: assistant.busy ? "Arrêter" : "Envoyer"
                    flat: !assistant.busy
                    highlighted: !assistant.busy
                    Material.accent: theme.highlight
                    implicitHeight: 30
                    onClicked: assistant.busy ? assistant.stop() : panel.ask(input.text)
                }
            }
        }
    }

    component CodeAction: Rectangle {
        id: action
        property string label
        property bool accent: false
        signal clicked()
        width: actionText.implicitWidth + 14
        height: 22
        radius: 5
        color: actionHover.containsMouse ? (accent ? theme.alpha(theme.highlight, 0.2) : theme.raised) : (accent ? theme.alpha(theme.highlight, 0.1) : "transparent")
        Text { id: actionText; anchors.centerIn: parent; text: action.label; color: action.accent ? theme.highlight : theme.textDim; font.pixelSize: 11 }
        MouseArea { id: actionHover; anchors.fill: parent; hoverEnabled: true; onClicked: action.clicked() }
    }
}
