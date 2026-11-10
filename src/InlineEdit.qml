import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Ctrl+K: describe a change, the AI rewrites the selection (or writes at the
// cursor), and nothing changes in the file until you accept.
Popup {
    id: inline
    property var editor: null
    property int start: 0
    property int end: 0
    property string original: ""

    modal: false
    focus: true
    x: (parent.width - width) / 2
    y: 56
    width: Math.min(parent.width - 60, 720)
    padding: 12
    closePolicy: Popup.CloseOnEscape
    background: Rectangle { color: theme.surface; radius: 12; border.color: theme.highlight }

    function show() {
        if (!editor) return
        const edit = editor.textEdit
        start = Math.min(edit.selectionStart, edit.selectionEnd)
        end = Math.max(edit.selectionStart, edit.selectionEnd)
        original = edit.getText(start, end)
        instruction.text = ""
        assistant.clearInline()
        open()
        instruction.forceActiveFocus()
    }
    function run() {
        const edit = editor.textEdit
        assistant.inlineEdit(instruction.text, editor.document.name, editor.document.language,
                             edit.getText(Math.max(0, start - 6000), start), original,
                             edit.getText(end, Math.min(edit.length, end + 3000)))
    }
    function accept() {
        if (!assistant.inlineResult || assistant.inlineBusy) return
        const edit = editor.textEdit
        edit.remove(start, end)
        edit.insert(start, assistant.inlineResult)
        edit.select(start, start + assistant.inlineResult.length)
        close()
        edit.forceActiveFocus()
    }
    onClosed: { assistant.clearInline(); if (editor) editor.textEdit.forceActiveFocus() }

    Shortcut { sequences: ["Ctrl+Return", "Ctrl+Enter"]; enabled: inline.visible; onActivated: inline.accept() }

    ColumnLayout {
        width: parent.width
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Icon { name: "sparkle"; size: 16; color: theme.highlight }
            TextField {
                id: instruction
                Layout.fillWidth: true
                background: null
                font.pixelSize: 14
                placeholderText: inline.original ? "Que faire de la sélection ? (« ajoute la gestion d'erreur », « passe en async »…)"
                                                 : "Que faut-il écrire ici ? (« une fonction qui trie les noms »…)"
                onAccepted: inline.run()
            }
            Text {
                text: assistant.provider ? "via " + (assistant.provider === "openai" ? "OpenAI" : assistant.provider === "gemini" ? "Gemini" : assistant.provider === "local" ? "local" : "Claude") : ""
                color: theme.textFaint
                font.pixelSize: 11
            }
        }

        // Before / after
        GridLayout {
            visible: assistant.inlineResult !== "" || assistant.inlineBusy
            Layout.fillWidth: true
            columns: inline.original ? 2 : 1
            columnSpacing: 8
            rowSpacing: 4
            Text { visible: !!inline.original; text: "Avant"; color: theme.textFaint; font.pixelSize: 11 }
            Text { text: assistant.inlineBusy ? "Écriture…" : "Après"; color: theme.highlight; font.pixelSize: 11 }
            Repeater {
                model: inline.original ? [inline.original, assistant.inlineResult] : [assistant.inlineResult]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(300, codeText.implicitHeight + 16)
                    radius: 8
                    color: theme.alpha(index === 0 && inline.original ? theme.danger : theme.success, 0.07)
                    border.color: theme.line
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        Text {
                            id: codeText
                            text: modelData
                            color: theme.text
                            font.family: inline.editor ? inline.editor.monoFamily : "monospace"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Text {
            visible: assistant.error !== ""
            Layout.fillWidth: true
            text: assistant.error
            color: theme.danger
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "Entrée : générer · Ctrl+Entrée : accepter · Échap : annuler"
                color: theme.textFaint
                font.pixelSize: 11
            }
            Button { text: "Annuler"; flat: true; onClicked: inline.close() }
            Button {
                visible: assistant.inlineResult !== ""
                text: "Réessayer"
                flat: true
                enabled: !assistant.inlineBusy
                onClicked: inline.run()
            }
            PrimaryButton {
                text: assistant.inlineResult ? "Accepter" : "Générer"
                enabled: !assistant.inlineBusy && instruction.text.trim() !== ""
                onClicked: assistant.inlineResult ? inline.accept() : inline.run()
            }
        }
    }
}
