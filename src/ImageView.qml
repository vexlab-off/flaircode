import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A picture opened as a tab: fitted to the window or at real size, on a
// checkerboard so transparency shows, reloaded when the file changes.
Rectangle {
    id: view
    required property var document
    property bool actualSize: false
    property int stamp: 0
    color: theme.background

    Connections {
        target: view.document
        function onReloaded() { view.stamp++ }
    }

    // Checkerboard
    Canvas {
        anchors.fill: frame
        onPaint: {
            const ctx = getContext("2d")
            const size = 10
            for (let y = 0; y < height; y += size)
                for (let x = 0; x < width; x += size) {
                    ctx.fillStyle = ((x + y) / size) % 2 === 0 ? "#2a2a2e" : "#1f1f23"
                    ctx.fillRect(x, y, size, size)
                }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: 34
        clip: true
        contentWidth: Math.max(width, frame.width + 40)
        contentHeight: Math.max(height, frame.height + 40)
        ScrollBar.vertical: ScrollBar {}
        ScrollBar.horizontal: ScrollBar {}

        Item {
            id: frame
            x: (flick.contentWidth - width) / 2
            y: (flick.contentHeight - height) / 2
            width: image.paintedWidth
            height: image.paintedHeight
        }
        Image {
            id: image
            anchors.centerIn: frame
            width: view.actualSize ? implicitWidth : Math.min(implicitWidth, flick.width - 40)
            height: view.actualSize ? implicitHeight : Math.min(implicitHeight, flick.height - 40)
            fillMode: Image.PreserveAspectFit
            cache: false
            smooth: !view.actualSize
            source: "file://" + view.document.path + "?" + view.stamp
            asynchronous: true
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 34
        color: theme.sidebar
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 14
            Text {
                text: image.status === Image.Ready ? image.sourceSize.width + " × " + image.sourceSize.height + " px"
                      : image.status === Image.Error ? "Format non pris en charge" : "Chargement…"
                color: theme.textDim
                font.pixelSize: 12
                font.features: { "tnum": 1 }
            }
            Text {
                visible: image.status === Image.Ready && !view.actualSize
                text: Math.round(image.paintedWidth / Math.max(1, image.sourceSize.width) * 100) + " %"
                color: theme.textFaint
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Button {
                text: view.actualSize ? "Ajuster à la fenêtre" : "Taille réelle"
                flat: true
                onClicked: view.actualSize = !view.actualSize
            }
        }
    }
}
