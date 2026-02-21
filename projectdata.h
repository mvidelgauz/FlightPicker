#ifndef PROJECTDATA_H
#define PROJECTDATA_H

#include <QObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileDialog>
#include <QVariantList>

class ProjectData : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList airlines READ airlines WRITE setAirlines NOTIFY dataChanged)
    Q_PROPERTY(QVariantList aircraft READ aircraft WRITE setAircraft NOTIFY dataChanged)
    Q_PROPERTY(QVariantList seg1 READ seg1 WRITE setSeg1 NOTIFY dataChanged)
    Q_PROPERTY(QVariantList seg2 READ seg2 WRITE setSeg2 NOTIFY dataChanged)
    Q_PROPERTY(QVariantList seg3 READ seg3 WRITE setSeg3 NOTIFY dataChanged)
    Q_PROPERTY(QVariantList seg4 READ seg4 WRITE setSeg4 NOTIFY dataChanged)
    Q_PROPERTY(QString currentFilePath READ currentFilePath NOTIFY filePathChanged)
    Q_PROPERTY(QString currentFileName READ currentFileName NOTIFY filePathChanged)
    Q_PROPERTY(bool dirty READ dirty WRITE setDirty NOTIFY dirtyChanged)

public:
    explicit ProjectData(QObject *parent = nullptr) : QObject(parent) {}

    // ── Getters ─────────────────────────────────────────────────
    QVariantList airlines() const { return m_airlines; }
    QVariantList aircraft() const { return m_aircraft; }
    QVariantList seg1() const { return m_seg1; }
    QVariantList seg2() const { return m_seg2; }
    QVariantList seg3() const { return m_seg3; }
    QVariantList seg4() const { return m_seg4; }
    QString currentFilePath() const { return m_filePath; }
    bool dirty() const { return m_dirty; }

    QString currentFileName() const {
        if (m_filePath.isEmpty()) return "Untitled";
        return QFileInfo(m_filePath).fileName();
    }

    // ── Setters ─────────────────────────────────────────────────
    void setAirlines(const QVariantList &v) { m_airlines = v; markDirty(); emit dataChanged(); }
    void setAircraft(const QVariantList &v) { m_aircraft = v; markDirty(); emit dataChanged(); }
    void setSeg1(const QVariantList &v) { m_seg1 = v; markDirty(); emit dataChanged(); }
    void setSeg2(const QVariantList &v) { m_seg2 = v; markDirty(); emit dataChanged(); }
    void setSeg3(const QVariantList &v) { m_seg3 = v; markDirty(); emit dataChanged(); }
    void setSeg4(const QVariantList &v) { m_seg4 = v; markDirty(); emit dataChanged(); }
    void setDirty(bool v) { if (m_dirty != v) { m_dirty = v; emit dirtyChanged(); } }

    // ── File operations (callable from QML) ─────────────────────

    // Create a new empty project
    Q_INVOKABLE void newProject() {
        m_airlines.clear();
        m_aircraft.clear();
        m_seg1.clear(); m_seg2.clear(); m_seg3.clear(); m_seg4.clear();
        m_filePath.clear();
        m_dirty = false;
        emit dataChanged();
        emit filePathChanged();
        emit dirtyChanged();
    }

    // Load a project from a specific file path
    // Returns true on success, false on failure
    Q_INVOKABLE bool loadFromFile(const QString &path) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) return false;
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        f.close();
        if (!doc.isObject()) return false;
        QJsonObject o = doc.object();

        m_airlines = o.value("airlines").toArray().toVariantList();
        m_aircraft = o.value("aircraft").toArray().toVariantList();
        m_seg1 = o.value("seg1").toArray().toVariantList();
        m_seg2 = o.value("seg2").toArray().toVariantList();
        m_seg3 = o.value("seg3").toArray().toVariantList();
        m_seg4 = o.value("seg4").toArray().toVariantList();

        m_filePath = path;
        m_dirty = false;
        emit dataChanged();
        emit filePathChanged();
        emit dirtyChanged();
        return true;
    }

    // Save to the current file path (must already have one)
    Q_INVOKABLE bool save() {
        if (m_filePath.isEmpty()) return false;
        return saveToFile(m_filePath);
    }

    // Save to a specific file path (Save As)
    Q_INVOKABLE bool saveToFile(const QString &path) {
        QJsonObject o;
        o["airlines"] = QJsonArray::fromVariantList(m_airlines);
        o["aircraft"] = QJsonArray::fromVariantList(m_aircraft);
        o["seg1"] = QJsonArray::fromVariantList(m_seg1);
        o["seg2"] = QJsonArray::fromVariantList(m_seg2);
        o["seg3"] = QJsonArray::fromVariantList(m_seg3);
        o["seg4"] = QJsonArray::fromVariantList(m_seg4);

        QFile f(path);
        if (!f.open(QIODevice::WriteOnly)) return false;
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
        f.close();

        m_filePath = path;
        m_dirty = false;
        emit filePathChanged();
        emit dirtyChanged();
        return true;
    }

    // Check if there is a current file to save to
    Q_INVOKABLE bool hasFile() const { return !m_filePath.isEmpty(); }

    // Get default directory for file dialogs
    Q_INVOKABLE QString defaultDir() const {
        if (!m_filePath.isEmpty()) return QFileInfo(m_filePath).absolutePath();
        return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    }

    // Show native Open dialog, load selected file. Returns true on success.
    Q_INVOKABLE bool openFileDialog() {
        QString path = QFileDialog::getOpenFileName(
            nullptr,
            "Open Project",
            defaultDir(),
            "Flight Picker projects (*.flp);;JSON files (*.json);;All files (*)"
        );
        if (path.isEmpty()) return false;
        return loadFromFile(path);
    }

    // Show native Save As dialog, save to selected file. Returns true on success.
    Q_INVOKABLE bool saveFileDialog() {
        QString startPath = defaultDir();
        if (!m_filePath.isEmpty())
            startPath = m_filePath;
        else
            startPath += "/Untitled.flp";

        QString path = QFileDialog::getSaveFileName(
            nullptr,
            "Save Project As",
            startPath,
            "Flight Picker projects (*.flp);;JSON files (*.json);;All files (*)"
        );
        if (path.isEmpty()) return false;
        return saveToFile(path);
    }

signals:
    void dataChanged();
    void filePathChanged();
    void dirtyChanged();

private:
    void markDirty() { if (!m_dirty) { m_dirty = true; emit dirtyChanged(); } }

    QString m_filePath;
    bool m_dirty = false;
    QVariantList m_airlines, m_aircraft;
    QVariantList m_seg1, m_seg2, m_seg3, m_seg4;
};

#endif // PROJECTDATA_H
