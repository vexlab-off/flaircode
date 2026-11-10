QT += core gui quick quickcontrols2 dbus network testlib
CONFIG += c++17 testcase
TARGET = flaircode_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/ai.h ../src/assistant.h ../src/colorscheme.h ../src/settings.h ../src/snippets.h ../src/document.h ../src/highlighter.h ../src/theme.h ../src/workspace.h
SOURCES += flaircode_tests.cpp ../src/ai.cpp ../src/assistant.cpp ../src/colorscheme.cpp ../src/settings.cpp ../src/snippets.cpp ../src/document.cpp ../src/highlighter.cpp ../src/theme.cpp ../src/workspace.cpp
