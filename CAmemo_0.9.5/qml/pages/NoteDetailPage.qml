import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: detailPage
    allowedOrientations: Orientation.All

    // Egenskaper som mottas når siden åpnes (fra FavoritesPage / AllNotesPage)
    property string noteTitle: ""
    property string noteId: ""
    property string currentLanguage: I18n.currentLang

    onStatusChanged: {
        if (status === PageStatus.Active) {
            detailPage.currentLanguage = I18n.currentLang
        }
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../"))
            importModule("nb_backend", function() {
                // Henter lagret språk fra config
                call("nb_backend.get_setting", ["language", "en"], function(lang) {
                    if (lang) {
                        I18n.currentLang = lang
                        detailPage.currentLanguage = lang
                    }
                })
                hentInnhold()
            })
        }

        function hentInnhold() {
            var cleanId = noteId.toString()
            if (cleanId.indexOf("]") !== -1) {
                cleanId = cleanId.split("]")[0].replace("[", "").trim()
            }

            call("nb_backend.get_note_content", [cleanId], function(result) {
                if (result !== undefined && result !== null) {
                    noteTextArea.text = result
                } else {
                    noteTextArea.text = detailPage.currentLanguage ? I18n.tr("could_not_load") : "Could not load content."
                }
            })
        }

        function lagreInnhold(tekst) {
            var cleanId = noteId.toString()
            if (cleanId.indexOf("]") !== -1) {
                cleanId = cleanId.split("]")[0].replace("[", "").trim()
            }

            var safeText = tekst ? tekst.toString() : ""

            call("nb_backend.save_note_content", [cleanId, safeText], function(result) {
                if (result === "OK") {
                    console.log("Notat lagret!")
                } else {
                    console.log("Feil ved lagring:", result)
                }
            })
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: detailPage.currentLanguage ? I18n.tr("save") : ""
                onClicked: {
                    noteTextArea.focus = false
                    python.lagreInnhold(noteTextArea.text)
                }
            }
        }

        Column {
            id: column
            width: detailPage.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: noteTitle !== "" ? noteTitle : (detailPage.currentLanguage ? I18n.tr("edit_note") : "")
            }

            TextArea {
                id: noteTextArea
                width: parent.width - (2 * Theme.horizontalPageMargin)
                x: Theme.horizontalPageMargin
                readOnly: false
                text: detailPage.currentLanguage ? I18n.tr("loading") : "Loading..."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                placeholderText: detailPage.currentLanguage ? I18n.tr("write_here") : ""
                label: detailPage.currentLanguage ? I18n.tr("edit_note") : ""
            }
        }
    }
}
