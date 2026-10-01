// SPDX-License-Identifier: MIT

import QtMultimedia
import QtQuick
import QtQuick.VectorImage
import QtQuick.Controls

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

/*!
    \qmltype Preview
    \brief Displays an entry.

    Preview shows the image or plays the video and has buttons to control the playback and edit the thumbnail.

    The image can be panned and zoomed.
*/
Rectangle {
    id: root

    /*!
        \qmlproperty url Preview::entryUrl
        \brief Path to the file to preview.
    */
    property url entryUrl

    /*!
        \qmlsignal Preview::doubleClicked
        \brief Used by the parent window to hide the preview.
    */
    signal doubleClicked()

    /*!
        \qmlsignal Preview::setMeta(string key, var value)
        \brief Sets entry's metadata \a key to \a value.

        Used for adjusting the thumbnail by setting \c frameNumForThumb to the desirable frame of the video for example.
    */
    signal setMeta(key: string, value: var)

    /*!
        \qmlmethod Preview::fit()
        \brief Fits the previewed item to the dimensions of the preview.
    */
    function fit() {
        loader.zoom = 0;
        loader.item.x = (root.width - loader.item.width * loader.item.scale) / 2;
        loader.item.y = (root.height - loader.item.height * loader.item.scale) / 2;
    }

    // Formats millisecond duration into HH:MM:SS or MM:SS
    function formatTime(ms) {
        if (isNaN(ms) || ms < 0) return "00:00";
        let totalSeconds = Math.floor(ms / 1000);
        let hours = Math.floor(totalSeconds / 3600);
        let minutes = Math.floor((totalSeconds % 3600) / 60);
        let seconds = totalSeconds % 60;

        let minStr = minutes.toString().padStart(2, '0');
        let secStr = seconds.toString().padStart(2, '0');

        if (hours > 0) {
            return hours + ":" + minStr + ":" + secStr;
        }
        return minStr + ":" + secStr;
    }

    color: root.palette.window

    property url source: previewable.isPreviewable(entryUrl) ? entryUrl : ""
    property bool isSvg: previewable.isSvg(source)
    property bool isGif: previewable.isGif(source)
    property bool isVideo: previewable.isVideo(source)
    property bool isAudio: previewable.isAudio(source)

    // Separate sources to not get a warning when going between different types.
    property url svgSource: isSvg ? source : ""
    property url gifSource: isGif ? source : ""
    property url videoSource: isVideo ? source : ""
    property url audioSource: isAudio ? source : ""
    property url rasterSource: isSvg || isGif || isVideo || isAudio ? "" : source

    Previewable {
        id: previewable
    }

    MouseArea {
        anchors.fill: parent

        drag.target: loader.item
        drag.axis: Drag.XAndYAxis
        drag.minimumX: Math.min(root.width - loader.item?.width * loader.item?.scale, 0)
        drag.maximumX: Math.max(root.width - loader.item?.width * loader.item?.scale, 0)
        drag.minimumY: Math.min(root.height - loader.item?.height * loader.item?.scale, 0)
        drag.maximumY: Math.max(root.height - loader.item?.height * loader.item?.scale, 0)

        onDoubleClicked: (mouse)=> { root.doubleClicked(); }
    }

    Loader {
        id: loader

        active: root.visible

        property real zoom
        property var transformCache: ({})
        property bool syncedToTransformCache

        Binding {
            target: loader.item
            property: "fillMode"
            value: Image.PreserveAspectFit
        }

        Binding {
            target: loader.item
            property: "transformOrigin"
            value: Item.TopLeft
        }

        Binding {
            target: loader.item
            property: "scale"
            value: loader.item && loader.item.width !== 0 && loader.item.height !== 0 ? Math.min(root.width / loader.item.width, root.height / loader.item.height) + loader.zoom : 1.0
        }

        Connections { // Center it when the window is resized and the image is small.
            target: root
            function onWidthChanged() {
                if (loader.item && root.width > loader.item.width * loader.item.scale) {
                    loader.item.x = (root.width - loader.item.width * loader.item.scale) / 2;
                }
            }
            function onHeightChanged() {
                if (loader.item && root.height > loader.item.height * loader.item.scale) {
                    loader.item.y = (root.height - loader.item.height * loader.item.scale) / 2;
                }
            }
        }

        Connections {
            target: loader.item

            function onXChanged() {
                loader.saveGeometryToTransformCache();
            }

            function onYChanged() {
                loader.saveGeometryToTransformCache();
            }
        }

        onZoomChanged: saveGeometryToTransformCache()

        function saveGeometryToTransformCache() {
            if (loader.syncedToTransformCache && loader.item && loader.item.cacheId) {
                let cache = loader.transformCache;
                let data = cache[loader.item.source] || {};
                data.zoom = loader.zoom;
                data.x = loader.item.x;
                data.y = loader.item.y;
                cache[loader.item.cacheId] = data;
                loader.transformCache = cache;
            }
        }

        function saveMediaCtlsToTransformCache(volume, position, paused) {
            if (loader.syncedToTransformCache && loader.item && loader.item.cacheId) {
                let cache = loader.transformCache;
                let data = cache[loader.item.cacheId] || {};
                if (volume !== undefined) data.volume = volume;
                if (position !== undefined) data.position = position;
                if (paused !== undefined) data.paused = paused;
                cache[loader.item.cacheId] = data;
                loader.transformCache = cache;
            }
        }

        function restoreGeometryFromTransformCache() {
            if (!item) {
                return;
            }
            syncedToTransformCache = false;
            if (transformCache[item.cacheId]) {
                zoom = transformCache[item.cacheId].zoom;
                item.x = transformCache[item.cacheId].x;
                item.y = transformCache[item.cacheId].y;
            } else {
                zoom = 0;
                item.x = (root.width - item.width * item.scale) / 2;
                item.y = (root.height - item.height * item.scale) / 2;
            }
            syncedToTransformCache = true;
        }

        function restoreMediaCtlsFromTransformCache() {
            if (!item) {
                return;
            }
            syncedToTransformCache = false;
            let cacheData = transformCache[item.cacheId];

            if (!cacheData && item.player && item.player.audioOutput) {
                item.player.audioOutput.volume = GlobalState.defaultAudioVolume
            }

            if (cacheData && item.player) {
                if (cacheData.volume !== undefined && item.player.audioOutput) {
                    item.player.audioOutput.volume = cacheData.volume;
                }
                if (cacheData.position !== undefined) {
                    item.player.position = cacheData.position;
                }
                if (cacheData.paused) {
                    item.player.pause();
                } else {
                    item.player.play();
                }
            }
            syncedToTransformCache = true;
        }

        Component {
            id: rasterImage

            Image {
                source: root.rasterSource
                property string cacheId: source
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status === Image.Ready) {
                        loader.restoreGeometryFromTransformCache();
                    }
                }
            }
        }

        // Normally it's not used.
        Component {
            id: rasterizedSvgImage

            Image {
                source: root.source
                property string cacheId: source
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status === Image.Ready) {
                        loader.restoreGeometryFromTransformCache();
                    }
                }

                // SVG clarity hack (https://forum.qt.io/topic/52161/properly-scaling-svg-images).
                sourceSize: root.isSvg && svgHackLoader.item
                            ? Qt.size(svgHackLoader.item.sourceSize.width * 4,
                                      svgHackLoader.item.sourceSize.height * 4)
                            : undefined

                Loader {
                    id: svgHackLoader
                    active: root.isSvg

                    sourceComponent: Image {
                        source: root.source
                        width: 0
                        height: 0
                    }
                }
            }
        }

        Component {
            id: vectorImage

            VectorImage {
                source: root.svgSource
                property string cacheId: source
                onSourceChanged: loader.restoreGeometryFromTransformCache()
            }
        }

        Component {
            id: animatedImage

            AnimatedImage {
                source: root.gifSource
                property string cacheId: source
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status === Image.Ready) {
                        loader.restoreGeometryFromTransformCache();
                    }
                }
            }
        }

        Component {
            id: video

            VideoOutput {
                id: videoOutput

                property string source: root.videoSource // So the fallback icon doesn't appear.
                property string cacheId: source
                property bool initialRenderDone
                property bool initialPlaybackDone

                function checkReady() {
                    if (!initialRenderDone && width && height) {
                        initialRenderDone = true;
                        loader.restoreGeometryFromTransformCache();
                    }

                    if (!initialPlaybackDone && player.mediaStatus === MediaPlayer.LoadedMedia) {
                        initialPlaybackDone = true;
                        loader.restoreMediaCtlsFromTransformCache()
                    }
                }

                onWidthChanged: checkReady()
                onHeightChanged: checkReady()

                property MediaPlayer player: MediaPlayer {
                    source: root.videoSource
                    videoOutput: videoOutput
                    audioOutput: AudioOutput {}
                    autoPlay: true
                    loops: MediaPlayer.Infinite
                }

                Connections {
                    target: videoOutput.player
                    function onMediaStatusChanged() { videoOutput.checkReady(); }
                }
            }
        }

        Component {
            id: audio

            Image {
                id: audioItem

                property string cacheId: root.audioSource
                property bool isGeometryLoaded
                property bool isMediaCtlsLoaded

                property MediaPlayer player: MediaPlayer {
                    source: root.audioSource
                    audioOutput: AudioOutput {}
                    autoPlay: true
                    loops: MediaPlayer.Infinite
                    onMediaStatusChanged: audioItem.checkReady()
                }

                source: {
                    if (!player || !player.metaData) {
                        return "";
                    }
                    return ImageFuncs.toDataUri(player.metaData.value(MediaMetaData.CoverArtImage) || player.metaData.value(MediaMetaData.ThumbnailImage));
                }

                asynchronous: true

                function checkReady() {
                    if (!isGeometryLoaded && (status === Image.Ready || status === Image.Error)) {
                        isGeometryLoaded = true;
                        loader.restoreGeometryFromTransformCache();
                    }
                    if (!isMediaCtlsLoaded && player.mediaStatus === MediaPlayer.LoadedMedia) {
                        isMediaCtlsLoaded = true;
                        loader.restoreMediaCtlsFromTransformCache();
                    }
                }

                onStatusChanged: checkReady()

                Connections {
                    target: audioItem.player
                    function onMediaStatusChanged() {
                        audioItem.checkReady();
                    }
                }
            }
        }

        sourceComponent: if (root.isSvg) {
            return Diagnostics.rasterizeSvg ? rasterizedSvgImage : vectorImage;
        } else if (root.isGif) {
            return animatedImage;
        } else if (root.isVideo) {
            return video;
        } else if (root.isAudio) {
            return audio;
        } else {
            return rasterImage;
        }
    }

    VectorImage {
        visible: loader.item?.source.toString() === ""
        anchors.centerIn: parent
        width: mediaControlsPanel.iconSize * 4
        height: mediaControlsPanel.iconSize * 4
        source: Themed.getIcon(root, "audio-x-generic")
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        height: mediaControlsPanel.iconSize + 12

        HoverHandler { id: mediaControlsHover }

        Item {
            id: mediaControlsPanel

            anchors.fill: parent

            property int iconSize: 48

            state: ((loader.sourceComponent === animatedImage || loader.sourceComponent === video || loader.sourceComponent === audio) && mediaControlsHover.hovered) ? "Visible" : "Invisible"

            states: [
                State{
                    name: "Visible"
                    PropertyChanges {
                        mediaControlsPanel {
                            opacity: 1.0
                            visible: true
                        }
                    }
                },
                State{
                    name: "Invisible"
                    PropertyChanges {
                        mediaControlsPanel {
                            opacity: 0.0
                            visible: false
                        }
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "Visible"
                    to: "Invisible"
                    SequentialAnimation {
                        PropertyAnimation {
                            duration: 1000
                        }
                        NumberAnimation {
                            target: mediaControlsPanel
                            property: "opacity"
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: mediaControlsPanel
                            property: "visible"
                            duration: 0
                        }
                    }
                },
                Transition {
                    from: "Invisible"
                    to: "Visible"
                    SequentialAnimation {
                        NumberAnimation {
                            target: mediaControlsPanel
                            property: "visible"
                            duration: 0
                        }
                        NumberAnimation {
                            target: mediaControlsPanel
                            property: "opacity"
                            duration: 200
                            easing.type: Easing.InQuad
                        }
                    }
                }
            ]

            Component {
                id: animationControlsComponent

                Item {
                    Row {
                        id: animationControls

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter

                        ToolButton {
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, "go-previous")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Previous frame")
                            ToolTip.delay: 500
                            display: AbstractButton.IconOnly
                            onClicked: loader.item.currentFrame = Math.max(0, loader.item.currentFrame - 1)
                        }
                        ToolButton {
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, animationControls.visible && loader.item.playing ? "media-playback-pause" : "media-playback-start")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr(animationControls.visible && loader.item.playing ? "Pause" : "Play")
                            ToolTip.delay: 500
                            onClicked: loader.item.playing = !loader.item.playing
                        }
                        ToolButton {
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, "go-next")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Next frame")
                            ToolTip.delay: 500
                            display: AbstractButton.IconOnly
                            onClicked: loader.item.currentFrame = Math.min(loader.item.currentFrame + 1, loader.item.frameCount)
                        }
                    }

                    ToolButton {
                        anchors.bottom: animationControls.bottom
                        anchors.left: animationControls.right
                        anchors.leftMargin: width

                        width: mediaControlsPanel.iconSize
                        height: mediaControlsPanel.iconSize
                        icon.source: Themed.getIcon(root, "view-preview")
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Set this frame as a thumbnail")
                        ToolTip.delay: 500
                        display: AbstractButton.IconOnly
                        onClicked: root.setMeta("frameNumForThumb", loader.item.currentFrame)
                    }
                }
            }

            Component {
                id: mediaControlsComponent

                Item {
                    id: mediaControlsRoot

                    // To simplify TransformCache functions, the controls are outside of the rendering components.
                    // But it causes some interference during transitions.
                    property MediaPlayer player: loader.item?.player ?? null

                    property real videoFps: {
                        let fps = player ? player.metaData.value(MediaMetaData.VideoFrameRate) : 0;
                        return fps > 0 ? fps : 30.0;
                    }

                    property real msPerFrame: 1000.0 / videoFps
                    property int currentFrame: player ? Math.floor(player.position / msPerFrame) : 0;

                    // Left Side: Volume & Timeline Row.
                    Row {
                        id: audioInfoRow
                        anchors.left: parent.left
                        anchors.bottom: mediaControls.bottom
                        spacing: 8

                        Row {
                            ToolButton {
                                width: mediaControlsPanel.iconSize * 0.75
                                height: mediaControlsPanel.iconSize * 0.75
                                anchors.verticalCenter: parent.verticalCenter
                                icon.source: {
                                    if (mediaControlsRoot.player && mediaControlsRoot.player.audioOutput) {
                                        return Themed.getIcon(root, mediaControlsRoot.player.audioOutput.muted || mediaControlsRoot.player.audioOutput.volume === 0 ? "audio-volume-muted" : "player-volume");
                                    }
                                    return Themed.getIcon(root, "player-volume");
                                }
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Mute")
                                ToolTip.delay: 500
                                display: AbstractButton.IconOnly
                                onClicked: {
                                    if (mediaControlsRoot.player && mediaControlsRoot.player.audioOutput) {
                                        mediaControlsRoot.player.audioOutput.muted = !mediaControlsRoot.player.audioOutput.muted;
                                    }
                                }
                            }

                            Slider {
                                id: volumeSlider
                                width: 100
                                anchors.verticalCenter: parent.verticalCenter
                                value: mediaControlsRoot.player && mediaControlsRoot.player.audioOutput ? mediaControlsRoot.player.audioOutput.volume : GlobalState.defaultAudioVolume // Not necessairly the initial value. It may be set in the cache load.
                                onMoved: {
                                    if (mediaControlsRoot.player && mediaControlsRoot.player.audioOutput) {
                                        mediaControlsRoot.player.audioOutput.volume = value;
                                        mediaControlsRoot.player.audioOutput.muted = false;
                                        loader.saveMediaCtlsToTransformCache(value, undefined, undefined);
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.palette.windowText
                            text: {
                                if (!mediaControlsRoot.player) {
                                    return "00:00 / 00:00";
                                }
                                return root.formatTime(mediaControlsRoot.player.position) + " / " + root.formatTime(mediaControlsRoot.player.duration);
                            }
                        }
                    }

                    // Middle: Playback controls.
                    Row {
                        id: mediaControls

                        anchors.horizontalCenter: parent.horizontalCenter

                        ToolButton {
                            visible: root.isVideo
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, "go-previous")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Previous frame")
                            ToolTip.delay: 500
                            display: AbstractButton.IconOnly
                            onClicked: {
                                mediaControlsRoot.player.pause()
                                mediaControlsRoot.player.position = Math.max(0, mediaControlsRoot.player.position - mediaControlsRoot.msPerFrame)
                                loader.saveMediaCtlsToTransformCache(undefined, mediaControlsRoot.player.position, true)
                            }
                        }

                        ToolButton {
                            property bool isPlaying: mediaControlsRoot.player ? mediaControlsRoot.player.playbackState === MediaPlayer.PlayingState : false

                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, mediaControls.visible && isPlaying ? "media-playback-pause" : "media-playback-start")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr(mediaControls.visible && isPlaying ? "Pause" : "Play")
                            ToolTip.delay: 500
                            onClicked: {
                                if (isPlaying) {
                                    mediaControlsRoot.player.pause()
                                    loader.saveMediaCtlsToTransformCache(undefined, mediaControlsRoot.player.position, true)
                                } else {
                                    mediaControlsRoot.player.play()
                                    loader.saveMediaCtlsToTransformCache(undefined, undefined, false)
                                }
                            }
                        }

                        ToolButton {
                            visible: root.isVideo
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, "go-next")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Next frame")
                            ToolTip.delay: 500
                            display: AbstractButton.IconOnly
                            onClicked: {
                                mediaControlsRoot.player.pause()
                                mediaControlsRoot.player.position = Math.min(mediaControlsRoot.player.duration, mediaControlsRoot.player.position + mediaControlsRoot.msPerFrame)
                                loader.saveMediaCtlsToTransformCache(undefined, mediaControlsRoot.player.position, true)
                            }
                        }
                    }

                    ToolButton {
                        visible: root.isVideo
                        anchors.bottom: mediaControls.bottom
                        anchors.left: mediaControls.right
                        anchors.leftMargin: width

                        width: mediaControlsPanel.iconSize
                        height: mediaControlsPanel.iconSize
                        icon.source: Themed.getIcon(root, "view-preview")
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Set this frame as a thumbnail")
                        ToolTip.delay: 500
                        display: AbstractButton.IconOnly
                        onClicked: root.setMeta("frameNumForThumb", mediaControlsRoot.currentFrame)
                    }

                    Slider {
                        id: seekSlider
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20

                        from: 0
                        to: mediaControlsRoot.player && mediaControlsRoot.player.duration > 0 ? mediaControlsRoot.player.duration : 1

                        value: mediaControlsRoot.player ? mediaControlsRoot.player.position : 0
                        onMoved: {
                            if (mediaControlsRoot.player) {
                                mediaControlsRoot.player.position = value
                                loader.saveMediaCtlsToTransformCache(undefined, value, undefined)
                            }
                        }
                    }
                }
            }

            Loader {
                anchors.fill: parent
                sourceComponent: loader.sourceComponent === animatedImage ? animationControlsComponent :
                                 (loader.sourceComponent === video || loader.sourceComponent === audio) ? mediaControlsComponent : null
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel)=> {
            const oldZoom = Math.min(root.width / loader.item.width, root.height / loader.item.height) + loader.zoom;

            if (wheel.angleDelta.y > 0) {
                loader.zoom = Number((loader.zoom + .1).toFixed(1));
            } else if (loader.zoom > 0) {
                loader.zoom = Number((loader.zoom - .1).toFixed(1));
            }

            const newZoom = Math.min(root.width / loader.item.width, root.height / loader.item.height) + loader.zoom;

            const imgX = (wheel.x - loader.item.x) / oldZoom;
            const imgY = (wheel.y - loader.item.y) / oldZoom;

            loader.item.x = wheel.x - imgX * newZoom;
            loader.item.y = wheel.y - imgY * newZoom;
        }
    }
}
