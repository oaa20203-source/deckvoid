TEMPLATE = app
TARGET = tst_apollo
QT = core testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
INCLUDEPATH += $$PWD/../../app
SOURCES += $$PWD/tst_apollo.cpp
HEADERS += \
    $$PWD/../../app/backend/apollo/apollohostinfo.h \
    $$PWD/../../app/backend/apollo/apollopermissions.h
