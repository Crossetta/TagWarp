// SPDX-License-Identifier: MIT

import QtMultimedia
import QtQuick
import QtQuick.VectorImage

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

/*!
    \qmltype MiniPreview
    \brief A preview that appears inside the entry info pane.

    MiniPreview shows the image or plays the video and has buttons to show a bigger preview.

    Usually appears alongside the entry's details.
*/
Item {
    id: root

    /*!
        \qmlproperty url MiniPreview::entryUrl
        \brief Path to the file to preview.
    */
    property url entryUrl
    readonly property url source: previewable.isPreviewable(root.entryUrl) ? root.entryUrl : ""
    readonly property bool isSvg: previewable.isSvg(root.source)
    readonly property bool isGif: previewable.isGif(root.source)
    readonly property bool isVideo: previewable.isVideo(root.source)

    // Separate sources to not get a warning when going between different types.
    property url svgSource: isSvg ? source : ""
    property url gifSource: isGif ? source : ""
    property url videoSource: isVideo ? source : ""
    property url rasterSource: isSvg || isGif || isVideo ? "" : source

    Previewable {
        id: previewable
    }

    Loader {
        anchors.fill: parent
        anchors.margins: 4

        Component {
            id: rasterImage

            Image {
                fillMode: Image.PreserveAspectFit
                source: root.rasterSource

                asynchronous: true
                smooth: false

                DelayedBusyIndicator {
                    anchors.fill: parent
                    opacity: 0.3
                    loading: parent.status === Image.Loading
                }
            }
        }

        // Normally it's not used.
        Component {
            id: rasterizedSvgImage

            Image {
                fillMode: Image.PreserveAspectFit
                source: root.svgSource

                asynchronous: true
                smooth: false

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

                DelayedBusyIndicator {
                    anchors.fill: parent
                    opacity: 0.3
                    loading: parent.status === Image.Loading
                }
            }
        }

        Component {
            id: vectorImage

            VectorImage {
                // Is stuck to top left instead of center (https://qt-project.atlassian.net/browse/QTBUG-140034).

                // Assume that the area is square.
                property real aspect: implicitWidth / implicitHeight
                x: aspect >= 1.0 ? 0 : (height - height * aspect) / 2
                y: aspect >= 1.0 ? (width - width / aspect) / 2 : 0

                fillMode: Image.PreserveAspectFit
                source: root.svgSource

                clip: true // Can sometimes render outside like carlitos-Cartoon-Landscape.svg.

                // No loading indicator. The asynchronousShapes doesn't help.
            }
        }

        Component {
            id: animatedImage

            AnimatedImage {
                fillMode: Image.PreserveAspectFit
                source: root.gifSource

                asynchronous: true
                smooth: false

                DelayedBusyIndicator {
                    anchors.fill: parent
                    opacity: 0.3
                    loading: parent.status === Image.Loading
                }
            }
        }

        Component {
            id: video

            VideoOutput {
                id: videoOutput
                MediaPlayer {
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
}
