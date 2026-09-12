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

        Used for adjusting the thumbnail by setting \e frameNumForThumb to the desirable frame of the video for example.
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

    color: root.palette.window

    property url source: previewable.isPreviewable(entryUrl) ? entryUrl : ""
    property bool isSvg: previewable.isSvg(source)
    property bool isGif: previewable.isGif(source)
    property bool isVideo: previewable.isVideo(source)

    // Separate sources to not get a warning when going between different types.
    property url svgSource: isSvg ? source : ""
    property url gifSource: isGif ? source : ""
    property url videoSource: isVideo ? source : ""
    property url rasterSource: isSvg || isGif || isVideo ? "" : source

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
            value: loader.item && loader.item.width != 0 && loader.item.height != 0 ? Math.min(root.width / loader.item.width, root.height / loader.item.height) + loader.zoom : 1.0
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
                loader.saveToTransformCache();
            }

            function onYChanged() {
                loader.saveToTransformCache();
            }
        }

        onZoomChanged: saveToTransformCache()

        function saveToTransformCache() {
            if (loader.syncedToTransformCache) {
                loader.transformCache[loader.item.source] = {
                    zoom: loader.zoom,
                    x: loader.item.x,
                    y: loader.item.y
                };
            }
        }

        function restoreFromTransformCache() {
            if (!item) {
                return;
            }
            syncedToTransformCache = false;
            if (transformCache[item.source]) {
                zoom = transformCache[item.source].zoom;
                item.x = transformCache[item.source].x;
                item.y = transformCache[item.source].y;
            } else {
                zoom = 0;
                item.x = (root.width - item.width * item.scale) / 2;
                item.y = (root.height - item.height * item.scale) / 2;
            }
            syncedToTransformCache = true;
        }

        Component {
            id: rasterImage

            Image {
                source: root.rasterSource
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status == Image.Ready) {
                        loader.restoreFromTransformCache();
                    }
                }
            }
        }

        // Normally it's not used.
        Component {
            id: rasterizedSvgImage

            Image {
                source: root.source
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status == Image.Ready) {
                        loader.restoreFromTransformCache();
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
                onSourceChanged: loader.restoreFromTransformCache()
            }
        }

        Component {
            id: animatedImage

            AnimatedImage {
                source: root.gifSource
                asynchronous: true
                onStatusChanged: (status)=> {
                    if (status == Image.Ready) {
                        loader.restoreFromTransformCache();
                    }
                }
            }
        }

        Component {
            id: video

            VideoOutput {
                id: videoOutput

                property url source: root.videoSource // For the TransformCache.
                property bool firstRender
                function onFirstRender() {
                    if (!firstRender && width && height) {
                        firstRender = false;
                        loader.restoreFromTransformCache();
                    }
                }
                onWidthChanged: onFirstRender()
                onHeightChanged: onFirstRender()

                property MediaPlayer player: MediaPlayer {
                    source: root.videoSource
                    videoOutput: videoOutput
                    autoPlay: true
                    loops: MediaPlayer.Infinite
                }
            }
        }

        sourceComponent: if (root.isSvg) {
            return Diagnostics.rasterizeSvg ? rasterizedSvgImage : vectorImage;
        } else if (root.isGif) {
            return animatedImage;
        } else if (root.isVideo) {
            return video;
        } else {
            return rasterImage;
        }
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

            state: ((loader.sourceComponent === animatedImage || loader.sourceComponent === video) && mediaControlsHover.hovered) ? "Visible" : "Invisible"

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
                    SequentialAnimation{
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
                    SequentialAnimation{
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
                id: videoControlsComponent

                Item {
                    Row {
                        id: videoControls

                        // To simplify TransformCache functions, the controls are outside of the rendering components.
                        // But it causes some interference during transitions.
                        property MediaPlayer player: loader.item?.player ?? null

                        property real videoFps: {
                            let fps = player ? player.metaData.value(MediaMetaData.VideoFrameRate) : 0;
                            return fps > 0 ? fps : 30.0; // Default to 30 if undefined
                        }

                        property real msPerFrame: 1000.0 / videoFps
                        property int currentFrame: player ? Math.floor(player.position / msPerFrame) : 0;

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
                            onClicked: {
                                videoControls.player.pause()
                                videoControls.player.position = Math.max(0, videoControls.player.position - videoControls.msPerFrame)
                            }
                        }

                        ToolButton {
                            property bool isPlaying: videoControls.player ? videoControls.player.playbackState === MediaPlayer.PlayingState : false

                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, videoControls.visible && isPlaying ? "media-playback-pause" : "media-playback-start")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr(videoControls.visible && isPlaying ? "Pause" : "Play")
                            ToolTip.delay: 500
                            onClicked: {
                                if (isPlaying) {
                                    videoControls.player.pause()
                                } else {
                                    videoControls.player.play()
                                }
                            }
                        }

                        ToolButton {
                            width: mediaControlsPanel.iconSize
                            height: mediaControlsPanel.iconSize
                            icon.source: Themed.getIcon(root, "go-next")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Next frame")
                            ToolTip.delay: 500
                            display: AbstractButton.IconOnly
                            onClicked: {
                                videoControls.player.pause()
                                videoControls.player.position = Math.min(videoControls.player.duration, videoControls.player.position + videoControls.msPerFrame)
                            }
                        }
                    }

                    ToolButton {
                        anchors.bottom: videoControls.bottom
                        anchors.left: videoControls.right
                        anchors.leftMargin: width

                        width: mediaControlsPanel.iconSize
                        height: mediaControlsPanel.iconSize
                        icon.source: Themed.getIcon(root, "view-preview")
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Set this frame as a thumbnail")
                        ToolTip.delay: 500
                        display: AbstractButton.IconOnly
                        onClicked: root.setMeta("frameNumForThumb", videoControls.currentFrame)
                    }

                    Slider {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20

                        from: 0
                        to: videoControls.player && videoControls.player.duration > 0 ? videoControls.player.duration : 1

                        value: videoControls.player ? videoControls.player.position : 0
                        onMoved: videoControls.player.position = value
                    }
                }
            }

            Loader {
                anchors.fill: parent
                sourceComponent: loader.sourceComponent === animatedImage ? animationControlsComponent : loader.sourceComponent === video ? videoControlsComponent : null
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
