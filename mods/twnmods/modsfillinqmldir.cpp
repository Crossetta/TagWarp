// SPDX-License-Identifier: MIT

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTextStream>

#ifdef __cplusplus
extern "C" {
#endif

TW_EXPORT void twModsFillInQmldir(const char *path) {
    QDir          importDir(path);
    QDir          dir(importDir.filePath("twqmods"));
    const QString qmldirPath = dir.filePath("qmldir");

    QStringList   lines;
    QSet<QString> existingModules;
    QSet<QString> definedModules;
    QString       version = "1.0";

    bool needsRewrite = false;

    // Find all QML files
    const QFileInfoList qmlFiles = dir.entryInfoList(QStringList() << "*.qml", QDir::Files);

    for (const QFileInfo &fi : qmlFiles) {
        existingModules.insert(fi.completeBaseName());
    }

    // Read qmldir if present
    QFile inFile(qmldirPath);
    if (inFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&inFile);

        QRegularExpression re(R"(^\s*([A-Za-z_][A-Za-z0-9_]*)\s+([0-9]+\.[0-9]+)\s+(.+\.qml)\s*$)");

        while (!in.atEnd()) {
            QString line = in.readLine();

            auto match = re.match(line);
            if (match.hasMatch()) {
                const QString typeName     = match.captured(1);
                const QString foundVersion = match.captured(2);

                if (!existingModules.contains(typeName)) {
                    needsRewrite = true;
                    continue;
                }

                definedModules.insert(typeName);

                // Take version from first valid entry
                if (version == "1.0") {
                    version = foundVersion;
                }
            }

            lines.append(line);
        }
    }

    // Ensure "module ." exists
    bool hasModuleLine = false;
    for (const QString &line : lines) {
        if (line.trimmed() == "module .") {
            hasModuleLine = true;
            break;
        }
    }

    if (!hasModuleLine) {
        lines.prepend("module .");
        needsRewrite = true;
    }

    for (const QString &baseName : existingModules) {
        // Skip if already present
        if (definedModules.contains(baseName)) {
            continue;
        }

        lines.append(QString("%1 %2 %1.qml").arg(baseName, version));
        needsRewrite = true;
    }

    needsRewrite = needsRewrite || qmlFiles.size() != existingModules.size();

    if (!needsRewrite) {
        return;
    }

    // Rewrite qmldir
    QFile outFile(qmldirPath);
    if (!outFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qWarning() << "Failed to write qmldir file for" << path;
        return;
    }

    QTextStream out(&outFile);

    for (const QString &line : std::as_const(lines)) {
        out << line << '\n';
    }
}

#ifdef __cplusplus
}
#endif
