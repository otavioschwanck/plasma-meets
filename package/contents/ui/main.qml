import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Representations ───────────────────────────────────────────────────────
    fullRepresentation: FullRepresentation {
        model: root.meetingsModel
        nextMeeting: root.nextMeeting
        lastSyncTime: root.lastSyncTime
        isSyncing: root.isSyncing
        isAuthed: root.accessToken !== ""
        onRefreshRequested: root.fetchEvents()
    }

    compactRepresentation: Item {
        id: compactRoot

        readonly property string mode:        Plasmoid.configuration.taskbarMode
        readonly property int    maxChars:    Plasmoid.configuration.titleMaxChars
        readonly property string iconNoMeet:  Plasmoid.configuration.iconNoMeet  || "meeting-organizer"
        readonly property string iconHasMeet: Plasmoid.configuration.iconHasMeet || "meeting-attending"

        Layout.minimumWidth:  compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
        implicitWidth:        compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight:       Kirigami.Units.iconSizes.smallMedium

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked:    root.expanded = !root.expanded

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: parent.containsMouse
                       ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                 Kirigami.Theme.highlightColor.g,
                                 Kirigami.Theme.highlightColor.b, 0.15)
                       : "transparent"
            }

            RowLayout {
                id: compactRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.hasMeetingsToday ? compactRoot.iconHasMeet : compactRoot.iconNoMeet
                    width:  Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                }

                PlasmaComponents3.Label {
                    visible: (compactRoot.mode === "time" || compactRoot.mode === "time+title")
                             && root.nextMeeting !== null
                    text:    root.nextMeeting ? root.nextMeeting.startTime : ""
                    font.bold: true
                    color: Kirigami.Theme.highlightColor
                }

                PlasmaComponents3.Label {
                    visible: compactRoot.mode === "time+title"
                             && root.nextMeeting !== null
                             && root.nextMeeting.title !== ""
                    text:  "·"
                    color: Kirigami.Theme.disabledTextColor
                }

                PlasmaComponents3.Label {
                    visible: compactRoot.mode === "time+title" && root.nextMeeting !== null
                    text: {
                        if (!root.nextMeeting) return ""
                        var t = root.nextMeeting.title
                        return t.length > compactRoot.maxChars ? t.slice(0, compactRoot.maxChars) + "…" : t
                    }
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                }
            }
        }

        PlasmaComponents3.ToolTip {
            text: root.nextMeeting
                  ? root.nextMeeting.startTime + " · " + root.nextMeeting.title
                  : i18n("No meetings today")
        }
    }

    // ── Shared data model (accessed via parent.xxx in child components) ───────
    // ListModel exposed as a property so child components can access via parent.meetingsModel
    ListModel { id: meetingsModelInstance }
    property alias meetingsModel: meetingsModelInstance

    property bool   hasMeetingsToday: false
    property var    nextMeeting:      null   // plain object: { title, startTime, meetUrl }
    property string lastSyncTime:     ""
    property bool   isSyncing:        false

    // Device flow transient state
    property bool   showDeviceFlow:        false
    property string deviceUserCode:        ""
    property string deviceVerificationUrl: ""
    property string _deviceCode:           ""   // internal, not shown in UI

    // Notification tracking — reset each day
    property var    _notifiedIds: ({})
    property string _notifDate:   ""

    // ── Config shortcuts (read-only mirrors so bindings fire) ─────────────────
    readonly property string accessToken:     Plasmoid.configuration.accessToken
    readonly property string refreshToken:    Plasmoid.configuration.refreshToken
    readonly property real   tokenExpiry:     parseFloat(Plasmoid.configuration.tokenExpiry) || 0
    readonly property int    daysAhead:       Plasmoid.configuration.daysAhead
    readonly property int    notifyMinutes:   Plasmoid.configuration.notifyMinutes
    readonly property int    syncIntervalMin: Plasmoid.configuration.syncIntervalMin

    // ── Timers ────────────────────────────────────────────────────────────────
    Timer {
        id: syncTimer
        interval:         root.syncIntervalMin * 60000
        running:          root.accessToken !== ""
        repeat:           true
        triggeredOnStart: true
        onTriggered:      root.fetchEvents()
    }

    Timer {
        id: notifTimer
        interval: 60000
        running:  root.accessToken !== ""
        repeat:   true
        onTriggered: root.checkNotifications()
    }

    // Device-flow poll timer (stopped by default)
    Timer {
        id: pollTimer
        interval: 5000
        repeat:   true
        running:  false
        onTriggered: root.pollDeviceToken()
    }

    // ── Notifications (via plasma5support if installed, otherwise silent) ──────
    Loader {
        id: notificationHelper
        source: "NotificationHelper.qml"
        // If plasma5support is not installed the Loader fails silently;
        // notifications are disabled but the widget keeps working.
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("plasma5support not found — notifications disabled. Install it with: sudo pacman -S plasma5support")
        }
    }

    function sendNotification(title, body) {
        if (notificationHelper.item) {
            const t = title.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
            const b = body.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
            notificationHelper.item.exec(`notify-send -a "Plasma Meets" -i calendar "${t}" "${b}" -t 10000`)
        }
    }

    // ── OAuth2 Device Flow ────────────────────────────────────────────────────
    function startDeviceFlow() {
        const clientId = Plasmoid.configuration.clientId
        if (!clientId) return

        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://oauth2.googleapis.com/device/code")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                var d = JSON.parse(xhr.responseText)
                root._deviceCode           = d.device_code
                root.deviceUserCode        = d.user_code
                root.deviceVerificationUrl = d.verification_url || "google.com/device"
                root.showDeviceFlow        = true
                pollTimer.interval         = (d.interval || 5) * 1000
                pollTimer.running          = true
            }
        }
        xhr.send("client_id=" + encodeURIComponent(clientId) +
                 "&scope=https://www.googleapis.com/auth/calendar.readonly")
    }

    function pollDeviceToken() {
        if (!root._deviceCode) return
        const clientId     = Plasmoid.configuration.clientId
        const clientSecret = Plasmoid.configuration.clientSecret

        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://oauth2.googleapis.com/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var d = JSON.parse(xhr.responseText)

            if (d.access_token) {
                pollTimer.running              = false
                root.showDeviceFlow            = false
                root._deviceCode               = ""
                Plasmoid.configuration.accessToken  = d.access_token
                Plasmoid.configuration.refreshToken = d.refresh_token
                Plasmoid.configuration.tokenExpiry  =
                    String(Math.floor(Date.now() / 1000) + d.expires_in - 60)
                root.fetchUserEmail()
                root.fetchEvents()
                return
            }
            // authorization_pending → keep polling; anything else → abort
            if (d.error && d.error !== "authorization_pending") {
                pollTimer.running  = false
                root.showDeviceFlow = false
                root._deviceCode   = ""
            }
        }
        xhr.send("client_id=" + encodeURIComponent(clientId) +
                 "&client_secret=" + encodeURIComponent(clientSecret) +
                 "&device_code=" + encodeURIComponent(root._deviceCode) +
                 "&grant_type=urn:ietf:params:oauth:grant-type:device_code")
    }

    function disconnectAccount() {
        pollTimer.running = false
        root.showDeviceFlow = false
        root._deviceCode = ""
        Plasmoid.configuration.accessToken  = ""
        Plasmoid.configuration.refreshToken = ""
        Plasmoid.configuration.tokenExpiry  = "0"
        Plasmoid.configuration.accountEmail = ""
        meetingsModel.clear()
        root.hasMeetingsToday = false
        root.nextMeeting = null
    }

    // ── Token management ──────────────────────────────────────────────────────
    function doWithToken(callback) {
        const now = Math.floor(Date.now() / 1000)
        if (root.tokenExpiry > now + 30) {
            callback(root.accessToken)
            return
        }
        // Needs refresh
        const rToken = Plasmoid.configuration.refreshToken
        if (!rToken) return

        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://oauth2.googleapis.com/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                var d = JSON.parse(xhr.responseText)
                Plasmoid.configuration.accessToken = d.access_token
                Plasmoid.configuration.tokenExpiry =
                    String(Math.floor(Date.now() / 1000) + d.expires_in - 60)
                callback(d.access_token)
            } else {
                // Refresh failed → need re-auth
                Plasmoid.configuration.accessToken  = ""
                Plasmoid.configuration.refreshToken = ""
            }
        }
        xhr.send("client_id=" + encodeURIComponent(Plasmoid.configuration.clientId) +
                 "&client_secret=" + encodeURIComponent(Plasmoid.configuration.clientSecret) +
                 "&refresh_token=" + encodeURIComponent(rToken) +
                 "&grant_type=refresh_token")
    }

    // ── User info ─────────────────────────────────────────────────────────────
    function fetchUserEmail() {
        root.doWithToken(function(token) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "https://www.googleapis.com/oauth2/v2/userinfo")
            xhr.setRequestHeader("Authorization", "Bearer " + token)
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) {
                    var d = JSON.parse(xhr.responseText)
                    Plasmoid.configuration.accountEmail = d.email || d.name || ""
                }
            }
            xhr.send()
        })
    }

    // ── Google Calendar API ───────────────────────────────────────────────────
    function fetchEvents() {
        if (!root.accessToken) return
        root.isSyncing = true

        root.doWithToken(function(token) {
            const now     = new Date()
            const timeMin = now.toISOString()
            const timeMax = new Date(now.getTime() + root.daysAhead * 86400000).toISOString()
            const url     = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
                          + "?timeMin=" + encodeURIComponent(timeMin)
                          + "&timeMax=" + encodeURIComponent(timeMax)
                          + "&singleEvents=true&orderBy=startTime&maxResults=200"

            var xhr = new XMLHttpRequest()
            xhr.open("GET", url)
            xhr.setRequestHeader("Authorization", "Bearer " + token)
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                root.isSyncing = false

                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    root.processMeetings(data.items || [])
                    root.lastSyncTime = Qt.formatTime(new Date(), "HH:mm")
                } else if (xhr.status === 401) {
                    Plasmoid.configuration.accessToken = ""
                }
            }
            xhr.send()
        })
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function getMeetingUrl(event) {
        if (event.hangoutLink) return event.hangoutLink
        if (event.conferenceData && event.conferenceData.entryPoints) {
            for (var i = 0; i < event.conferenceData.entryPoints.length; i++) {
                if (event.conferenceData.entryPoints[i].entryPointType === "video")
                    return event.conferenceData.entryPoints[i].uri
            }
        }
        return ""
    }

    function getDateLabel(dateStr) {
        var today = new Date(); today.setHours(0, 0, 0, 0)
        var tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)
        var d = new Date(dateStr + "T00:00:00"); d.setHours(0, 0, 0, 0)
        var diff = Math.round((d - today) / 86400000)
        if (diff === 0) return "Hoje"
        if (diff === 1) return "Amanhã"
        var days   = ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
        var months = ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
    }

    function formatHHMM(isoString) {
        if (!isoString) return ""
        return Qt.formatTime(new Date(isoString), "HH:mm")
    }

    // ── Process API response → populate ListModel ─────────────────────────────
    function processMeetings(items) {
        meetingsModel.clear()

        var todayStr  = new Date().toISOString().slice(0, 10)
        var now       = Date.now()
        var todayCount = 0
        var earliest  = null   // next upcoming meeting with a Meet URL

        for (var i = 0; i < items.length; i++) {
            var ev = items[i]
            if (!ev.start || !ev.start.dateTime) continue   // skip all-day events

            var startDt  = new Date(ev.start.dateTime)
            var endDt    = new Date(ev.end.dateTime)
            var dateStr  = startDt.toISOString().slice(0, 10)
            var isPast   = endDt.getTime() < now
            var minUntil = Math.round((startDt.getTime() - now) / 60000)
            var meetUrl  = root.getMeetingUrl(ev)
            var calUrl   = ev.htmlLink || ""

            if (dateStr === todayStr) todayCount++

            meetingsModel.append({
                eventId:   ev.id || String(i),
                dateLabel: root.getDateLabel(dateStr),
                date:      dateStr,
                startIso:  ev.start.dateTime,
                endIso:    ev.end.dateTime,
                startTime: root.formatHHMM(ev.start.dateTime),
                endTime:   root.formatHHMM(ev.end.dateTime),
                title:     ev.summary || i18n("(sem título)"),
                meetUrl:   meetUrl,
                calUrl:    calUrl,
                isPast:    isPast,
                minutesUntil: isPast ? -1 : minUntil
            })

            // Track earliest upcoming meeting that has a video link
            if (!isPast && (earliest === null || startDt < new Date(earliest.startIso))) {
                earliest = { title: ev.summary || "", startTime: root.formatHHMM(ev.start.dateTime),
                             meetUrl: meetUrl, calUrl: calUrl, startIso: ev.start.dateTime }
            }
        }

        root.hasMeetingsToday = todayCount > 0
        root.nextMeeting      = earliest
    }

    // ── Notification checker (called every minute) ────────────────────────────
    function checkNotifications() {
        var todayStr = new Date().toISOString().slice(0, 10)

        // Reset tracker on new day
        if (root._notifDate !== todayStr) {
            root._notifiedIds = {}
            root._notifDate   = todayStr
        }

        var now    = Date.now()
        var target = root.notifyMinutes

        for (var i = 0; i < meetingsModel.count; i++) {
            var m = meetingsModel.get(i)
            if (m.isPast) continue
            if (root._notifiedIds[m.eventId]) continue

            var startMs  = new Date(m.startIso).getTime()
            var minLeft  = Math.round((startMs - now) / 60000)

            // Notify when within [target-1, target] minutes (±1 min tolerance)
            if (minLeft >= target - 1 && minLeft <= target) {
                var ids = root._notifiedIds
                ids[m.eventId] = true
                root._notifiedIds = ids   // trigger binding update

                root.sendNotification(
                    m.title,
                    i18n("Começa às %1 — em %2 min", m.startTime, minLeft)
                )
            }
        }
    }

    // ── Init ──────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        if (root.accessToken !== "") {
            root.fetchEvents()
        }
    }
}
