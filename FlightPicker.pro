QT += quick quickcontrols2 widgets
CONFIG += c++17

HEADERS += appsettings.h projectdata.h
SOURCES += main.cpp
RESOURCES += qml.qrc

CONFIG(debug, debug|release) {
    DEFINES += QML_SOURCE_DIR=\\\"$$PWD\\\"
}

qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
