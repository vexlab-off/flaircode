QT += core gui qml quick quickcontrols2 dbus

CONFIG += c++17 release
TARGET = flaircode
TEMPLATE = app

HEADERS += \
    src/document.h \
    src/highlighter.h \
    src/theme.h \
    src/workspace.h

SOURCES += \
    src/main.cpp \
    src/document.cpp \
    src/highlighter.cpp \
    src/theme.cpp \
    src/workspace.cpp

RESOURCES += src/resources.qrc
