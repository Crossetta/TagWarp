// SPDX-License-Identifier: MIT

#pragma once

#include <QCoreApplication>
#include <QDir>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class ModPortableMode : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl configPath READ getConfigPath NOTIFY configPathChanged)
    QML_SINGLETON
    QML_ELEMENT

  public:
    ModPortableMode(QObject *parent = nullptr);

    QUrl getConfigPath() const;

  signals:
    void configPathChanged();
};
