TEMPLATE = app
TARGET = tst_apollo
QT = core network testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
INCLUDEPATH += $$PWD/../../app
SOURCES += $$PWD/tst_apollo.cpp $$PWD/../../app/backend/nvapp.cpp
HEADERS += \
    $$PWD/../../app/backend/apollo/apollohostinfo.h \
    $$PWD/../../app/backend/apollo/apollopermissions.h \
    $$PWD/../../app/backend/apollo/apollolaunchverb.h \
    $$PWD/../../app/backend/apollo/apollolaunchoptions.h \
    $$PWD/../../app/backend/apollo/apollootp.h \
    $$PWD/../../app/backend/apollo/apolloclipboardsync.h \
    $$PWD/../../app/backend/applistparser.h \
    $$PWD/../../app/backend/nvapp.h
