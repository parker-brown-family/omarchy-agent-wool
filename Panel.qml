import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The linter cannot see Quickshell's C++ type registration nor the dynamic
// members of the theme singletons — same blind spot the first-party panels
// hit; every other check still runs.
// qmllint disable uncreatable-type missing-property unqualified

// Wool — the presence surface. The whole flock, on one wall.
//
// Crook answers "who needs me right now" from the bar; Wool answers "what
// does my fleet look like" on a toggled wall of cards. They compose and
// neither requires the other; both drink from the Herd bus.
//
// This file is a pure display over two state files:
//
//   ~/.local/state/herd/state.json        who exists and how they are —
//                                          written by the herd bus (agents
//                                          self-report via hooks; a herdr
//                                          mirror covers the rest)
//   ~/.local/state/omarchy/wool/wall.json  vitals enrichment — written by
//                                          wool/wool-scan.sh, which runs ONLY
//                                          while the wall is open
//
// Nothing here writes to any terminal. The one write anywhere in the plugin
// is `herd seen` after a focus jump, which is what makes "finished and
// unseen" a state that can end.
Panel {
  id: root
  moduleName: "brownfamilysports.wool"
  ipcTarget: "brownfamilysports.wool"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateBase:
    Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string herdFile: stateBase + "/herd/state.json"
  readonly property string wallFile: stateBase + "/omarchy/wool/wall.json"
  readonly property bool hideWhenEmpty: setting("hideWhenEmpty", true)
  readonly property int scanIntervalMs: Math.max(1000, setting("scanIntervalMs", 2500))

  readonly property string pluginDir: {
    var u = Qt.resolvedUrl(".").toString()
    return u.replace(/^file:\/\//, "").replace(/\/$/, "")
  }

  property var sessions: []
  property var vitals: ({})
  // Staleness is judged against a clock that ticks with the refresh timer, so
  // an entry can rot into "unknown" while the wall is simply being looked at.
  property real nowSecs: Date.now() / 1000

  // ------------------------------------------------------------------ model

  // The one-line contract herd's file asks of every reader: past stale_after
  // the state is unknown, whatever the field still says.
  function effectiveState(s) {
    if (s.stale_after !== undefined && s.stale_after !== null && nowSecs > s.stale_after)
      return "unknown"
    return s.state || "unknown"
  }

  // The fleece doctrine. White is good, dark grey wants your eyes, black is
  // broken. "Unknown" is grey BY DEFINITION — an undetected state is an
  // attention state, never a calm one.
  function tierOf(st) {
    if (st === "error") return "error"
    if (st === "working" || st === "idle") return "good"
    return "attention"
  }

  function rank(st) {
    if (st === "blocked") return 0
    if (st === "error") return 1
    if (st === "done") return 2
    if (st === "unknown") return 3
    if (st === "working") return 4
    return 5
  }

  readonly property var ordered: {
    var list = []
    for (var i = 0; i < sessions.length; i++) if (sessions[i]) list.push(sessions[i])
    var self = root
    list.sort(function (a, b) {
      var d = self.rank(self.effectiveState(a)) - self.rank(self.effectiveState(b))
      return d !== 0 ? d : String(a.key).localeCompare(String(b.key))
    })
    return list
  }

  function tallyTier(t) {
    var n = 0
    for (var i = 0; i < sessions.length; i++)
      if (sessions[i] && tierOf(effectiveState(sessions[i])) === t) n++
    return n
  }

  readonly property int goodCount: tallyTier("good")
  readonly property int attentionCount: tallyTier("attention")
  readonly property int errorCount: tallyTier("error")

  readonly property string heroMeta: {
    if (sessions.length === 0) return "no agents reported"
    var parts = []
    if (attentionCount > 0) parts.push(attentionCount + " want your eyes")
    if (errorCount > 0) parts.push(errorCount + " broken")
    if (goodCount > 0) parts.push(goodCount + " fine")
    return parts.join(" · ")
  }

  function labelFor(st) {
    if (st === "blocked") return "waiting on you"
    if (st === "done") return "done · unseen"
    if (st === "working") return "working"
    if (st === "idle") return "idle"
    if (st === "unknown") return "unknown"
    if (st === "error") return "broken"
    return st
  }

  // A session parked in the home directory would otherwise title its card
  // with the username — four cards all reading "parker" on the first live
  // wall. Home is "~"; everything else is its directory's name.
  function projectOf(s) {
    var c = s.cwd || ""
    if (c === home) return "~"
    var i = c.lastIndexOf("/")
    return i >= 0 ? c.substring(i + 1) : c
  }

  // ----------------------------------------------------------------- action

  // Keys are claude session uuids or "herdr:w1:p1". They reach a command
  // line, and the file they come from is written by other processes, so shape
  // is checked here rather than trusted.
  function safeToken(value) {
    return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9:._-]*$/.test(value)
  }

  function focusAgent(key) {
    if (!root.bar || !safeToken(key)) return
    root.bar.run("sh '" + pluginDir + "/wool/wool-focus.sh' '" + key + "'")
    root.close()
  }

  function focusFirstAttention() {
    for (var i = 0; i < ordered.length; i++) {
      var t = tierOf(effectiveState(ordered[i]))
      if (t === "attention" || t === "error") {
        focusAgent(ordered[i].key)
        return
      }
    }
  }

  // ------------------------------------------------------------------- bar

  visible: sessions.length > 0 || !hideWhenEmpty
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------------ state

  FileView {
    id: herdView
    path: root.herdFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseHerd(text())
    onLoadFailed: {
      root.lastHerdText = ""
      root.sessions = []
    }
  }

  property string lastHerdText: ""

  function parseHerd(content) {
    var raw = String(content || "")
    if (raw === lastHerdText) return
    lastHerdText = raw
    try {
      var doc = JSON.parse(raw)
      sessions = (doc && Array.isArray(doc.sessions)) ? doc.sessions : []
    } catch (e) {
      console.warn("wool", "ignoring unreadable herd state", e)
      sessions = []
    }
  }

  FileView {
    id: wallView
    path: root.wallFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseWall(text())
    onLoadFailed: root.vitals = ({})
  }

  property string lastWallText: ""

  function parseWall(content) {
    var raw = String(content || "")
    if (raw === lastWallText) return
    lastWallText = raw
    try {
      var doc = JSON.parse(raw)
      vitals = (doc && doc.vitals && typeof doc.vitals === "object") ? doc.vitals : ({})
    } catch (e) {
      vitals = ({})
    }
  }

  // A FileView whose parent directory does not exist when it is created never
  // sees the file appear (the Crook tray learned this the hard way, back when
  // it was Herd: watchChanges copes with an absent file, not an absent
  // directory, and does not retry). The herd bus may well not have run yet
  // when the shell loads this panel, so the slow tick re-reads as well as
  // re-stamping the staleness clock.
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowSecs = Date.now() / 1000
      herdView.reload()
    }
  }

  // ------------------------------------------------------------------- scan
  //
  // Everything that costs anything — the herdr mirror, the vitals CLI over
  // whole transcripts — runs only while the wall is open. Terminal Delight
  // shipped this exact sweep ungated once and read 3.5MB/s of disk with the
  // wall closed; the gate IS the design.

  Process {
    id: scanProc
    command: ["sh", root.pluginDir + "/wool/wool-scan.sh"]
    onExited: wallView.reload()
  }

  Timer {
    interval: root.scanIntervalMs
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!scanProc.running) scanProc.running = true
  }

  // The Panel base already registers an IpcHandler for ipcTarget with
  // open/close/show/hide/toggle — verified live: `qs -p /usr/share/omarchy/shell
  // ipc call brownfamilysports.wool toggle` opens the wall with no handler
  // declared here, and a duplicate declaration only earns a "will not be used"
  // warning in the shell log.

  // ------------------------------------------------------------- bar button

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-md-view_grid (U+F0570): a wall of cards. Verified present in the
    // bar's JetBrainsMono Nerd Font — the whole f0001-f1af0 Material block
    // ships in it. An absent glyph would leave a blank slot with no error.
    text: "󰕰"
    active: root.attentionCount > 0 || root.errorCount > 0
    tooltipText: root.heroMeta
    onPressed: function (buttonCode) {
      // Right-click goes straight to the first card that wants eyes, without
      // opening the wall — the Crook gesture, kept consistent.
      if (buttonCode === Qt.RightButton && (root.attentionCount > 0 || root.errorCount > 0))
        root.focusFirstAttention()
      else
        root.toggle()
    }
  }

  // ------------------------------------------------------------------- wall

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(1140))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: "Wool"
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Flow {
            id: flock
            width: parent.width
            spacing: Style.space(10)

            Repeater {
              model: root.ordered

              Rectangle {
                id: card
                required property var modelData

                readonly property string est: root.effectiveState(modelData)
                readonly property string tier: root.tierOf(est)
                readonly property var v: root.vitals[modelData.key] || null

                width: Style.space(262)
                height: Style.space(190)
                radius: Style.space(8)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                border.color: tier === "error" ? root.urgent
                  : tier === "attention" ? root.foreground : root.dim
                border.width: tier === "good" ? 1 : 2

                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)

                  Row {
                    width: parent.width
                    spacing: Style.space(10)

                    FleeceFace {
                      width: Style.space(64)
                      height: Style.space(48)
                      tier: card.tier
                      outline: root.dim
                    }

                    Column {
                      width: parent.width - Style.space(74)
                      spacing: Style.space(2)

                      Text {
                        width: parent.width
                        text: root.projectOf(card.modelData) || card.modelData.agent
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        width: parent.width
                        text: card.modelData.agent
                              + (card.v && card.v.model ? "  ·  " + card.v.model
                                  + (card.v.effort ? " · " + card.v.effort : "") : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                      Text {
                        width: parent.width
                        text: root.labelFor(card.est)
                        color: card.tier === "good" ? root.dim
                          : card.tier === "error" ? root.urgent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }
                  }

                  // The last prompt this agent was given — herd carries it,
                  // so no transcript is read to draw it. Plain text on
                  // purpose: it is other people's (and other agents') input.
                  Text {
                    width: parent.width
                    text: card.modelData.title || ""
                    visible: text !== ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                  }

                  // Vitals, or their honest absence. A missing measurement is
                  // a dash, never a zero-length bar pretending to be one.
                  Column {
                    width: parent.width
                    spacing: Style.space(3)
                    visible: card.v !== null

                    Repeater {
                      model: card.v ? [
                        { name: "CTX", frac: card.v.window },
                        { name: "FTG", frac: card.v.fatigue },
                        { name: "REL", frac: 1 - (card.v.relevance === undefined ? 1 : card.v.relevance) }
                      ] : []

                      Row {
                        required property var modelData
                        width: parent.width
                        spacing: Style.space(6)

                        Text {
                          text: modelData.name
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          width: Style.space(30)
                        }
                        Rectangle {
                          width: parent.width - Style.space(36)
                          height: Style.space(5)
                          radius: height / 2
                          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                          anchors.verticalCenter: parent.verticalCenter

                          Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, modelData.frac || 0))
                            height: parent.height
                            radius: height / 2
                            // Colour means direction: the ramp is tied to the
                            // threshold the verdict acts on, so a bar cannot
                            // look calm beside a chip that says act.
                            color: (modelData.frac || 0) > 0.8 ? root.urgent : root.foreground
                          }
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      visible: card.v && card.v.call !== undefined && card.v.call !== "RUN"
                      text: card.v ? String(card.v.call) : ""
                      color: root.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  Text {
                    width: parent.width
                    visible: card.v === null
                    text: "— no vitals —"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.focusAgent(card.modelData.key)
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.ordered.length === 0
            text: "Nothing on the wall yet. Claude sessions appear when the herd hooks are installed; `herd sync-herdr` mirrors everything else."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
