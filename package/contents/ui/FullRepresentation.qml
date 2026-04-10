import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: fullRoot

    // Accessed from PlasmoidItem (parent)
    readonly property var    model:        parent.meetingsModel
    readonly property string lastSyncTime: parent.lastSyncTime
    readonly property bool   isSyncing:    parent.isSyncing
    readonly property bool   isAuthed:     Plasmoid.configuration.accessToken !== ""

    // Size hints — work for both popup and desktop widget
    Layout.minimumWidth:  Kirigami.Units.gridUnit * 18
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin:  Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin:   Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18n("Reuniões")
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            // Sync indicator / button
            PlasmaComponents3.BusyIndicator {
                visible: fullRoot.isSyncing
                width:  Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents3.ToolButton {
                visible:   !fullRoot.isSyncing && fullRoot.isAuthed
                icon.name: "view-refresh"
                flat:      true
                PlasmaComponents3.ToolTip { text: i18n("Sincronizar agora") }
                onClicked: fullRoot.parent.fetchEvents()
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Not authenticated ─────────────────────────────────────────────────
        Item {
            visible: !fullRoot.isAuthed
            Layout.fillWidth:  true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "meeting-organizer"
                    width:  Kirigami.Units.iconSizes.huge
                    height: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                PlasmaComponents3.Label {
                    text: i18n("Conta Google não conectada")
                    color: Kirigami.Theme.disabledTextColor
                    Layout.alignment: Qt.AlignHCenter
                }

                PlasmaComponents3.Button {
                    text: i18n("Configurar…")
                    Layout.alignment: Qt.AlignHCenter
                    icon.name: "configure"
                    onClicked: plasmoid.action("configure").trigger()
                }
            }
        }

        // ── Meeting list ──────────────────────────────────────────────────────
        PlasmaComponents3.ScrollView {
            visible:           fullRoot.isAuthed
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:      availableWidth

            ListView {
                id: meetingList
                model: fullRoot.model
                clip: true

                // Section headers (date groups)
                section.property:  "dateLabel"
                section.criteria:  ViewSection.FullString
                section.delegate: Item {
                    width:  ListView.view.width
                    height: sectionRow.implicitHeight + Kirigami.Units.smallSpacing * 2

                    RowLayout {
                        id: sectionRow
                        anchors {
                            left:  parent.left;  leftMargin:  Kirigami.Units.largeSpacing
                            right: parent.right; rightMargin: Kirigami.Units.largeSpacing
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            text: section
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            opacity: 0.4
                        }
                    }
                }

                // Meeting row delegate
                delegate: MeetingItem {
                    width:        ListView.view.width
                    startTime:    model.startTime
                    endTime:      model.endTime
                    title:        model.title
                    meetUrl:      model.meetUrl
                    calUrl:       model.calUrl
                    isPast:       model.isPast
                    minutesUntil: model.minutesUntil
                }

                // Empty state (authed but no meetings)
                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: meetingList.count === 0 && fullRoot.isAuthed && !fullRoot.isSyncing
                    text: i18n("Nenhuma reunião nos próximos %1 dias",
                               Plasmoid.configuration.daysAhead)
                    color: Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - Kirigami.Units.largeSpacing * 4
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; visible: fullRoot.isAuthed }

        // ── Footer ────────────────────────────────────────────────────────────
        RowLayout {
            visible: fullRoot.isAuthed
            Layout.fillWidth:   true
            Layout.leftMargin:  Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin:   Kirigami.Units.smallSpacing / 2
            Layout.bottomMargin: Kirigami.Units.smallSpacing / 2

            PlasmaComponents3.Label {
                visible: fullRoot.lastSyncTime !== ""
                text: i18n("Sync às %1", fullRoot.lastSyncTime)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: fullRoot.lastSyncTime === "" && !fullRoot.isSyncing
                text: i18n("Nunca sincronizado")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
        }
    }
}
