TEMPLATE = app
TARGET = tst_inputmode
QT = core testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
INCLUDEPATH += $$PWD/../../app
SOURCES += $$PWD/tst_inputmode.cpp
HEADERS += $$PWD/../../app/gui/inputmodepolicy.h
