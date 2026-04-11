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
        nextMeetingEventId: root.nextMeetingEventId
        lastSyncTime: root.lastSyncTime
        isSyncing: root.isSyncing
        isAuthed: root.hasStoredAuth
        onRefreshRequested: root.fetchEvents()
    }

    compactRepresentation: Item {
        id: compactRoot

        readonly property string mode:        Plasmoid.configuration.taskbarMode
        readonly property int    maxChars:    Plasmoid.configuration.titleMaxChars
        readonly property string iconNoMeet:  Plasmoid.configuration.iconNoMeet  || "meeting-attending-tentative"
        readonly property string iconHasMeet: Plasmoid.configuration.iconHasMeet || "meeting-attending"

        Layout.minimumWidth:  compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
        implicitWidth:        compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight:       Kirigami.Units.iconSizes.smallMedium

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton)
                    root.openNextMeeting()
                else
                    root.expanded = !root.expanded
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
    property string nextMeetingEventId: ""
    property string lastSyncTime:     ""
    property bool   isSyncing:        false

    // Notification tracking — reset each day
    property var    _notifiedIds: ({})
    property string _notifDate:   ""
    property string _accessToken:  ""
    property string _refreshToken: ""
    property string _clientSecret: ""
    property bool   _secretsLoaded: false

    // ── Config shortcuts (read-only mirrors so bindings fire) ─────────────────
    readonly property string accessToken:     root._accessToken
    readonly property bool   hasStoredAuth:   root._secretsLoaded
                                              && Plasmoid.configuration.clientId !== ""
                                              && root._refreshToken !== ""
    readonly property real   tokenExpiry:     parseFloat(Plasmoid.configuration.tokenExpiry) || 0
    readonly property int    authVersion:     Plasmoid.configuration.authVersion
    readonly property int    daysAhead:       Plasmoid.configuration.daysAhead
    readonly property int    notifyMinutes:   Plasmoid.configuration.notifyMinutes
    readonly property int    syncIntervalMin: Plasmoid.configuration.syncIntervalMin

    function openNextMeeting() {
        if (root.nextMeeting && root.nextMeeting.meetUrl)
            Qt.openUrlExternally(root.nextMeeting.meetUrl)
    }

    // ── Timers ────────────────────────────────────────────────────────────────
    Timer {
        id: syncTimer
        interval:         root.syncIntervalMin * 60000
        running:          root.hasStoredAuth
        repeat:           true
        triggeredOnStart: true
        onTriggered:      root.fetchEvents()
    }

    Timer {
        id: notifTimer
        interval: 60000
        running:  root.hasStoredAuth
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            root.refreshTimeSensitiveState()
            root.checkNotifications()
        }
    }

    // ── Helper backend ────────────────────────────────────────────────────────
    Loader {
        id: secureHelper
        source: "SecureHelper.qml"
        onLoaded: root.loadSecureSecrets()
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("Secure helper unavailable; notifications and secret storage are disabled.")
        }
    }

    function sendNotification(title, body) {
        if (secureHelper.item)
            secureHelper.item.notify(title, body)
    }

    function clearLegacySecrets() {
        if (Plasmoid.configuration.clientSecret !== "")
            Plasmoid.configuration.clientSecret = ""
        if (Plasmoid.configuration.accessToken !== "")
            Plasmoid.configuration.accessToken = ""
        if (Plasmoid.configuration.refreshToken !== "")
            Plasmoid.configuration.refreshToken = ""
        if (Plasmoid.configuration.tokenExpiry !== "0")
            Plasmoid.configuration.tokenExpiry = "0"
    }

    function loadSecureSecrets() {
        root._secretsLoaded = false
        root._accessToken = ""
        root._refreshToken = ""
        root._clientSecret = ""
        if (!secureHelper.item) {
            clearLegacySecrets()
            return
        }

        secureHelper.item.readSecret("clientSecret", function(value) {
            root._clientSecret = value
            secureHelper.item.readSecret("refreshToken", function(refreshValue) {
                root._refreshToken = refreshValue
                root._secretsLoaded = true
                clearLegacySecrets()
                if (Plasmoid.configuration.clientId !== "" && root._refreshToken !== "") {
                    if (Plasmoid.configuration.accountEmail === "")
                        root.fetchUserEmail()
                    root.fetchEvents()
                }
            })
        })
    }

    function disconnectAccount() {
        var refreshToken = root._refreshToken
        root.isSyncing = false
        root._accessToken = ""
        root._refreshToken = ""
        root._clientSecret = ""
        Plasmoid.configuration.tokenExpiry  = "0"
        Plasmoid.configuration.accountEmail = ""
        if (secureHelper.item) {
            if (refreshToken !== "")
                secureHelper.item.revokeToken(refreshToken)
            secureHelper.item.clearSecret("refreshToken")
            secureHelper.item.clearSecret("clientSecret")
        }
        meetingsModel.clear()
        root.hasMeetingsToday = false
        root.nextMeeting = null
        root.nextMeetingEventId = ""
    }

    // ── Token management ──────────────────────────────────────────────────────
    function doWithToken(callback) {
        const now = Math.floor(Date.now() / 1000)
        if (root.accessToken !== "" && root.tokenExpiry > now + 30) {
            callback(root.accessToken)
            return
        }
        // Needs refresh
        const rToken = root._refreshToken
        if (!rToken || root._clientSecret === "") {
            root.isSyncing = false
            return
        }

        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://oauth2.googleapis.com/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                var d = JSON.parse(xhr.responseText)
                root._accessToken = d.access_token
                Plasmoid.configuration.tokenExpiry =
                    String(Math.floor(Date.now() / 1000) + d.expires_in - 60)
                callback(d.access_token)
            } else {
                // Refresh failed → need re-auth
                root.isSyncing = false
                root._accessToken = ""
                root._refreshToken = ""
                Plasmoid.configuration.tokenExpiry = "0"
                if (secureHelper.item)
                    secureHelper.item.clearSecret("refreshToken")
            }
        }
        xhr.send("client_id=" + encodeURIComponent(Plasmoid.configuration.clientId) +
                 "&client_secret=" + encodeURIComponent(root._clientSecret) +
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
        if (!root._secretsLoaded || Plasmoid.configuration.clientId === "" || root._refreshToken === "") {
            root.isSyncing = false
            return
        }
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
                    root._accessToken = ""
                    Plasmoid.configuration.tokenExpiry = "0"
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

    function isEventDeclined(event) {
        if (!event || !event.attendees) return false
        for (var i = 0; i < event.attendees.length; i++) {
            var attendee = event.attendees[i]
            if (attendee.self && attendee.responseStatus === "declined")
                return true
        }
        return false
    }

    function getDateLabel(dateStr) {
        var today = new Date(); today.setHours(0, 0, 0, 0)
        var tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)
        var d = new Date(dateStr + "T00:00:00"); d.setHours(0, 0, 0, 0)
        var diff = Math.round((d - today) / 86400000)
        if (diff === 0) return i18n("Today")
        if (diff === 1) return i18n("Tomorrow")
        var days   = [i18n("Sun"), i18n("Mon"), i18n("Tue"), i18n("Wed"), i18n("Thu"), i18n("Fri"), i18n("Sat")]
        var months = [i18n("Jan"), i18n("Feb"), i18n("Mar"), i18n("Apr"), i18n("May"), i18n("Jun"), i18n("Jul"), i18n("Aug"), i18n("Sep"), i18n("Oct"), i18n("Nov"), i18n("Dec")]
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
    }

    function formatHHMM(isoString) {
        if (!isoString) return ""
        return Qt.formatTime(new Date(isoString), "HH:mm")
    }

    function refreshTimeSensitiveState() {
        var now = Date.now()
        var todayStr = new Date().toISOString().slice(0, 10)
        var todayUpcomingCount = 0
        var earliest = null

        for (var i = 0; i < meetingsModel.count; i++) {
            var m = meetingsModel.get(i)
            var startMs = new Date(m.startIso).getTime()
            var endMs = new Date(m.endIso).getTime()
            var isPast = endMs < now
            var minutesUntil = isPast ? -1 : Math.max(0, Math.round((startMs - now) / 60000))
            var dateStr = new Date(m.startIso).toISOString().slice(0, 10)

            meetingsModel.setProperty(i, "isPast", isPast)
            meetingsModel.setProperty(i, "minutesUntil", minutesUntil)
            meetingsModel.setProperty(i, "dateLabel", root.getDateLabel(dateStr))

            if (dateStr === todayStr && !isPast && !m.isCancelled && !m.isDeclined) {
                todayUpcomingCount++
            }

            if (dateStr === todayStr
                    && !isPast
                    && !m.isCancelled
                    && !m.isDeclined
                    && m.meetUrl !== ""
                    && (earliest === null || startMs < new Date(earliest.startIso).getTime())) {
                earliest = {
                    eventId: m.eventId,
                    title: m.title,
                    startTime: m.startTime,
                    meetUrl: m.meetUrl,
                    calUrl: m.calUrl,
                    startIso: m.startIso
                }
            }
        }

        root.hasMeetingsToday = todayUpcomingCount > 0
        root.nextMeeting = earliest
        root.nextMeetingEventId = earliest ? earliest.eventId : ""
    }

    // ── Process API response → populate ListModel ─────────────────────────────
    function processMeetings(items) {
        meetingsModel.clear()

        var todayStr  = new Date().toISOString().slice(0, 10)
        var now       = Date.now()
        var todayUpcomingCount = 0
        var earliest  = null   // next upcoming meeting with a Meet URL

        for (var i = 0; i < items.length; i++) {
            var ev = items[i]
            if (!ev.start || !ev.start.dateTime) continue   // skip all-day events

            var startDt  = new Date(ev.start.dateTime)
            var endDt    = new Date(ev.end.dateTime)
            var dateStr  = startDt.toISOString().slice(0, 10)
            var isPast   = endDt.getTime() < now
            var isCancelled = ev.status === "cancelled"
            var isDeclined = root.isEventDeclined(ev)
            var minUntil = isPast ? -1 : Math.max(0, Math.round((startDt.getTime() - now) / 60000))
            var meetUrl  = root.getMeetingUrl(ev)
            var calUrl   = ev.htmlLink || ""

            if (dateStr === todayStr && !isPast && !isCancelled && !isDeclined) {
                todayUpcomingCount++
            }

            meetingsModel.append({
                eventId:   ev.id || String(i),
                dateLabel: root.getDateLabel(dateStr),
                date:      dateStr,
                startIso:  ev.start.dateTime,
                endIso:    ev.end.dateTime,
                startTime: root.formatHHMM(ev.start.dateTime),
                endTime:   root.formatHHMM(ev.end.dateTime),
                title:     ev.summary || i18n("(untitled)"),
                meetUrl:   meetUrl,
                calUrl:    calUrl,
                isPast:    isPast,
                isCancelled: isCancelled,
                isDeclined: isDeclined,
                minutesUntil: isPast ? -1 : minUntil
            })

            // Track earliest upcoming meeting that has a video link
            if (dateStr === todayStr
                    && !isPast
                    && !isCancelled
                    && !isDeclined
                    && meetUrl !== ""
                    && (earliest === null || startDt < new Date(earliest.startIso))) {
                earliest = { title: ev.summary || "", startTime: root.formatHHMM(ev.start.dateTime),
                             meetUrl: meetUrl, calUrl: calUrl, startIso: ev.start.dateTime,
                             eventId: ev.id || String(i) }
            }
        }

        root.hasMeetingsToday = todayUpcomingCount > 0
        root.nextMeeting      = earliest
        root.nextMeetingEventId = earliest ? earliest.eventId : ""
        root.refreshTimeSensitiveState()
        root.checkNotifications()
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
            if (m.isCancelled || m.isDeclined) continue
            var endMs = new Date(m.endIso).getTime()
            if (endMs < now) continue
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
                    i18n("Starts at %1 - in %2 min", m.startTime, minLeft)
                )
            }
        }
    }

    // ── Init ──────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        clearLegacySecrets()
        loadSecureSecrets()
        root.refreshTimeSensitiveState()
    }

    onAuthVersionChanged: loadSecureSecrets()
}
