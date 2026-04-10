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
    property int    minutesUntil: -1   // <0 = past/N/A, 0+ = minutes remaining

    // Badge: "Agora" | "em Xmin" | ""
    readonly property string badgeText: {
        if (isPast || minutesUntil < 0) return ""
        if (minutesUntil === 0)         return i18n("Agora")
        if (minutesUntil <= 30)         return i18n("em %1 min", minutesUntil)
        return ""
    }
    readonly property bool isSoon: minutesUntil >= 0 && minutesUntil <= 5
    readonly property bool isNow:  minutesUntil >= 0 && minutesUntil <= 0

    width:  parent ? parent.width : 0
    height: row.implicitHeight + Kirigami.Units.smallSpacing * 2

    // Hover background
    Rectangle {
        id: hoverBg
        anchors.fill: parent
        color: Kirigami.Theme.hoverColor
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { hoverBg.opacity = 1; actionRow.opacity = 1 }
        onExited:  { hoverBg.opacity = 0; actionRow.opacity = 0 }
        // Row itself is not clickable; use the action buttons
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
            color:  meetItem.isPast
                    ? Kirigami.Theme.disabledTextColor
                    : (meetItem.isSoon || meetItem.isNow)
                      ? Kirigami.Theme.positiveTextColor
                      : Kirigami.Theme.highlightColor
        }

        // Time range
        PlasmaComponents3.Label {
            text: meetItem.startTime + "–" + meetItem.endTime
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: meetItem.isPast
                   ? Kirigami.Theme.disabledTextColor
                   : Kirigami.Theme.textColor
            font.strikeout: meetItem.isPast
            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
        }

        // Title
        PlasmaComponents3.Label {
            text:  meetItem.title
            color: meetItem.isPast
                   ? Kirigami.Theme.disabledTextColor
                   : Kirigami.Theme.textColor
            font.strikeout: meetItem.isPast
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
                     : Qt.rgba(Kirigami.Theme.neutralTextColor.r,
                               Kirigami.Theme.neutralTextColor.g,
                               Kirigami.Theme.neutralTextColor.b, 0.2)

            PlasmaComponents3.Label {
                id: badgeLabel
                anchors.centerIn: parent
                text:  meetItem.badgeText
                color: meetItem.isNow
                       ? Kirigami.Theme.positiveTextColor
                       : Kirigami.Theme.neutralTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: meetItem.isNow

                SequentialAnimation on opacity {
                    running: meetItem.isNow
                    loops:   Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
        }

        // Action buttons — fade in on hover
        RowLayout {
            id: actionRow
            opacity: 0
            spacing: 2
            Behavior on opacity { NumberAnimation { duration: 100 } }

            // Open Google Meet
            PlasmaComponents3.ToolButton {
                visible:    meetItem.meetUrl !== ""
                icon.name:  "video-conference"
                display:    PlasmaComponents3.AbstractButton.IconOnly
                flat:       true

                PlasmaComponents3.ToolTip { text: i18n("Abrir Google Meet") }

                onClicked: Qt.openUrlExternally(meetItem.meetUrl)
            }

            // Open in Google Calendar
            PlasmaComponents3.ToolButton {
                visible:    meetItem.calUrl !== ""
                icon.name:  "view-calendar"
                display:    PlasmaComponents3.AbstractButton.IconOnly
                flat:       true

                PlasmaComponents3.ToolTip { text: i18n("Abrir no Google Agenda") }

                onClicked: Qt.openUrlExternally(meetItem.calUrl)
            }
        }
    }
}
