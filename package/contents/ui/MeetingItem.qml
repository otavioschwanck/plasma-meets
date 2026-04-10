import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Self-contained meeting row. Receives all data as explicit properties.
// Used as delegate in FullRepresentation's ListView.
Item {
    id: meetItem

    // Data properties (set by ListView delegate binding)
    property string startTime:    ""
    property string endTime:      ""
    property string title:        ""
    property string meetUrl:      ""
    property string calUrl:       ""
    property bool   isPast:       false
    property bool   isCancelled:  false
    property bool   isDeclined:   false
    property int    minutesUntil: -1   // <0 = past/N/A, 0+ = minutes remaining

    // Badge: "Agora" | "em Xmin" | ""
    readonly property string badgeText: {
        if (isCancelled) return i18n("Cancelled")
        if (isDeclined) return i18n("Declined")
        if (isPast || minutesUntil < 0) return ""
        if (minutesUntil === 0)         return i18n("Now")
        if (minutesUntil <= 30)         return i18n("in %1 min", minutesUntil)
        return ""
    }
    readonly property bool isSoon: minutesUntil >= 0 && minutesUntil <= 5
    readonly property bool isNow:  minutesUntil >= 0 && minutesUntil <= 0
    readonly property bool hovered: itemHover.hovered || meetButton.hovered || calendarButton.hovered

    width:  parent ? parent.width : 0
    height: row.implicitHeight + Kirigami.Units.largeSpacing * 2

    // Hover background
    Rectangle {
        id: hoverBg
        anchors.fill: parent
        color: Kirigami.Theme.hoverColor
        opacity: meetItem.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    HoverHandler {
        id: itemHover
    }

    RowLayout {
        id: row
        anchors {
            left:           parent.left
            right:          parent.right
            verticalCenter: parent.verticalCenter
            leftMargin:     Kirigami.Units.largeSpacing
            rightMargin:    Kirigami.Units.largeSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        // Color dot
        Rectangle {
            width:  7
            height: 7
            radius: 4
            color:  (meetItem.isPast || meetItem.isCancelled || meetItem.isDeclined)
                    ? Kirigami.Theme.disabledTextColor
                    : (meetItem.isSoon || meetItem.isNow)
                      ? Kirigami.Theme.positiveTextColor
                      : Kirigami.Theme.highlightColor
        }

        // Time range
        PlasmaComponents3.Label {
            text: meetItem.startTime + "–" + meetItem.endTime
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: (meetItem.isPast || meetItem.isCancelled || meetItem.isDeclined)
                   ? Kirigami.Theme.disabledTextColor
                   : Kirigami.Theme.textColor
            font.strikeout: meetItem.isPast || meetItem.isCancelled || meetItem.isDeclined
            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
        }

        // Title
        PlasmaComponents3.Label {
            text:  meetItem.title
            color: (meetItem.isPast || meetItem.isCancelled || meetItem.isDeclined)
                   ? Kirigami.Theme.disabledTextColor
                   : Kirigami.Theme.textColor
            font.strikeout: meetItem.isPast || meetItem.isCancelled || meetItem.isDeclined
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Badge (Agora / em Xmin)
        Rectangle {
            visible: meetItem.badgeText !== ""
            width:   badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
            height:  badgeLabel.implicitHeight + 2
            radius:  height / 2
            color:   meetItem.isNow
                     ? Qt.rgba(Kirigami.Theme.positiveTextColor.r,
                               Kirigami.Theme.positiveTextColor.g,
                               Kirigami.Theme.positiveTextColor.b, 0.2)
                     : (meetItem.isCancelled || meetItem.isDeclined)
                     ? Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                               Kirigami.Theme.disabledTextColor.g,
                               Kirigami.Theme.disabledTextColor.b, 0.15)
                     : Qt.rgba(Kirigami.Theme.neutralTextColor.r,
                               Kirigami.Theme.neutralTextColor.g,
                               Kirigami.Theme.neutralTextColor.b, 0.2)

            PlasmaComponents3.Label {
                id: badgeLabel
                anchors.centerIn: parent
                text:  meetItem.badgeText
                color: (meetItem.isCancelled || meetItem.isDeclined)
                       ? Kirigami.Theme.disabledTextColor
                       : meetItem.isNow
                       ? Kirigami.Theme.positiveTextColor
                       : Kirigami.Theme.neutralTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: meetItem.isNow && !meetItem.isCancelled && !meetItem.isDeclined

                SequentialAnimation on opacity {
                    running: meetItem.isNow && !meetItem.isCancelled && !meetItem.isDeclined
                    loops:   Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
        }

        // Action buttons — fade in on hover
        RowLayout {
            id: actionRow
            opacity: meetItem.hovered ? 1 : 0
            spacing: 2
            Behavior on opacity { NumberAnimation { duration: 100 } }

            // Open Google Meet
            PlasmaComponents3.ToolButton {
                id: meetButton
                visible:    meetItem.meetUrl !== "" && !meetItem.isCancelled && !meetItem.isDeclined
                icon.name:  "open-link"
                icon.color: meetButton.hovered ? Kirigami.Theme.textColor : Qt.lighter(Kirigami.Theme.textColor, 1.2)
                display:    PlasmaComponents3.AbstractButton.IconOnly
                flat:       true
                hoverEnabled: true

                background: Rectangle {
                    radius: Kirigami.Units.cornerRadius
                    color: meetButton.hovered
                           ? Qt.rgba(Kirigami.Theme.highlightedTextColor.r,
                                     Kirigami.Theme.highlightedTextColor.g,
                                     Kirigami.Theme.highlightedTextColor.b, 0.18)
                           : Qt.rgba(Kirigami.Theme.textColor.r,
                                     Kirigami.Theme.textColor.g,
                                     Kirigami.Theme.textColor.b, 0.10)
                }

                PlasmaComponents3.ToolTip { text: i18n("Open Google Meet") }

                onClicked: Qt.openUrlExternally(meetItem.meetUrl)
            }

            // Open in Google Calendar
            PlasmaComponents3.ToolButton {
                id: calendarButton
                visible:    meetItem.calUrl !== ""
                icon.name:  "view-calendar"
                icon.color: calendarButton.hovered ? Kirigami.Theme.textColor : Qt.lighter(Kirigami.Theme.textColor, 1.15)
                display:    PlasmaComponents3.AbstractButton.IconOnly
                flat:       true
                hoverEnabled: true

                background: Rectangle {
                    radius: Kirigami.Units.cornerRadius
                    color: calendarButton.hovered
                           ? Qt.rgba(Kirigami.Theme.highlightedTextColor.r,
                                     Kirigami.Theme.highlightedTextColor.g,
                                     Kirigami.Theme.highlightedTextColor.b, 0.18)
                           : Qt.rgba(Kirigami.Theme.textColor.r,
                                     Kirigami.Theme.textColor.g,
                                     Kirigami.Theme.textColor.b, 0.10)
                }

                PlasmaComponents3.ToolTip { text: i18n("Open in Google Calendar") }

                onClicked: Qt.openUrlExternally(meetItem.calUrl)
            }
        }
    }
}
