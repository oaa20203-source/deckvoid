TEMPLATE = app
TARGET = tst_bitratepolicy
QT = core testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
INCLUDEPATH += $$PWD/../../app
SOURCES += $$PWD/tst_bitratepolicy.cpp $$PWD/../../app/streaming/bitratepolicy.cpp
HEADERS += $$PWD/../../app/streaming/bitratepolicy.h
