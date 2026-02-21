#ifndef APPSTATE_H
#define APPSTATE_H

#include <QObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

class AppState : public QObject
{
    Q_OBJECT
    // Window geometry
    Q_PROPERTY(int windowX READ windowX WRITE setWindowX NOTIFY changed)
    Q_PROPERTY(int windowY READ windowY WRITE setWindowY NOTIFY changed)
    Q_PROPERTY(int windowW READ windowW WRITE setWindowW NOTIFY changed)
    Q_PROPERTY(int windowH READ windowH WRITE setWindowH NOTIFY changed)
    // Theme
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY changed)
    // Dynamic lists
    Q_PROPERTY(QVariantList airlines READ airlines WRITE setAirlines NOTIFY changed)
    Q_PROPERTY(QVariantList aircraft READ aircraft WRITE setAircraft NOTIFY changed)
    // Flight data per segment (stored as arrays of objects)
    Q_PROPERTY(QVariantList seg1 READ seg1 WRITE setSeg1 NOTIFY changed)
    Q_PROPERTY(QVariantList seg2 READ seg2 WRITE setSeg2 NOTIFY changed)
    Q_PROPERTY(QVariantList seg3 READ seg3 WRITE setSeg3 NOTIFY changed)
    Q_PROPERTY(QVariantList seg4 READ seg4 WRITE setSeg4 NOTIFY changed)

public:
    explicit AppState(QObject *parent = nullptr) : QObject(parent) {
        m_filePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(m_filePath);
        m_filePath += "/flightpicker_state.json";
    }

    // Getters
    int windowX() const { return m_winX; }
    int windowY() const { return m_winY; }
    int windowW() const { return m_winW; }
    int windowH() const { return m_winH; }
    bool darkMode() const { return m_darkMode; }
    QVariantList airlines() const { return m_airlines; }
    QVariantList aircraft() const { return m_aircraft; }
    QVariantList seg1() const { return m_seg1; }
    QVariantList seg2() const { return m_seg2; }
    QVariantList seg3() const { return m_seg3; }
    QVariantList seg4() const { return m_seg4; }

    // Setters
    void setWindowX(int v) { if (m_winX != v) { m_winX = v; emit changed(); } }
    void setWindowY(int v) { if (m_winY != v) { m_winY = v; emit changed(); } }
    void setWindowW(int v) { if (m_winW != v) { m_winW = v; emit changed(); } }
    void setWindowH(int v) { if (m_winH != v) { m_winH = v; emit changed(); } }
    void setDarkMode(bool v) { if (m_darkMode != v) { m_darkMode = v; emit changed(); } }
    void setAirlines(const QVariantList &v) { m_airlines = v; emit changed(); }
    void setAircraft(const QVariantList &v) { m_aircraft = v; emit changed(); }
    void setSeg1(const QVariantList &v) { m_seg1 = v; emit changed(); }
    void setSeg2(const QVariantList &v) { m_seg2 = v; emit changed(); }
    void setSeg3(const QVariantList &v) { m_seg3 = v; emit changed(); }
    void setSeg4(const QVariantList &v) { m_seg4 = v; emit changed(); }

    Q_INVOKABLE void load() {
        QFile f(m_filePath);
        if (!f.open(QIODevice::ReadOnly)) return;
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        f.close();
        if (!doc.isObject()) return;
        QJsonObject o = doc.object();

        m_winX = o.value("windowX").toInt(100);
        m_winY = o.value("windowY").toInt(100);
        m_winW = o.value("windowW").toInt(1400);
        m_winH = o.value("windowH").toInt(900);
        m_darkMode = o.value("darkMode").toBool(true);

        m_airlines = o.value("airlines").toArray().toVariantList();
        m_aircraft = o.value("aircraft").toArray().toVariantList();
        m_seg1 = o.value("seg1").toArray().toVariantList();
        m_seg2 = o.value("seg2").toArray().toVariantList();
        m_seg3 = o.value("seg3").toArray().toVariantList();
        m_seg4 = o.value("seg4").toArray().toVariantList();

        emit changed();
    }

    Q_INVOKABLE void save() {
        QJsonObject o;
        o["windowX"] = m_winX;
        o["windowY"] = m_winY;
        o["windowW"] = m_winW;
        o["windowH"] = m_winH;
        o["darkMode"] = m_darkMode;
        o["airlines"] = QJsonArray::fromVariantList(m_airlines);
        o["aircraft"] = QJsonArray::fromVariantList(m_aircraft);
        o["seg1"] = QJsonArray::fromVariantList(m_seg1);
        o["seg2"] = QJsonArray::fromVariantList(m_seg2);
        o["seg3"] = QJsonArray::fromVariantList(m_seg3);
        o["seg4"] = QJsonArray::fromVariantList(m_seg4);

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
    QVariantList m_airlines, m_aircraft;
    QVariantList m_seg1, m_seg2, m_seg3, m_seg4;
};

#endif // APPSTATE_H
