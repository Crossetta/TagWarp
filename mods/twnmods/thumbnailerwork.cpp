// SPDX-License-Identifier: MIT

/*!
    \brief Thumbnails generation.

    Functions to generate and refresh thumbnails - smaller version of images that are used as file icons.
*/

#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QMediaMetaData>
#include <QMediaPlayer>
#include <QStringList>
#include <QTemporaryFile>
#include <QTimer>
#include <QVideoFrame>
#include <QVideoSink>
#include <memory>
#include <utility>

#include "tweerrorcheckutilslibc.h"
#include "twemeta.h"
#include "twestrmap.h"

static const int   VID_TIMEOUT_MSEC = 3000;
static const qreal VID_DEFAULT_FPS  = 30.0;

static const QStringList IMAGES     = {".jpg", ".jpeg", ".png", ".svg", ".webp"};
static const QStringList ANIMATIONS = {".gif"};
static const QStringList VIDEOS     = {
    ".avi", ".flv", ".mkv", ".mov", "m4v", "mp4", "mpeg", ".ts", ".vob", ".webm", ".wmv"};

/*!
    \fn bool twThumbnailable(char *basename, char **err)
    \brief Returns \c true if the \a basename looks like a file name that a thumbnail can be generated for it.

    May fail and set the \a err.
*/
extern "C" TW_EXPORT bool twThumbnailable(char *basename, char **err) {
    size_t len = strlen(basename);
    for (const QString &extension : IMAGES) {
        if (len >= extension.size() && extension.compare(&basename[len - extension.size()], Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    for (const QString &extension : VIDEOS) {
        if (len >= extension.size() && extension.compare(&basename[len - extension.size()], Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    for (const QString &extension : ANIMATIONS) {
        if (len >= extension.size() && extension.compare(&basename[len - extension.size()], Qt::CaseInsensitive) == 0) {
            return true;
        }
    }

    return false;
}

static bool isOfType(const QString &path, const QStringList &exts) {
    for (const QString &extension : exts) {
        if (path.endsWith(extension, Qt::CaseInsensitive)) {
            return true;
        }
    }
    return false;
}

static std::pair<bool, QImage> ensureThumbnail(
    uint64_t       id,
    uint64_t       locationId,
    const QString &path,
    const QString &thumbnailDir,
    const QString &thumbnailName,
    const QSize   &thumbSize,
    char         **err) {

    QString thumbnailPath = thumbnailDir + thumbnailName;

    if (QFile(thumbnailPath).exists()) {
        QFileInfo thumbInfo(thumbnailPath);
        QFileInfo origInfo(path);

        if (!origInfo.exists() || thumbInfo.lastModified() > origInfo.lastModified()) {
            return std::make_pair(true, QImage());
        }
    }

    QImage image;

    if (isOfType(path, IMAGES)) {
        image.load(path);
    } else if (isOfType(path, VIDEOS)) {
        TWStrMap *m;
        tweMetaGetForEntry(id, locationId, &m, err);
        EB_GF(!*err);

        void        *v;
        TWStrMapType t;
        intptr_t frame = tweStrMapGet(m, "frameNumForThumb", &v, &t, err) && t == TW_STR_MAP_TYPE_INT ? (intptr_t)v : 0;
        EB_GF(!*err);

        QMediaPlayer player;
        QVideoSink   sink;
        player.setVideoOutput(&sink);
        player.setSource(QUrl::fromLocalFile(path));

        QEventLoop loop;
        bool       frameCaptured = false;

        QObject::connect(&player, &QMediaPlayer::mediaStatusChanged, [&](QMediaPlayer::MediaStatus status) {
            if (status == QMediaPlayer::LoadedMedia) {
                QVariant fpsVar = player.metaData().value(QMediaMetaData::VideoFrameRate);
                qreal    fps    = fpsVar.isValid() ? fpsVar.toReal() : VID_DEFAULT_FPS;
                if (fps <= 0.0) {
                    fps = VID_DEFAULT_FPS;
                }

                qint64 targetMs = static_cast<qint64>((frame / fps) * 1000.0);

                player.setPosition(targetMs);
            } else if (status == QMediaPlayer::InvalidMedia) {
                loop.quit();
            }
        });

        QObject::connect(&sink, &QVideoSink::videoFrameChanged, [&](const QVideoFrame &videoFrame) {
            if (videoFrame.isValid() && !frameCaptured) {
                image         = videoFrame.toImage();
                frameCaptured = true;
                loop.quit();
            }
        });

        QTimer timeoutTimer;
        timeoutTimer.setSingleShot(true);
        QObject::connect(&timeoutTimer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timeoutTimer.start(VID_TIMEOUT_MSEC);

        player.pause();
        loop.exec();

        if (!frameCaptured) {
            image = QImage();
        }
    } else if (isOfType(path, ANIMATIONS)) {
        QImageReader imageLoader(path);

        TWStrMap *m;
        tweMetaGetForEntry(id, locationId, &m, err);
        EB_GF(!*err);

        void        *v;
        TWStrMapType t;

        intptr_t frame = tweStrMapGet(m, "frameNumForThumb", &v, &t, err) && t == TW_STR_MAP_TYPE_INT ? (intptr_t)v : 0;
        EB_GF(!*err);

        intptr_t f = -1;
        while (f < frame && imageLoader.read(&image)) {
            ++f;
        }

        if (f != frame) {
            image = QImage();
        }
    } else {
        EB_ERR_GF(false, "Unknown file extension for thumbnailing. This is a bug.");
    }

    if (image.isNull()) {
        qWarning() << "Failed to load an image";
        return std::make_pair(false, QImage());
    }

    {
        QImage thumbnail = image.scaled(thumbSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);

        QDir(QFileInfo(thumbnailDir).absolutePath()).mkpath(".");

        QTemporaryFile tmp(thumbnailPath);

        if (!tmp.open() || !thumbnail.save(&tmp, "WEBP")) {
            qWarning() << "Failed to save a thumbnail";
            return std::make_pair(false, thumbnail);
        }
        tmp.close();
        tmp.renameOverwrite(thumbnailPath);
        tmp.setAutoRemove(false);

        return std::make_pair(true, thumbnail);
    }

fail:
    return std::make_pair(false, QImage());
}

/*!
    \fn bool twThumbnailEnsureUpToDate(
        uint64_t    id,
        uint64_t    locationId,
        const char *path,
        const char *thumbnailDir,
        const char *thumbnailName,
        int         thumbWidth,
        int         thumbHeight,
        char      **recoverableErr,
        char      **err)
    \brief Makes sure that th thumbnail file is up to date and returns \c true if succeeded to achieve that.

    \a id and \a locationId are invalid after the call returns.

    The \a path is the full path to the original.

    \a thumbnailDir with \a thumbnailName is the path to thumbnail to check or generate.

    \a thumbWidth and \a thumbHeight are the bounding box dimensions.

    Useful for the QML functions that show small numbers of thumbnails by URL.

    May fail and set the \a err or \a recoverableErr.
*/
extern "C" TW_EXPORT bool twThumbnailEnsureUpToDate(
    uint64_t    id,
    uint64_t    locationId,
    const char *path,
    const char *thumbnailDir,
    const char *thumbnailName,
    int         thumbWidth,
    int         thumbHeight,
    char      **recoverableErr,
    char      **err) {

    return ensureThumbnail(id, locationId, path, thumbnailDir, thumbnailName, QSize(thumbWidth, thumbHeight), err)
        .first;
}

/*!
    \fn QImage twThumbnailGetQImage(
        uint64_t       id,
        uint64_t       locationId,
        const QString &path,
        const QString &thumbnailDir,
        const QString &thumbnailName,
        const QSize   &thumbSize,
        char         **recoverableErr,
        char         **err)
    \brief Generates (if needed), saves and returns a thumbnail.

    \a id and \a locationId are invalid after the call returns.

    The \a path is the full path to the original.

    \a thumbnailDir with \a thumbnailName is the path to thumbnail to check or generate.

    \a thumbSize is the bounding box dimensions.

    May fail and set the \a err or \a recoverableErr.
*/
TW_EXPORT QImage twThumbnailGetQImage(
    uint64_t       id,
    uint64_t       locationId,
    const QString &path,
    const QString &thumbnailDir,
    const QString &thumbnailName,
    const QSize   &thumbSize,
    char         **recoverableErr,
    char         **err) {

    auto [exists, image] = ensureThumbnail(id, locationId, path, thumbnailDir, thumbnailName, thumbSize, err);
    EB_GF(!*err);

    if (exists && image.isNull()) {
        QImage thumbnail(thumbnailDir + thumbnailName);
        if (thumbnail.isNull()) {
            qWarning() << "Failed to load a thumbnail";
            return QImage();
        }
        image = thumbnail.scaled(thumbSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    return image.convertToFormat(QImage::Format_RGBA8888_Premultiplied);

fail:
    return QImage();
}

/*!
    \fn void twThumbnailGetImageData(
        uint64_t        id,
        uint64_t        locationId,
        const char     *path,
        const char     *thumbnailDir,
        const char     *thumbnailName,
        int            *thumbWidthInOut,
        int            *thumbHeightInOut,
        const uint8_t **data,
        void          **cleanupInfo,
        char          **recoverableErr,
        char          **err)
    \brief Generates (if needed), saves and returns a thumbnail.

    \a id and \a locationId are invalid after the call returns.

    The \a path is the full path to the original.

    \a thumbnailDir with \a thumbnailName is the path to thumbnail to check or generate.

    \a thumbWidthInOut and \a thumbHeightInOut are the bounding box dimensions. The resulting dimensions are returned.

    \a data is raw data in \e Format_RGBA8888_Premultiplied. The \a cleanupInfo is for the use with
   twThumbnailFreeImageData().

    Used if twThumbnailGetQImage() is not provided.

    May fail and set the \a err or \a recoverableErr.

    \sa twThumbnailFreeImageData()
*/
extern "C" TW_EXPORT void twThumbnailGetImageData(
    uint64_t        id,
    uint64_t        locationId,
    const char     *path,
    const char     *thumbnailDir,
    const char     *thumbnailName,
    int            *thumbWidthInOut,
    int            *thumbHeightInOut,
    const uint8_t **data,
    void          **cleanupInfo,
    char          **recoverableErr,
    char          **err) {

    auto thumbnail = std::make_unique<QImage>(twThumbnailGetQImage(
        id,
        locationId,
        QString::fromUtf8(path),
        QString::fromUtf8(thumbnailDir),
        QString::fromUtf8(thumbnailName),
        QSize(*thumbWidthInOut, *thumbHeightInOut),
        recoverableErr,
        err));

    if (!*err && !*recoverableErr) {
        *thumbWidthInOut  = thumbnail->width();
        *thumbHeightInOut = thumbnail->height();
        *data             = thumbnail->constBits();
        *cleanupInfo      = thumbnail.release();
    }
}

/*!
    \fn void twThumbnailFreeImageData(void *cleanupInfo)
    \brief Deletes image data associated with \a cleanupInfo.

    \sa twThumbnailGetImageData()
*/
extern "C" TW_EXPORT void twThumbnailFreeImageData(void *cleanupInfo) {
    std::unique_ptr<QImage> thumbnail((QImage *)cleanupInfo);
}
