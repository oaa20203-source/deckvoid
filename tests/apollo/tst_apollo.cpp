// Apollo /serverinfo extensions as emitted by Vibepollo 2.0.6 (src/nvhttp.cpp:4216-4446).
#include <QtTest>

#include "backend/apollo/apollohostinfo.h"
#include "backend/apollo/apollopermissions.h"

namespace {

// Paired HTTPS response from a Windows Vibepollo host whose client has the
// default permissions plus launch and server commands.
const char* kPairedApollo =
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<root status_code=\"200\">"
    "<hostname>GAMING-PC</hostname>"
    "<appversion>7.1.431.-1</appversion>"
    "<PairStatus>1</PairStatus>"
    "<currentgame>3</currentgame>"
    "<currentgameuuid>A1B2C3D4-0000-4000-8000-000000000003</currentgameuuid>"
    "<VirtualDisplayCapable>true</VirtualDisplayCapable>"
    "<VirtualDisplayDriverReady>false</VirtualDisplayDriverReady>"
    "<VirtualDisplayHDRCapable>true</VirtualDisplayHDRCapable>"
    "<mac>aa:bb:cc:dd:ee:ff</mac>"
    "<ServerCommand>Restart Steam</ServerCommand>"
    "<ServerCommand>Sleep monitor</ServerCommand>"
    "<ServerCommand></ServerCommand>"
    "<Permission>118489088</Permission>"
    "</root>";

// The same host answering an unpaired client over plain HTTP.
const char* kUnpairedApollo =
    "<root status_code=\"200\">"
    "<appversion>7.1.431.-1</appversion>"
    "<PairStatus>0</PairStatus>"
    "<currentgame>0</currentgame>"
    "<currentgameuuid></currentgameuuid>"
    "<VirtualDisplayCapable>true</VirtualDisplayCapable>"
    "<VirtualDisplayDriverReady>true</VirtualDisplayDriverReady>"
    "<VirtualDisplayHDRCapable>true</VirtualDisplayHDRCapable>"
    "<mac>00:00:00:00:00:00</mac>"
    "<Permission>0</Permission>"
    "</root>";

// Stock Sunshine: none of the Apollo tags.
const char* kSunshine =
    "<root status_code=\"200\">"
    "<appversion>7.1.431.-1</appversion>"
    "<PairStatus>1</PairStatus>"
    "<currentgame>0</currentgame>"
    "</root>";

} // namespace

class TestApollo : public QObject
{
    Q_OBJECT

private slots:
    void pairedApolloHost()
    {
        const auto info = ApolloHostInfo::fromServerInfo(kPairedApollo);
        QVERIFY(info.detected);
        QVERIFY(info.permissionsKnown);
        QCOMPARE(info.permissions, 118489088u); // list|view|launch|server_cmd = 0x7100000
        QCOMPARE(info.serverCommands, QStringList({"Restart Steam", "Sleep monitor", ""}));
        QVERIFY(info.virtualDisplayCapable);
        QVERIFY(!info.virtualDisplayDriverReady);
        QVERIFY(info.virtualDisplayHdrCapable);
        QCOMPARE(info.currentGameUuid, QString("A1B2C3D4-0000-4000-8000-000000000003"));
    }

    void serverCommandIndexIsListPosition()
    {
        // The host runs server_cmds[index]; an empty name still occupies its slot.
        const auto info = ApolloHostInfo::fromServerInfo(kPairedApollo);
        QCOMPARE(info.serverCommands.indexOf("Sleep monitor"), 1);
        QCOMPARE(info.serverCommands.size(), 3);
    }

    void unpairedHttpHasUnknownPermissions()
    {
        const auto info = ApolloHostInfo::fromServerInfo(kUnpairedApollo);
        QVERIFY(info.detected);
        QVERIFY(!info.permissionsKnown);
        QCOMPARE(info.permissions, 0u);
        QVERIFY(info.serverCommands.isEmpty());
        QVERIFY(info.virtualDisplayDriverReady);
        QVERIFY(info.currentGameUuid.isEmpty());
    }

    void sunshineIsNotApollo()
    {
        const auto info = ApolloHostInfo::fromServerInfo(kSunshine);
        QVERIFY(!info.detected);
        QVERIFY(!info.permissionsKnown);
        QVERIFY(!info.virtualDisplayCapable);
    }

    void malformedXmlIsNotApollo()
    {
        const auto info = ApolloHostInfo::fromServerInfo("<root><VirtualDisplayCapable>true</root>");
        QVERIFY(!info.detected);
    }

    void booleanSpellings()
    {
        const auto info = ApolloHostInfo::fromServerInfo(
            "<root><VirtualDisplayCapable>1</VirtualDisplayCapable>"
            "<VirtualDisplayDriverReady>TRUE</VirtualDisplayDriverReady>"
            "<VirtualDisplayHDRCapable>0</VirtualDisplayHDRCapable></root>");
        QVERIFY(info.detected);
        QVERIFY(info.virtualDisplayCapable);
        QVERIFY(info.virtualDisplayDriverReady);
        QVERIFY(!info.virtualDisplayHdrCapable);
    }

    void permissionBits()
    {
        using namespace ApolloPermissions;
        QCOMPARE(uint32_t(ClipboardSet), 0x10000u);
        QCOMPARE(uint32_t(ClipboardRead), 0x20000u);
        QCOMPARE(uint32_t(ServerCommand), 0x100000u);
        QCOMPARE(uint32_t(List), 0x1000000u);
        QCOMPARE(uint32_t(View), 0x2000000u);
        QCOMPARE(uint32_t(Launch), 0x4000000u);
        QVERIFY(has(118489088u, ServerCommand));
        QVERIFY(has(118489088u, Launch));
        QVERIFY(!has(118489088u, ClipboardRead));
    }

    void permissionNamesInBitOrder()
    {
        using namespace ApolloPermissions;
        QCOMPARE(names(118489088u),
                 QStringList({"Run server commands", "List applications", "View streams", "Launch applications"}));
        QCOMPARE(names(InputController | InputKeyboard | ClipboardSet),
                 QStringList({"Controller input", "Keyboard input", "Set clipboard"}));
        QVERIFY(names(0).isEmpty());
        // Unknown bits are ignored rather than shown as garbage.
        QCOMPARE(names(0x1u | List), QStringList({"List applications"}));
    }
};

QTEST_GUILESS_MAIN(TestApollo)
#include "tst_apollo.moc"
