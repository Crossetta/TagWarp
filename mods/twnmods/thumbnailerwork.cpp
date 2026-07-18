// SPDX-License-Identifier: MIT

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QStringList>
#include <memory>
#include <utility>

static const QStringList THUMBNAILABLE_EXTENSIONS = {".gif", ".jpg", ".jpeg", ".png", ".svg", ".webp"};

extern "C" TW_EXPORT bool twThumbnailable(char *basename, char **err) {
    size_t len = strlen(basename);
    for (const QString &extension : THUMBNAILABLE_EXTENSIONS) {
        if (len >= extension.size() && extension.compare(&basename[len - extension.size()], Qt::CaseInsensitive) == 0) {
            return true;
        }
    }

    return false;
}

static std::pair<bool, QImage> ensureThumbnail(
    const QString &path, const QString &thumbnailDir, const QString &thumbnailName, const QSize &thumbSize) {

    QString thumbnailPath = thumbnailDir + thumbnailName;

    if (QFile(thumbnailPath).exists()) {
        QFileInfo thumbInfo(thumbnailPath);
        QFileInfo origInfo(path);

        if (!origInfo.exists() || thumbInfo.lastModified() > origInfo.lastModified()) {
            return std::make_pair(true, QImage());
        }
    }

    QImage image(path);
    if (image.isNull()) {
        qWarning() << "Failed to load an image";
        return std::make_pair(false, QImage());
    }

    QImage thumbnail = image.scaled(thumbSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    QDir(QFileInfo(thumbnailDir).absolutePath()).mkpath(".");

    bool saved = thumbnail.save(thumbnailPath);
    if (!saved) {
        qWarning() << "Failed to save a thumbnail";
    }

    return std::make_pair(saved, thumbnail);
}

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

    return ensureThumbnail(path, thumbnailDir, thumbnailName, QSize(thumbWidth, thumbHeight)).first;
}

TW_EXPORT QImage twThumbnailGetQImage(
    uint64_t       id,
    uint64_t       locationId,
    const QString &path,
    const QString &thumbnailDir,
    const QString &thumbnailName,
    const QSize   &thumbSize,
    char         **recoverableErr,
    char         **err) {

    auto [exists, image] = ensureThumbnail(path, thumbnailDir, thumbnailName, thumbSize);

    if (exists && image.isNull()) {
        QImage thumbnail(thumbnailDir + thumbnailName);
        if (thumbnail.isNull()) {
            qWarning() << "Failed to load a thumbnail";
        }
        image = thumbnail.scaled(thumbSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    return image.convertToFormat(QImage::Format_RGBA8888_Premultiplied);
}

// Used if twThumbnailGetQImage is not provided.
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

extern "C" TW_EXPORT void twThumbnailFreeImageData(void *cleanupInfo) {
    std::unique_ptr<QImage> thumbnail((QImage *)cleanupInfo);
}
