QT += core gui qml quick quickcontrols2 dbus network webenginequick

CONFIG += c++17 release
TARGET = flaircode
TEMPLATE = app

HEADERS += \
    src/ai.h \
    src/assistant.h \
    src/colorscheme.h \
    src/settings.h \
    src/snippets.h \
    src/document.h \
    src/highlighter.h \
    src/theme.h \
    src/workspace.h

SOURCES += \
    src/main.cpp \
    src/ai.cpp \
    src/assistant.cpp \
    src/colorscheme.cpp \
    src/settings.cpp \
    src/snippets.cpp \
    src/document.cpp \
    src/highlighter.cpp \
    src/theme.cpp \
    src/workspace.cpp

RESOURCES += src/resources.qrc
