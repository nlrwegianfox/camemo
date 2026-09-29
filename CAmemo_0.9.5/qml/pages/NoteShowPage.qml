import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    property string noteId: ""
    property string rawNoteText: ""
    property string formattedHtml: ""
    property string currentLanguage: I18n.currentLang
    property var python: pythonInstance // Gjør python tilgjengelig for vedhjelpt side

    // Avansert Markdown-parser tilpasset Sailfish OS
    function parseMarkdown(text) {
        if (!text) return ""

        var lines = text.split("\n")
        var htmlResult = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            if (line.match(/^#\s+(.*)/)) {
                line = "<font size='+2'><b>" + line.replace(/^#\s+/, "") + "</b></font>"
            } else if (line.match(/^##\s+(.*)/)) {
                line = "<font size='+1'><b>" + line.replace(/^##\s+/, "") + "</b></font>"
            } else if (line.match(/^###\s+(.*)/)) {
                line = "<b>" + line.replace(/^###\s+/, "") + "</b>"
            } else if (line.match(/^\s*\[\s*\]\s+(.*)/)) {
                line = "&nbsp;&nbsp;&nbsp;&nbsp;☐ " + line.replace(/^\s*\[\s*\]\s+/, "")
            } else if (line.match(/^\s*\[[xX]\]\s+(.*)/)) {
                line = "&nbsp;&nbsp;&nbsp;&nbsp;☑ <s>" + line.replace(/^\s*\[[xX]\]\s+/, "") + "</s>"
            } else if (line.match(/^\s*[-\*]\s+(.*)/)) {
                line = "&nbsp;&nbsp;&nbsp;&nbsp;&bull;&nbsp;" + line.replace(/^\s*[-\*]\s+/, "")
            } else {
                if (line.trim() === "") {
                    line = "<br>"
                }
            }

            line = line.replace(/\*\*(.*?)\*\*/g, "<b>$1</b>")
            line = line.replace(/\*(.*?)\*/g, "<i>$1</i>")
            line = line.replace(/(^|\s)(#[a-zA-Z0-9_æøåÆØÅ]+)/g, "$1<b><i>$2</i></b>")

            htmlResult.push(line)
        }

        return htmlResult.join("<br>")
    }

    Python {
        id: pythonInstance

        Component.onCompleted: {
            var resolved = Qt.resolvedUrl("../").toString()
            var importPath = resolved.replace(/^file:\/\//, "")
            addImportPath(importPath)

            importModule("nb_backend", function() {
                call("nb_backend.get_setting", ["language", "en"], function(lang) {
                    if (lang) {
                        I18n.currentLang = lang
                        page.currentLanguage = lang
                    }
                })
                loadNoteContent()
            })
        }

        function loadNoteContent() {
            call("nb_backend.get_note_content", [noteId], function(result) {
                page.rawNoteText = result
                page.formattedHtml = parseMarkdown(result)
            })
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            page.currentLanguage = I18n.currentLang
            if (pythonInstance) {
                pythonInstance.loadNoteContent()
            }

            // Kobler NoteEditPage direkte på som vedhjelpt side (sveip til venstre)
            if (!page.attachedPage) {
                pageStack.pushAttached(Qt.resolvedUrl("NoteEditPage.qml"), {
                    noteId: page.noteId,
                    python: pythonInstance
                })
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: page.currentLanguage ? I18n.tr("edit_note") : "Rediger notat"
                onClicked: pageStack.push(Qt.resolvedUrl("NoteEditPage.qml"), { noteId: page.noteId, python: pythonInstance })
            }
        }

        Column {
            id: column
            width: parent.width - (2 * Theme.horizontalPageMargin)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.currentLanguage ? I18n.tr("show_note") : "Vis notat"
            }

            Label {
                width: parent.width
                text: page.formattedHtml
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }
}
