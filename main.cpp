#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include "appsettings.h"
#include "projectdata.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("FlightPicker");
    app.setOrganizationName("FlightPicker");
    app.setApplicationVersion("1.0");

    // ── Command line ────────────────────────────────────────────
    QCommandLineParser parser;
    parser.setApplicationDescription("Flight Segment Picker");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption projectOpt(
        QStringList() << "p" << "project",
        "Load a project file (.flp) on startup.",
        "file"
    );
    parser.addOption(projectOpt);
    parser.process(app);

    // ── Settings (UI prefs, always in AppData) ──────────────────
    AppSettings settings;
    settings.load();

    // ── Project data (flights, user-managed file) ───────────────
    ProjectData project;

    // Determine which project file to load:
    // 1. --project CLI argument takes priority
    // 2. Otherwise, reopen last project (from settings)
    QString projectPath;
    if (parser.isSet(projectOpt)) {
        projectPath = parser.value(projectOpt);
    } else if (!settings.lastProjectPath().isEmpty()) {
        projectPath = settings.lastProjectPath();
    }

    if (!projectPath.isEmpty() && QFileInfo::exists(projectPath)) {
        project.loadFromFile(projectPath);
        settings.setLastProjectPath(projectPath);
    }

    // ── QML engine ──────────────────────────────────────────────
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appSettings", &settings);
    engine.rootContext()->setContextProperty("project", &project);

    // Track file path changes to update lastProjectPath in settings
    QObject::connect(&project, &ProjectData::filePathChanged, [&]() {
        if (!project.currentFilePath().isEmpty()) {
            settings.setLastProjectPath(project.currentFilePath());
            settings.save();
        }
    });

#ifdef QT_DEBUG
    QString qmlDir;
#ifdef QML_SOURCE_DIR
    qmlDir = QStringLiteral(QML_SOURCE_DIR);
#endif
    if (qmlDir.isEmpty() || !QFileInfo::exists(qmlDir + "/main.qml")) {
        QDir buildDir(QCoreApplication::applicationDirPath());
        QStringList searchPaths = {
            buildDir.absolutePath(),
            buildDir.absoluteFilePath(".."),
            buildDir.absoluteFilePath("../.."),
            buildDir.absoluteFilePath("../../.."),
        };
        for (const auto &path : searchPaths) {
            if (QFileInfo::exists(path + "/main.qml")) { qmlDir = path; break; }
        }
    }
    if (!qmlDir.isEmpty() && QFileInfo::exists(qmlDir + "/main.qml")) {
        engine.addImportPath(qmlDir);
        QUrl url = QUrl::fromLocalFile(qmlDir + "/main.qml");
        qDebug() << "Loading QML from source:" << url;
        engine.load(url);
    } else {
        engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
    }
#else
    engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
#endif

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
