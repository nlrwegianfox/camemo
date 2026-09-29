import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Image {
        id: coverImage
        anchors.fill: parent
        source: "cover.png"
        fillMode: Image.PreserveAspectCrop
    }

    CoverActionList {
        id: coverAction

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                appWindow.openCreateNoteDialog()
            }
        }
    }
}
