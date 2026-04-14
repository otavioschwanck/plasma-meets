import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: fullRoot

    property var model
    property var nextMeeting: null
    property string nextMeetingEventId: ""
    property string nextMeetUrl: ""
    property string lastSyncTime: ""
    property bool isSyncing: false
    property bool isAuthed: false
    readonly property bool hasNextMeetLink: nextMeetUrl !== ""
    signal refreshRequested()

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
                text: i18n("Meetings")
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

            PlasmaComponents3.Button {
                visible: fullRoot.isAuthed
                enabled: fullRoot.hasNextMeetLink
                text: i18n("Open next Meet")
                icon.name: "video-conference"
                onClicked: Qt.openUrlExternally(fullRoot.nextMeetUrl)

                PlasmaComponents3.ToolTip {
                    text: fullRoot.hasNextMeetLink
                          ? i18n("Open meeting at %1", fullRoot.nextMeeting ? fullRoot.nextMeeting.startTime : "")
                          : i18n("No upcoming meeting with a Google Meet link")
                }
            }

            PlasmaComponents3.ToolButton {
                visible:   !fullRoot.isSyncing && fullRoot.isAuthed
                icon.name: "view-refresh"
                flat:      true
                PlasmaComponents3.ToolTip { text: i18n("Sync now") }
                onClicked: fullRoot.refreshRequested()
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
                    source: "meeting-attending-tentative"
                    width:  Kirigami.Units.iconSizes.huge
                    height: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                PlasmaComponents3.Label {
                    text: i18n("Google account not connected")
                    color: Kirigami.Theme.disabledTextColor
                    Layout.alignment: Qt.AlignHCenter
                }

                PlasmaComponents3.Button {
                    text: i18n("Configure...")
                    Layout.alignment: Qt.AlignHCenter
                    icon.name: "configure"
                    onClicked: Plasmoid.internalAction("configure").trigger()
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
                spacing: Kirigami.Units.smallSpacing

                // Section headers (date groups)
                section.property:  "dateLabel"
                section.criteria:  ViewSection.FullString
                section.delegate: Item {
                    width:  ListView.view.width
                    height: sectionCard.implicitHeight + Kirigami.Units.largeSpacing

                    Rectangle {
                        id: sectionCard
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: Kirigami.Units.largeSpacing
                            rightMargin: Kirigami.Units.largeSpacing
                            top: parent.top
                            topMargin: Kirigami.Units.smallSpacing
                        }
                        implicitHeight: sectionRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                       Kirigami.Theme.highlightColor.g,
                                       Kirigami.Theme.highlightColor.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                              Kirigami.Theme.highlightColor.g,
                                              Kirigami.Theme.highlightColor.b, 0.16)

                        RowLayout {
                            id: sectionRow
                            anchors {
                                fill: parent
                                leftMargin: Kirigami.Units.largeSpacing
                                rightMargin: Kirigami.Units.largeSpacing
                                topMargin: Kirigami.Units.smallSpacing
                                bottomMargin: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Kirigami.Theme.highlightColor
                            }

                            PlasmaComponents3.Label {
                                text: section
                                font.bold: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                color: Kirigami.Theme.textColor
                            }

                            Kirigami.Separator {
                                Layout.fillWidth: true
                                opacity: 0.5
                            }
                        }
                    }
                }

                // Meeting row delegate
                delegate: MeetingItem {
                    width:        ListView.view.width
                    eventId:      model.eventId
                    startTime:    model.startTime
                    endTime:      model.endTime
                    title:        model.title
                    meetUrl:      model.meetUrl
                    calUrl:       model.calUrl
                    isPast:       model.isPast
                    isCancelled:  model.isCancelled
                    isDeclined:   model.isDeclined
                    minutesUntil: model.minutesUntil
                    isCurrent:    model.dateLabel === i18n("Today")
                                  && model.eventId === fullRoot.nextMeetingEventId
                }

                // Empty state (authed but no meetings)
                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: meetingList.count === 0 && fullRoot.isAuthed && !fullRoot.isSyncing
                    text: i18n("No meetings in the next %1 days",
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
                text: i18n("Synced at %1", fullRoot.lastSyncTime)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: fullRoot.lastSyncTime === "" && !fullRoot.isSyncing
                text: i18n("Never synced")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
        }
    }
}
