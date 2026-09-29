import QtQuick 2.6
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "pages" // <-- Legg til denne linjen!

ApplicationWindow {
    id: appWindow
    initialPage: Component { FirstPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    // Funksjon som kalles fra coveret for å åpne CreateNoteDialog direkte
    function openCreateNoteDialog() {
        console.log("DEBUG: openCreateNoteDialog ble kalt fra coveret!")
        appWindow.activate()

        // Sender med python-objektet (py) og lytter på når brukeren trykker create
        var dialog = pageStack.push(Qt.resolvedUrl("pages/CreateNoteDialog.qml"), {
            "python": py
        })

        dialog.accepted.connect(function() {
            var content = dialog.noteContent ? dialog.noteContent.trim() : ""
            var folder = dialog.selectedFolder

            if (content.length > 0 && py.ready) {
                py.call("nb_backend.create_note", [content, folder], function(success) {
                    if (success) {
                        console.log("Notat opprettet vellykket fra cover!")
                    }
                })
            }
        })
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('.').replace('file://', ''))

            importModule('nb_backend', function() {
                console.log('nb_backend.py ble lastet inn!')
            })
        }
    }
}
