// Loaded optionally via Loader. If plasma5support is not installed,
// the Loader will fail silently and notifications are simply disabled.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    visible: false
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, _data) => { disconnectSource(sourceName) }
    }

    function exec(cmd) {
        executable.connectSource(cmd)
    }
}
