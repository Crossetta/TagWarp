// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.VectorImage

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

// Displays an entry
Rectangle {
    id: root

    property url entryUrl
    signal doubleClicked()

    function fit() {
        loader.zoom = 0;
        loader.item.x = (root.width - loader.item.width * loader.item.scale) / 2;
        loader.item.y = (root.height - loader.item.height * loader.item.scale) / 2;
    }

    color: root.palette.window

    property url source: previewable.isPreviewable(entryUrl) ? entryUrl : ""
    property bool isSvg: source.toString().toLowerCase().endsWith(".svg")

    Previewable {
        id: previewable
    }

    Loader {
        id: loader

        active: root.visible

        property real zoom
        property var transformCache: ({})
        property bool syncedToTransformCache

        Binding {
            target: loader.item
            property: "source"
            value: root.source
        }

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
                onSourceChanged: loader.restoreFromTransformCache()
            }
        }

        sourceComponent: root.isSvg ? Diagnostics.rasterizeSvg ? rasterizedSvgImage : vectorImage : rasterImage
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
