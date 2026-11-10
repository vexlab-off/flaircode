QT += core gui quick quickcontrols2 dbus testlib
CONFIG += c++17 testcase
TARGET = flaircode_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/document.h ../src/highlighter.h ../src/theme.h ../src/workspace.h
SOURCES += flaircode_tests.cpp ../src/document.cpp ../src/highlighter.cpp ../src/theme.cpp ../src/workspace.cpp
