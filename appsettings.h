#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <QFile>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int windowX READ windowX WRITE setWindowX NOTIFY changed)
    Q_PROPERTY(int windowY READ windowY WRITE setWindowY NOTIFY changed)
    Q_PROPERTY(int windowW READ windowW WRITE setWindowW NOTIFY changed)
    Q_PROPERTY(int windowH READ windowH WRITE setWindowH NOTIFY changed)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY changed)
    Q_PROPERTY(int cellHeight READ cellHeight WRITE setCellHeight NOTIFY changed)
    Q_PROPERTY(QString lastProjectPath READ lastProjectPath WRITE setLastProjectPath NOTIFY changed)

public:
    explicit AppSettings(QObject *parent = nullptr) : QObject(parent) {
        m_filePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(m_filePath);
        m_filePath += "/flightpicker_settings.json";
    }

    int windowX() const { return m_winX; }
    int windowY() const { return m_winY; }
    int windowW() const { return m_winW; }
    int windowH() const { return m_winH; }
    bool darkMode() const { return m_darkMode; }
    int cellHeight() const { return m_cellHeight; }
    QString lastProjectPath() const { return m_lastProjectPath; }

    void setWindowX(int v) { if (m_winX != v) { m_winX = v; emit changed(); } }
    void setWindowY(int v) { if (m_winY != v) { m_winY = v; emit changed(); } }
    void setWindowW(int v) { if (m_winW != v) { m_winW = v; emit changed(); } }
    void setWindowH(int v) { if (m_winH != v) { m_winH = v; emit changed(); } }
    void setDarkMode(bool v) { if (m_darkMode != v) { m_darkMode = v; emit changed(); } }
    void setCellHeight(int v) { if (m_cellHeight != v) { m_cellHeight = v; emit changed(); } }
    void setLastProjectPath(const QString &v) { if (m_lastProjectPath != v) { m_lastProjectPath = v; emit changed(); } }

    Q_INVOKABLE void load() {
        QFile f(m_filePath);
        if (!f.open(QIODevice::ReadOnly)) return;
        QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
        f.close();

        m_winX = o.value("windowX").toInt(100);
        m_winY = o.value("windowY").toInt(100);
        m_winW = o.value("windowW").toInt(1400);
        m_winH = o.value("windowH").toInt(900);
        m_darkMode = o.value("darkMode").toBool(true);
        m_cellHeight = o.value("cellHeight").toInt(110);
        m_lastProjectPath = o.value("lastProjectPath").toString();

        emit changed();
    }

    Q_INVOKABLE void save() {
        QJsonObject o;
        o["windowX"] = m_winX;
        o["windowY"] = m_winY;
        o["windowW"] = m_winW;
        o["windowH"] = m_winH;
        o["darkMode"] = m_darkMode;
        o["cellHeight"] = m_cellHeight;
        o["lastProjectPath"] = m_lastProjectPath;

        QFile f(m_filePath);
        if (!f.open(QIODevice::WriteOnly)) return;
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
        f.close();
    }

    Q_INVOKABLE QString filePath() const { return m_filePath; }

signals:
    void changed();

private:
    QString m_filePath;
    int m_winX = 100, m_winY = 100, m_winW = 1400, m_winH = 900;
    bool m_darkMode = true;
    int m_cellHeight = 110;
    QString m_lastProjectPath;
};

#endif // APPSETTINGS_H
