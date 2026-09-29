import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    property var pyRef: null

    ListModel {
        id: basketModel
    }

    function loadBasket() {
        basketModel.clear();
        py.call("nb_backend.get_basket_items", [], function(items) {
            if (items) {
                for (var i = 0; i < items.length; i++) {
                    basketModel.append(items[i]);
                }
            }
        });
    }

    RemorsePopup {
        id: remorsePopup
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../"))
            importModule("nb_backend", function() {
                page.loadBasket();
            });
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: basketModel

        PullDownMenu {
            MenuItem {
                text: I18n.tr("empty_trash")
                enabled: basketModel.count > 0
                onClicked: {
                    remorsePopup.execute(I18n.tr("empty_trash"), function() {
                        py.call("nb_backend.empty_basket", [], function(success) {
                            page.loadBasket();
                        });
                    });
                }
            }
        }

        header: PageHeader {
            title: I18n.tr("trash")
        }

        ViewPlaceholder {
            enabled: basketModel.count === 0
            text: I18n.tr("trash_empty")
        }

        delegate: ListItem {
            id: delegate
            width: listView.width
            contentHeight: Theme.itemSizeMedium

            menu: contextMenuComponent

            function restoreItem() {
                remorseAction(I18n.tr("restore") + " " + model.title, function() {
                    py.call("nb_backend.restore_basket_item", [model.basket_id], function(res) {
                        page.loadBasket();
                    });
                });
            }

            function deletePermanently() {
                remorseAction(I18n.tr("delete_permanently") + " " + model.title, function() {
                    py.call("nb_backend.delete_permanently", [model.basket_id], function(res) {
                        page.loadBasket();
                    });
                });
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMicro

                Row {
                    spacing: Theme.paddingMedium
                    Label {
                        text: model.is_dir ? "📂" : "📄"
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    Label {
                        text: model.title
                        font.bold: true
                        color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Elide
                    }
                }

                Label {
                    text: I18n.tr("original_path") + ": " + model.original_rel_path
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Elide
                    width: parent.width
                }
            }

            Component {
                id: contextMenuComponent
                ContextMenu {
                    MenuItem {
                        text: "🔄 " + I18n.tr("restore")
                        onClicked: delegate.restoreItem()
                    }
                    MenuItem {
                        text: "🗑️ " + I18n.tr("delete_permanently")
                        onClicked: delegate.deletePermanently()
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
