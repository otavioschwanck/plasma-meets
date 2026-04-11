import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: helper

    property string helperPath: {
        var url = Qt.resolvedUrl("../bin/plasma-meets-helper.sh").toString()
        if (url.indexOf("file://") === 0)
            return decodeURIComponent(url.slice(7))
        return url
    }
    property int requestId: 0
    property var pending: ({})

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var callback = helper.pending[sourceName]
            executable.disconnectSource(sourceName)
            delete helper.pending[sourceName]
            if (callback)
                callback(data || {})
        }
    }

    function quoteArg(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
    }

    function command(args) {
        var parts = [quoteArg(helperPath)]
        for (var i = 0; i < args.length; ++i)
            parts.push(quoteArg(args[i]))
        return parts.join(" ")
    }

    function run(args, callback) {
        var sourceName = command(args)
        pending[sourceName] = callback
        executable.connectSource(sourceName)
        return sourceName
    }

    function stdout(data) {
        if (!data)
            return ""
        var out = data.stdout
        if (out === undefined)
            out = data["stdout"]
        if (out === undefined)
            out = data["standard output"]
        return String(out || "").replace(/\r?\n$/, "")
    }

    function exitCode(data) {
        if (!data)
            return -1
        if (data["exit code"] !== undefined)
            return Number(data["exit code"])
        if (data.exitCode !== undefined)
            return Number(data.exitCode)
        return 0
    }

    function readSecret(entry, callback) {
        run(["wallet-read", entry], function(data) {
            callback(stdout(data), data)
        })
    }

    function writeSecret(entry, value, callback) {
        run(["wallet-write", entry, String(value || "")], callback || function() {})
    }

    function clearSecret(entry, callback) {
        run(["wallet-clear", entry], callback || function() {})
    }

    function notify(title, body) {
        run(["notify", String(title || ""), String(body || "")], function() {})
    }

    function revokeToken(token, callback) {
        run(["oauth-revoke", String(token || "")], callback || function() {})
    }
}
