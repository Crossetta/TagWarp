// SPDX-License-Identifier: MIT

/*!
    \brief Mods builder.

    Functions that the application uses to build the mods.

    They pull a docker image with the build environment, generate build files and rebuild the mods.
*/

#include <QCoreApplication>
#include <QDebug>
#include <QProcessEnvironment>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QThread>
#include <QtConcurrent>
#include <memory>

#include "tweadjustpathsfordocker.h"
#include "tweerrorcheckutilslibc.h"
#include "tweexports.h"

#define TW_MAX_MOD_BUILD_OUTPUT_LEN 8192

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

#define TW_QT_VERSION STR(QT_VERSION_MAJOR) "." STR(QT_VERSION_MINOR)

#ifdef _WIN32
#define TW_DOCKER "docker.exe"
#else
#define TW_DOCKER "docker"
#endif

#ifdef _WIN32
#define TW_ILIB "libtagwarp.dll.a"
#endif

#ifdef _WIN32
#define TW_MOD_LIB "twnmods.dll"
#define TW_MOD_PLUGIN "twnmodsplugin.dll"
#else
#define TW_MOD_LIB "libtwnmods.so"
#define TW_MOD_PLUGIN "libtwnmodsplugin.so"
#endif

#if defined(Q_OS_LINUX)
#define TW_PLATFORM "linux"
#elif defined(Q_OS_MACOS)
#if defined(Q_PROCESSOR_ARM)
#define TW_PLATFORM "macos-arm64"
#else
#define TW_PLATFORM "macos-x86_64"
#endif
#elif defined(_WIN32)
#define TW_PLATFORM "windows"
#else
#define TW_PLATFORM "unknown";
#endif

static QStringList getSrcFiles(const QString &srcDir) {
    QDir        dir(srcDir);
    QStringList filters;
    filters << "*.c" << "*.cpp";
    return dir.entryList(filters, QDir::Files);
}

static void writeCmakeFile(
    const QString &hostSrcDir, const QString &containerIncludeDir, const QString &containerLibDir, char **err) {

    QStringList files = getSrcFiles(hostSrcDir);

    QString tplPath = hostSrcDir + "/CMakeLists.txt.tpl";
    QFile   tplFile(tplPath);
    QString cmakeTemplate;

    if (tplFile.exists() && tplFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&tplFile);
        QString     indentation;

        while (!in.atEnd()) {
            QString line = in.readLine();

            static QRegularExpression re("^(\\s*)@SOURCES@");
            QRegularExpressionMatch   match = re.match(line);

            if (match.hasMatch()) {
                indentation = match.captured(1);

                QString sourcesBlock;
                for (int i = 0; i < files.size(); ++i) {
                    sourcesBlock += indentation + files.at(i);
                    if (i < files.size() - 1) {
                        sourcesBlock += "\n";
                    }
                }
                line.replace("@SOURCES@", sourcesBlock);
            }
            line.replace("@INCLUDE_DIR@", containerIncludeDir);
            line.replace("@LIB_DIR@", containerLibDir);
            cmakeTemplate += line + "\n";
        }
        tplFile.close();
    } else {
        QString sourcesBlock = "";
        for (const QString &file : files) {
            sourcesBlock += "    " + file + "\n";
        }

        // clang-format off
        cmakeTemplate = "cmake_minimum_required(VERSION 3.16)\n"
                        "project(twnmods VERSION 1.0 LANGUAGES C CXX)\n"
                        "find_package(Qt6 REQUIRED COMPONENTS Concurrent Core Multimedia Qml Svg)\n"
                        "qt_standard_project_setup(REQUIRES 6.5)\n"
                        "set(CMAKE_C_STANDARD 23)\n"
                        "set(CMAKE_CXX_STANDARD 17)\n"
                        "set(CMAKE_CXX_STANDARD_REQUIRED ON)\n"
                        "qt_add_qml_module(${PROJECT_NAME}\n"
                        "    URI ${PROJECT_NAME}\n"
                        "    VERSION 1.0\n"
                        "    SOURCES\n" +
                        sourcesBlock +
                        "    NO_GENERATE_EXTRA_QMLDIRS\n"
                        ")\n"
                        "target_compile_definitions(${PROJECT_NAME} PRIVATE\n"
                        "    \"$<$<STREQUAL:${CMAKE_SYSTEM_NAME},Windows>:TW_EXPORT=__declspec(dllexport)>\"\n"
                        "    \"$<$<NOT:$<STREQUAL:${CMAKE_SYSTEM_NAME},Windows>>:TW_EXPORT=__attribute__((visibility(\\\"default\\\")))>\"\n"
                        ")\n"
                        "target_include_directories(${PROJECT_NAME} PRIVATE " + containerIncludeDir + ")\n"
                        "target_link_libraries(${PROJECT_NAME} PRIVATE\n"
                        "    Qt6::Concurrent\n"
                        "    Qt6::Core\n"
                        "    Qt6::Multimedia\n"
                        "    Qt6::Svg\n"
                        ")\n"
                        "target_link_directories(${PROJECT_NAME} PRIVATE\n"
                        "    \"$<$<STREQUAL:${CMAKE_SYSTEM_NAME},Windows>:" + containerLibDir + ">\"\n"
                        ")\n"
                        "target_link_libraries(${PROJECT_NAME} PRIVATE\n"
                        "    \"$<$<STREQUAL:${CMAKE_SYSTEM_NAME},Windows>:tagwarp>\"\n"
                        ")\n";
        // clang-format on
    }

    QByteArray cmakeContent(cmakeTemplate.toUtf8());

    QFile cmakeFile(hostSrcDir + "/CMakeLists.txt");
    bool  needsWrite = true;
    if (cmakeFile.exists()) {
        if (cmakeFile.open(QIODevice::ReadOnly)) {
            QByteArray currentContent = cmakeFile.readAll();
            needsWrite                = currentContent != cmakeContent;
            cmakeFile.close();
        }
    }

    if (needsWrite) {
        EB_ERR_GF(cmakeFile.open(QIODevice::WriteOnly), "Failed to open mods CMakeFile.txt for writing");
        EB_ERR_GF(cmakeFile.write(cmakeContent) == cmakeContent.size(), "Failed to write mods CMakeFile.txt");
    }

fail:;
}

struct TWModsBuildResult {
    QString output;
    QString error;
    bool    success;
};

/*!
    \class TWModsBuilder
    \brief Internal struct to store the state of the mods builder.
*/
struct TWModsBuilder {
    QString cachedModsDir;
    QString builtTWNModsDir; // Empty means no nmods to load.

    QString builderDir;
    QString srcDir;
    QString includeDir;
    QString libDir;

    QProcess bgProc;
    QString  containerName;

    QFuture<TWModsBuildResult> result;
};

static void copyPath(const QString &path, char buffer[PATH_MAX], char **err) {
    QByteArray pathAsUtf8(path.toUtf8());
    size_t     copySize = pathAsUtf8.size();
    EB_ERR_GF(copySize < PATH_MAX, "Dir path is too long");
    memcpy(buffer, pathAsUtf8.constData(), copySize);
    buffer[copySize] = '\0';
fail:;
}

static void copyOutput(const QString &output, char buffer[TW_MAX_MOD_BUILD_OUTPUT_LEN], char **err) {
    QByteArray outputAsUtf8(output.toUtf8());
    size_t     copySize = outputAsUtf8.size();
    EB_ERR_GF(copySize < TW_MAX_MOD_BUILD_OUTPUT_LEN, "Build output is too long");
    memcpy(buffer, outputAsUtf8.constData(), copySize);
    buffer[copySize] = '\0';
fail:;
}

#ifdef __cplusplus
extern "C" {
#endif

thread_local static char modsDirBuffer[PATH_MAX];

/*!
    \fn const char *twModsGetDir()
    \brief Returns the mods directory path from the configuration settings or the TW_MODS_DIR env var.

    The mods directory is the directory that may contain \e twnmods/ and \e twqmods/ directories with the source
    files for native mods and QML mods respectively.
*/
TW_EXPORT const char *twModsGetDir() {
    QSettings settings;
    if (!settings.value("mods/enabled", false).toBool()) {
        modsDirBuffer[0] = '\0';
        return modsDirBuffer;
    }

    QString modsDir;
    if (qEnvironmentVariableIsSet("TW_MODS_DIR")) {
        modsDir = qEnvironmentVariable("TW_MODS_DIR");
    } else {
        modsDir = settings.value("mods/dir", "").toString();
    }

    if (modsDir.isEmpty()) {
        modsDirBuffer[0] = '\0';
    } else {
        char *err = nullptr;
        copyPath(QDir(modsDir).canonicalPath(), modsDirBuffer, &err);
        if (err) {
            qWarning() << *err;
            modsDirBuffer[0] = '\0';
        }
    }

    return modsDirBuffer;
}

static QString adjustPathForDocker(const QString &path, char **err) {
    char *adjusted = tweAdjustPathForDocker(path.toUtf8(), err);
    if (!*err && adjusted) {
        QString result(QString::fromUtf8(adjusted));
        free(adjusted);
        return result;
    }
    return path;
}

/*!
    \fn TWModsBuilder *twModsBuilderCreate(char **err)
    \brief Starts a mods builder.

    May fail and set the \a err due to permission or memory errors.

    \sa twModsBuilderDestroy()
*/
TW_EXPORT TWModsBuilder *twModsBuilderCreate(char **err) {
    std::unique_ptr<TWModsBuilder> builder(std::make_unique<TWModsBuilder>());

    QString modsDir(twModsGetDir());
    if (modsDir.isEmpty()) {
        return nullptr;
    }

    builder->srcDir = modsDir + "/twnmods";
    if (!QDir(builder->srcDir).exists()) {
        return nullptr;
    }

    QString adjustedSrcDir;
    QString adjustedIncludeDir;
#ifdef _WIN32
    QString adjustedLibDir;
#endif
    QString     adjustedDstDir;
    QString     adjustedBuilderDir;
    QStringList args;

    QProcess *bgProc = &builder->bgProc;

    QString cacheDir(QStandardPaths::standardLocations(QStandardPaths::CacheLocation)[0]);
    builder->builderDir      = cacheDir + "/twnmodsbuilder";
    builder->cachedModsDir   = cacheDir + "/cachedmods";
    builder->builtTWNModsDir = builder->cachedModsDir + "/twnmods";

    builder->includeDir = builder->builderDir + "/include";
    builder->libDir     = builder->builderDir + "/lib";

    QString builderDir(builder->builderDir);
    QString srcDir(builder->srcDir);
    QString dstDir(builder->builtTWNModsDir);
    QString includeDir(builder->includeDir);
    QString libDir(builder->libDir);

    QDir incl(includeDir);
    EB_ERR_GF(incl.exists() || incl.mkpath("."), "Failed to create include directory");

#ifdef _WIN32
    {
        QDir lib(libDir);
        EB_ERR_GF(lib.exists() || lib.mkpath("."), "Failed to create output directory for the mods interface library");
    }
#endif

    // Make ourselves because Docker doesn't accept certain characters.
    EB_ERR_GF(
        QDir().mkpath(dstDir) && QDir(builderDir).mkpath("build") && QDir(builderDir).mkpath(".ccache"),
        "Failed to create build dirs for twnmods");

    adjustedSrcDir     = adjustPathForDocker(srcDir, err);
    adjustedIncludeDir = adjustPathForDocker(includeDir, err);
#ifdef _WIN32
    adjustedLibDir = adjustPathForDocker(libDir, err);
#endif
    adjustedDstDir     = adjustPathForDocker(dstDir, err);
    adjustedBuilderDir = adjustPathForDocker(builderDir, err);
    EB_GF(!*err);

    builder->containerName = QString("tw-mods-%1").arg(QRandomGenerator::global()->generate(), 8, 16, QLatin1Char('0'));

    // Prefer not to use the -v syntax: it's averse to colons. Use the mount syntax that doesn't like commas.
    // clang-format off
    args << "run" << "--name" << builder->containerName << "-i" << "--rm" // The "-it" to auto-destroy even if we crash.
         << "--mount" << QString("type=bind,src=%1,dst=/twws/include").arg(adjustedIncludeDir)
#ifdef _WIN32
         << "--mount" << QString("type=bind,src=%1,dst=/twws/lib").arg(adjustedLibDir)
#endif
         << "--mount" << QString("type=bind,src=%1,dst=/twws/twnmods").arg(adjustedSrcDir)
         << "--mount" << QString("type=bind,src=%1,dst=/twws/dst").arg(adjustedDstDir)
         << "--mount" << QString("type=bind,src=%1/build,dst=/twws/build").arg(adjustedBuilderDir)
         << "--mount" << QString("type=bind,src=%1/.ccache,dst=/root/.ccache").arg(adjustedBuilderDir)
         << "crossetta/crossetta:" TW_PLATFORM "-" TW_QT_VERSION "-latest"
         << "cat";
    // clang-format on

    bgProc->start(TW_DOCKER, args);

    EB_ERR_GF(bgProc->waitForStarted(-1), "Failed mod builder start: %s", bgProc->errorString().toUtf8().constData());

fail:
    return !*err ? builder.release() : (builder.reset(), nullptr);
}

static QDateTime calcLatestInputModifiedTime(const QString &srcDir, const QString &includeDir, const QString &libDir) {
    QDateTime latestInputModifiedTime;

    auto assignMaxLatestInputModifiedTime = [&latestInputModifiedTime](const QString &filePath) {
        QFileInfo fi(filePath);
        if (fi.exists()) {
            QDateTime mtime = fi.lastModified();
            if (!latestInputModifiedTime.isValid() || mtime > latestInputModifiedTime) {
                latestInputModifiedTime = mtime;
            }
        }
    };

    QStringList files = getSrcFiles(srcDir);
    QDir        srcQDir(srcDir);
    for (const QString &file : files) {
        assignMaxLatestInputModifiedTime(srcQDir.filePath(file));
    }

    QDir dir(includeDir);
    dir.entryList(QStringList(), QDir::Files);
    for (const QString &file : dir.entryList(QStringList(), QDir::Files)) {
        assignMaxLatestInputModifiedTime(dir.filePath(file));
    }

#ifdef _WIN32
    assignMaxLatestInputModifiedTime(QDir(libDir).filePath(TW_ILIB));
#endif

    return latestInputModifiedTime;
}

static bool wasDebug(const QString &builderDir) {
    QString cmakeCache(builderDir + "/build/twnmods/CMakeCache.txt");
    QFile   file(cmakeCache);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();

        if (line.isEmpty() || line.startsWith("#") || line.startsWith("//")) {
            continue;
        }

        if (line.startsWith("CMAKE_BUILD_TYPE")) {
            int equalsIdx = line.indexOf('=');
            if (equalsIdx != -1) {
                QString value = line.mid(equalsIdx + 1).trimmed();
                return value.compare("Debug", Qt::CaseInsensitive) == 0;
            }
        }
    }

    return false;
}

static bool
upToDate(const QString &srcDir, const QString &includeDir, const QString &libDir, const QString &builtTWNModsDir) {
    QStringList outputFiles;
    outputFiles.push_back(builtTWNModsDir + "/qmldir");
    outputFiles.push_back(builtTWNModsDir + "/" TW_MOD_LIB);
    outputFiles.push_back(builtTWNModsDir + "/" TW_MOD_PLUGIN);

    QDateTime latestInputModifiedTime;

    for (const QString &outFile : outputFiles) {
        QFileInfo outFi(outFile);

        if (!outFi.exists()) {
            return false;
        }

        if (!latestInputModifiedTime.isValid()) {
            latestInputModifiedTime = calcLatestInputModifiedTime(srcDir, includeDir, libDir);
            if (!latestInputModifiedTime.isValid()) {
                return false;
            }
        }

        if (outFi.lastModified() <= latestInputModifiedTime) {
            return false;
        }
    }

    return true;
}

static void buildCopyForCurrentPlatform(TWModsBuilder *builder, char **err) {
    QString builderDir(builder->builderDir);
    QString srcDir(builder->srcDir);
    QString dstDir(builder->builtTWNModsDir);
    QString includeDir(builder->includeDir);
    QString libDir(builder->libDir);

    QString containerName(builder->containerName);

    bool isDebug          = QSettings().value("mods/debug", false).toBool();
    bool buildTypeChanged = wasDebug(builderDir) != isDebug;

    bool headersRemoved = tweExportsWriteHeaders(includeDir.toUtf8().constData(), err);
    EB_GF(!*err);

#ifdef _WIN32
    tweExportsWriteILib((libDir + "/" TW_ILIB).toUtf8().constData(), err);
    EB_GF(!*err);
#endif

    writeCmakeFile(srcDir, "/twws/include", "/twws/lib", err);
    EB_GF(!*err);

    if (!buildTypeChanged && !headersRemoved && upToDate(srcDir, includeDir, libDir, builder->builtTWNModsDir)) {
        qInfo() << "Cached twnmods are up to date.";
        return;
    }

    builder->result = QtConcurrent::run([containerName, isDebug]() -> TWModsBuildResult {
        QStringList args;

        // Prefer not to use the -v syntax: it's averse to colons. Use the mount syntax that doesn't like commas.
        // clang-format off
        args << "exec" << containerName << "sh" << "-c" << QString("cmake %1 -G Ninja -S /twws/twnmods -B /twws/build/twnmods"
#ifdef _WIN32
            " -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/include/ -DCMAKE_SYSTEM_NAME=Windows"
#endif
            " && cmake --build /twws/build/twnmods --parallel"
            " && rm -f /twws/dst/libtwnmods.so /twws/dst/libtwnmodsplugin.so" // It'll crash if the same inode is used.
            " && cp -t /twws/dst /twws/build/twnmods/qmldir "
            "/twws/build/twnmods/" TW_MOD_LIB " /twws/build/twnmods/" TW_MOD_PLUGIN
            )
            .arg(isDebug ? "-DCMAKE_BUILD_TYPE=Debug" : "-DCMAKE_BUILD_TYPE=Release");
        // clang-format on

        // Wait for the container to exist and be running.
        bool containerReady = false;
        int  maxRetries     = 100; // 5 seconds timeout

        while (maxRetries-- > 0) {
            QProcess    inspectProc;
            QStringList inspectArgs;
            inspectArgs << "inspect"
                        << "-f" << "{{.State.Running}}" << containerName;

            inspectProc.start(TW_DOCKER, inspectArgs);

            inspectProc.waitForFinished();

            if (inspectProc.exitStatus() == QProcess::NormalExit && inspectProc.exitCode() == 0) {
                QString output = inspectProc.readAllStandardOutput().trimmed();
                if (output == "true") {
                    containerReady = true;
                    break;
                }
            }
            QThread::msleep(50);
        }

        if (!containerReady) {
            qWarning() << "Mods build container did not become ready in time.";
            return TWModsBuildResult{};
        }

        QProcess proc;

        proc.start(TW_DOCKER, args);

        bool complete = proc.waitForFinished(-1);

        return TWModsBuildResult{
            .output  = proc.readAllStandardOutput() + proc.readAllStandardError(),
            .error   = complete ? "" : proc.errorString(),
            .success = complete && proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0,
        };
    });

fail:;
}

/*!
    \fn void twModsBuilderBuild(TWModsBuilder *builder, char **err)
    \brief Starts building mods using the \a builder.

    May fail and set the \a err due to permission or memory errors.

    \sa twModsBuilderWaitResult()
*/
TW_EXPORT void twModsBuilderBuild(TWModsBuilder *builder, char **err) {
    if (!builder) {
        return;
    }
    qInfo() << "Building twnmods...";
    buildCopyForCurrentPlatform(builder, err);
}

thread_local static char cachedModsDirBuffer[PATH_MAX];
thread_local static char builtTWNModsDirBuffer[PATH_MAX];
thread_local static char outputBuffer[TW_MAX_MOD_BUILD_OUTPUT_LEN];

/*!
    \fn void twModsBuilderWaitResult(TWModsBuilder *builder, const char **cachedModsDir, const char **builtTWNModsDir,
   const char **output, char **err)
    \brief Waits for the mods builder \a builder to finish building.

    May fail and set the \a err. Failing to build also sets the \a err.

    The \a output is set to something even in the case of any error. The build log is copied into the \a output.

    Sets \a cachedModsDir - the path that the main application will add to QQmlEngine::importPathList to load the mod
    as a QML module.

    Sets \a builtTWNModsDir. The \a builtTWNModsDir is normally a directory inside the \a cachedModsDir.

    The \a builtTWNModsDir contains the built mod's loadable library that the main application will load as a dynamic
   library and will import known functions from it (functions like this one).
*/
TW_EXPORT void twModsBuilderWaitResult(
    TWModsBuilder *builder, const char **cachedModsDir, const char **builtTWNModsDir, const char **output, char **err) {

    *cachedModsDir   = "";
    *builtTWNModsDir = "";
    *output          = "";

    if (!builder) {
        return;
    }

    TWModsBuildResult result;

    copyPath(builder->cachedModsDir, cachedModsDirBuffer, err);
    EB_GF(!*err);
    copyPath(builder->builtTWNModsDir, builtTWNModsDirBuffer, err);
    EB_GF(!*err);

    *cachedModsDir   = cachedModsDirBuffer;
    *builtTWNModsDir = builtTWNModsDirBuffer;

    if (!builder->result.isValid()) { // There was no build because of the mtime comparison.
        outputBuffer[0] = '\0';
        *output         = outputBuffer;
        qInfo() << "No build needed for twnmods.";
        return;
    }

    result = builder->result.takeResult();
    copyOutput(result.output, outputBuffer, err);
    EB_GF(!*err);
    *output = outputBuffer;

    EB_ERR_GF(result.error.isEmpty(), "Failed to build twnmods: %s", result.error.toUtf8().constData());
    EB_ERR_GF(result.success, "Failed to build twnmods");

    if (!*err) {
        qInfo().noquote() << result.output;
        qInfo() << "Built twnmods.";
    } else {
        qWarning().noquote() << result.output;
        qWarning() << "Failed to build twnmods";
    }

fail:;
}

/*!
    \fn void twModsBuilderDestroy(TWModsBuilder *builder)
    \brief Stops the mods builder \a builder.
*/
TW_EXPORT void twModsBuilderDestroy(TWModsBuilder *builder) {
    std::unique_ptr<TWModsBuilder> builderPtr(builder);
}

#ifdef __cplusplus
}
#endif
