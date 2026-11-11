// Apollo /serverinfo extensions as emitted by Vibepollo 2.0.6 (src/nvhttp.cpp:4216-4446).
#include <QtTest>

#include "backend/apollo/apollohostinfo.h"
#include "backend/apollo/apollopermissions.h"
#include "backend/applistparser.h"
#include "backend/apollo/apollolaunchverb.h"
#include "backend/apollo/apollolaunchoptions.h"
#include "backend/apollo/apollootp.h"
#include "backend/apollo/apolloclipboardsync.h"
#include "backend/apollo/apolloquickmenu.h"
#include "backend/inkupdater.h"
#include <QJsonDocument>
#include <QJsonObject>
#include "backend/nvapp.h"

#include <QSettings>
#include <QTemporaryDir>

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
    void updaterReadsReleaseVersion()
    {
        QCOMPARE(InkUpdater::versionFromReleaseTitle("Latest Steam Deck build (0.1.0-99685c8)"), QString("0.1.0-99685c8"));
        QCOMPARE(InkUpdater::versionFromReleaseTitle("Latest Steam Deck build (0.1.0-ee27f54) "), QString("0.1.0-ee27f54"));
        QVERIFY(InkUpdater::versionFromReleaseTitle("Latest Steam Deck build").isEmpty());
        QVERIFY(InkUpdater::versionFromReleaseTitle("").isEmpty());
    }
    void updaterReadsBundleDigest()
    {
        const QByteArray hex(64, 'a');
        const auto release = QJsonDocument::fromJson(
            "{\"assets\":[{\"name\":\"DeckVoid-x86_64.flatpak\",\"digest\":\"sha256:" + QByteArray(64, 'b') + "\"},"
            "{\"name\":\"ink-x86_64.flatpak\",\"digest\":\"sha256:" + hex.toUpper() + "\"}]}").object();
        QCOMPARE(InkUpdater::bundleSha256FromRelease(release), hex);
        // No digest, a malformed one, or no such asset: nothing to compare against
        QVERIFY(InkUpdater::bundleSha256FromRelease(QJsonDocument::fromJson(
            "{\"assets\":[{\"name\":\"ink-x86_64.flatpak\"}]}").object()).isEmpty());
        QVERIFY(InkUpdater::bundleSha256FromRelease(QJsonDocument::fromJson(
            "{\"assets\":[{\"name\":\"ink-x86_64.flatpak\",\"digest\":\"sha256:abc\"}]}").object()).isEmpty());
        QVERIFY(InkUpdater::bundleSha256FromRelease(QJsonObject()).isEmpty());
    }
    void updaterInstallsOnlyAMatchingBundle()
    {
        const QByteArray hex(64, 'a');
        QVERIFY(InkUpdater::bundleMatches(hex, hex));
        QVERIFY(InkUpdater::bundleMatches(hex, hex.toUpper()));
        QVERIFY(!InkUpdater::bundleMatches(hex, QByteArray(64, 'b')));
        QVERIFY(InkUpdater::bundleMatches(QByteArray(), hex));
    }
    void updaterOffersOnlyADifferentBuild()
    {
        QVERIFY(InkUpdater::isNewer("0.1.0-99685c8", "0.1.0-00cdcaf"));
        QVERIFY(!InkUpdater::isNewer("0.1.0-00cdcaf", "0.1.0-00cdcaf"));
        QVERIFY(!InkUpdater::isNewer("0.1.0-00cdcaf", ""));
        QVERIFY(!InkUpdater::isNewer("", "0.1.0-00cdcaf"));
    }
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
    void appListParsesApolloFields()
    {
        // Shape of Vibepollo's /applist (src/nvhttp.cpp:4745-4758).
        const auto apps = AppListParser::parse(
            "<root status_code=\"200\">"
            "<App><IsHdrSupported>1</IsHdrSupported><AppTitle>Desktop</AppTitle><UUID>11111111-0000-4000-8000-000000000001</UUID><IDX>0</IDX><ArtVersion>3</ArtVersion><ID>881448767</ID></App>"
            "<App><IsHdrSupported>0</IsHdrSupported><AppTitle>Steam Big Picture</AppTitle><UUID>22222222-0000-4000-8000-000000000002</UUID><IDX>1</IDX><ArtVersion>7</ArtVersion><ID>1093255277</ID></App>"
            "</root>");
        QCOMPARE(apps.size(), 2);
        QCOMPARE(apps[0].name, QString("Desktop"));
        QCOMPARE(apps[0].id, 881448767);
        QVERIFY(apps[0].hdrSupported);
        QCOMPARE(apps[0].uuid, QString("11111111-0000-4000-8000-000000000001"));
        QCOMPARE(apps[0].hostIndex, qint64(0));
        QCOMPARE(apps[0].artVersion, QString("3"));
        QCOMPARE(apps[1].hostIndex, qint64(1));
    }

    void appListWithoutApolloFields()
    {
        const auto apps = AppListParser::parse(
            "<root status_code=\"200\"><App><AppTitle>Steam</AppTitle><ID>5</ID><IsHdrSupported>0</IsHdrSupported></App></root>");
        QCOMPARE(apps.size(), 1);
        QVERIFY(apps[0].uuid.isEmpty());
        QCOMPARE(apps[0].hostIndex, qint64(-1));
        QVERIFY(apps[0].artVersion.isEmpty());
    }

    void appListRejectsAppWithoutId()
    {
        QVERIFY_THROWS_EXCEPTION(std::runtime_error,
            AppListParser::parse("<root><App><AppTitle>A</AppTitle></App><App><AppTitle>B</AppTitle><ID>2</ID></App></root>"));
    }

    void sortFollowsHostIndexWhenPresent()
    {
        QVector<NvApp> apps(5);
        apps[0].name = "Zelda";        apps[0].hostIndex = 0;
        apps[1].name = "Remote Input"; apps[1].hostIndex = 2147483506; // control tile: IDX is its ID
        apps[2].name = "Alpha";        apps[2].hostIndex = 2;
        apps[3].name = "Catalogue";    apps[3].hostIndex = -1;         // empty IDX: after all numbered
        apps[4].name = "Mario";        apps[4].hostIndex = 1;
        AppListParser::sort(apps);
        QStringList order;
        for (const auto& app : apps) order << app.name;
        QCOMPARE(order, QStringList({"Zelda", "Mario", "Alpha", "Remote Input", "Catalogue"}));
    }

    void idxParsing()
    {
        const auto apps = AppListParser::parse(
            "<root><App><AppTitle>A</AppTitle><ID>1</ID><IDX>2147483506</IDX></App>"
            "<App><AppTitle>B</AppTitle><ID>2</ID><IDX></IDX></App>"
            "<App><AppTitle>C</AppTitle><ID>3</ID><IDX>abc</IDX></App>"
            "<App><AppTitle>D</AppTitle><ID>4</ID><IDX>-3</IDX></App></root>");
        QCOMPARE(apps[0].hostIndex, qint64(2147483506));
        QCOMPARE(apps[1].hostIndex, qint64(-1));
        QCOMPARE(apps[2].hostIndex, qint64(-1));
        QCOMPARE(apps[3].hostIndex, qint64(-1));
    }

    void sortKeepsXmlOrderForTies()
    {
        QVector<NvApp> apps(3);
        apps[0].name = "B"; apps[0].hostIndex = -1;
        apps[1].name = "A"; apps[1].hostIndex = 0;
        apps[2].name = "C"; apps[2].hostIndex = -1;
        AppListParser::sort(apps);
        QCOMPARE(apps[0].name, QString("A"));
        QCOMPARE(apps[1].name, QString("B"));
        QCOMPARE(apps[2].name, QString("C"));
    }

    void permissionNoticeApp()
    {
        // Sent only when the client has none of list, view or launch (src/nvhttp.cpp:4762-4775).
        NvApp notice; notice.id = 114514;
        NvApp realAppSameId; realAppSameId.id = 114514; realAppSameId.uuid = "U";
        NvApp game; game.id = 5;
        QVERIFY(notice.isApolloPermissionNotice());
        QVERIFY(!realAppSameId.isApolloPermissionNotice());
        QVERIFY(!game.isApolloPermissionNotice());
    }

    void launchVerbStockHost()
    {
        using V = ApolloLaunchVerb::Verb;
        NvApp app; app.id = 5;
        QCOMPARE(ApolloLaunchVerb::choose(0, QString(), app), V::Launch);
        QCOMPARE(ApolloLaunchVerb::choose(5, QString(), app), V::Resume);
        QCOMPARE(ApolloLaunchVerb::choose(9, QString(), app), V::QuitThenLaunch);
    }

    void launchVerbByUuid()
    {
        using V = ApolloLaunchVerb::Verb;
        NvApp app; app.id = 5; app.uuid = "aaaa-1111";
        QCOMPARE(ApolloLaunchVerb::choose(5, "AAAA-1111", app), V::Resume);      // case-insensitive
        QCOMPARE(ApolloLaunchVerb::choose(5, "bbbb-2222", app), V::QuitThenLaunch); // UUID wins over ID
        QCOMPARE(ApolloLaunchVerb::choose(0, "aaaa-1111", app), V::Resume);
    }

    void launchVerbReplacesRemoteInput()
    {
        using V = ApolloLaunchVerb::Verb;
        NvApp app; app.id = 5; app.uuid = "aaaa-1111";
        // Remote Input running: launch the new app directly; the host replaces the input-only session.
        QCOMPARE(ApolloLaunchVerb::choose(77, "8cb5c136-da67-4f99-b4a1-f9cd35005cf4", app), V::Launch);
        QCOMPARE(ApolloLaunchVerb::choose(77, "9A1C5A25-58FE-40E0-B9AA-7D3F00000006", app), V::Launch);
        QVERIFY(ApolloLaunchVerb::isRemoteInput("8CB5C136-DA67-4F99-B4A1-F9CD35005CF4"));
        QVERIFY(!ApolloLaunchVerb::isRemoteInput("aaaa-1111"));
    }

    void appSerializationKeepsApolloFields()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QSettings settings(dir.filePath("apps.ini"), QSettings::IniFormat);
        NvApp app; app.id = 7; app.name = "Game"; app.uuid = "U-7"; app.hostIndex = 4; app.artVersion = "9";
        app.serialize(settings);
        NvApp loaded(settings);
        QCOMPARE(loaded, app);
        QCOMPARE(loaded.hostIndex, qint64(4));
    }

    void legacySerializedAppHasNoIndex()
    {
        QTemporaryDir dir;
        QSettings settings(dir.filePath("legacy.ini"), QSettings::IniFormat);
        settings.setValue("name", "Old"); settings.setValue("id", 3);
        NvApp loaded(settings);
        QCOMPARE(loaded.hostIndex, qint64(-1));
        QVERIFY(loaded.uuid.isEmpty());
    }
    void launchQueryForStockHostIsEmpty()
    {
        ApolloLaunchOptions options;
        options.apolloHost = false;
        options.appUuid = "U"; options.virtualDisplay = 1; options.scaleFactor = 150; options.clientName = "Deck";
        QVERIFY(options.queryString().isEmpty());
    }

    void launchQueryHostDecides()
    {
        ApolloLaunchOptions options;
        options.apolloHost = true;
        options.appUuid = "11111111-0000-4000-8000-000000000001";
        options.clientName = "Omar's Deck";
        // virtualDisplay -1 (host decides) and scale 100 are host defaults: not sent.
        QCOMPARE(options.queryString(),
                 QString("&appuuid=11111111-0000-4000-8000-000000000001&clientName=Omar%27s%20Deck"));
    }

    void launchQueryExplicitDisplayAndScale()
    {
        ApolloLaunchOptions options;
        options.apolloHost = true;
        options.virtualDisplay = 0;
        options.scaleFactor = 150;
        QCOMPARE(options.queryString(), QString("&virtualDisplay=0&scaleFactor=150"));
        options.virtualDisplay = 1;
        options.scaleFactor = 500; // clamped to the host's 20..200
        QCOMPARE(options.queryString(), QString("&virtualDisplay=1&scaleFactor=200"));
        options.scaleFactor = 5;
        QCOMPARE(options.queryString(), QString("&virtualDisplay=1&scaleFactor=20"));
    }

    void launchQueryNeverSendsReservedClientName()
    {
        // The host refuses clients named "self" (src/nvhttp.cpp:2906-2909).
        ApolloLaunchOptions options;
        options.apolloHost = true;
        options.clientName = "  Self ";
        QVERIFY(!options.queryString().contains("clientName"));
    }

    void launchReplyClassification()
    {
        using R = ApolloLaunchReply::Kind;
        QCOMPARE(ApolloLaunchReply::classify(410, false), R::Notice);       // confirm replacement, terminated...
        QCOMPARE(ApolloLaunchReply::classify(403, false), R::Error);
        QCOMPARE(ApolloLaunchReply::classify(503, true), R::RetryAsLaunch);  // /resume: app already exited
        QCOMPARE(ApolloLaunchReply::classify(503, false), R::Error);
        QCOMPARE(ApolloLaunchReply::classify(500, true), R::Error);
    }
    void otpAuthHash()
    {
        // uppercase hex SHA-256(pin + saltHex + passphrase), as Vibepollo checks it
        // (src/nvhttp.cpp:4054-4082); vector computed independently with Python hashlib.
        QCOMPARE(ApolloOtp::otpAuth("1234", "00112233445566778899aabbccddeeff", "deck pass"),
                 QByteArray("E6430A9EAE4B91FF8A9D372135174EBEF7B7855692830516C9B7BA2AF43906FC"));
    }

    void otpInputValidation()
    {
        QVERIFY(ApolloOtp::isValidPin("0042"));
        QVERIFY(!ApolloOtp::isValidPin("042"));
        QVERIFY(!ApolloOtp::isValidPin("12a4"));
        QVERIFY(ApolloOtp::isValidPassphrase("abcd"));
        QVERIFY(!ApolloOtp::isValidPassphrase("abc"));
    }

    void pairingDeviceName()
    {
        QCOMPARE(ApolloOtp::deviceNameArg("Omar's Deck"), QString("Omar%27s%20Deck"));
        QCOMPARE(ApolloOtp::deviceNameArg(""), QString("roth"));       // stock fallback
        QCOMPARE(ApolloOtp::deviceNameArg(" SELF "), QString("roth")); // host refuses "self"
    }
    void clipboardOffNeverSyncs()
    {
        ApolloClipboardSync sync(ApolloClipboardSync::Off, true, true);
        QVERIFY(!sync.shouldPushOnFocusGain("text"));
        QVERIFY(!sync.shouldPullOnFocusLoss());
        QVERIFY(!sync.shouldPullOnDisconnect());
    }

    void clipboardSmartFollowsPermissions()
    {
        ApolloClipboardSync readOnly(ApolloClipboardSync::Smart, true, false);
        QVERIFY(!readOnly.shouldPushOnFocusGain("text"));
        QVERIFY(readOnly.shouldPullOnFocusLoss());
        ApolloClipboardSync setOnly(ApolloClipboardSync::Smart, false, true);
        QVERIFY(setOnly.shouldPushOnFocusGain("text"));
        QVERIFY(!setOnly.shouldPullOnFocusLoss());
        QVERIFY(!setOnly.shouldPullOnDisconnect());
    }

    void clipboardManualOnlyOnRequest()
    {
        ApolloClipboardSync sync(ApolloClipboardSync::Manual, true, true);
        QVERIFY(!sync.shouldPushOnFocusGain("text"));
        QVERIFY(!sync.shouldPullOnFocusLoss());
        QVERIFY(sync.canPush());
        QVERIFY(sync.canPull());
    }

    void clipboardLoopGuard()
    {
        ApolloClipboardSync sync(ApolloClipboardSync::Smart, true, true);
        QVERIFY(!sync.shouldPushOnFocusGain(""));               // nothing to push
        QVERIFY(sync.shouldPushOnFocusGain("from mac"));
        sync.pushed("from mac");
        QVERIFY(!sync.shouldPushOnFocusGain("from mac"));       // unchanged since last sync
        QVERIFY(!sync.acceptPulled("from mac", "from mac"));    // host echoes what we sent
        QVERIFY(sync.acceptPulled("from pc", "from mac"));      // new host text: set it locally
        QVERIFY(!sync.shouldPushOnFocusGain("from pc"));        // and don't send it back
        QVERIFY(!sync.acceptPulled("", "from pc"));             // empty host clipboard never wipes ours
    }

    void clipboardPermissionLossStopsSync()
    {
        ApolloClipboardSync sync(ApolloClipboardSync::Smart, true, true);
        sync.permissionDenied();                                // host answered 401
        QVERIFY(!sync.shouldPushOnFocusGain("x"));
        QVERIFY(!sync.shouldPullOnFocusLoss());
        QVERIFY(!sync.canPull());
    }
    void quickMenuFullPermissions()
    {
        const auto host = ApolloHostInfo::fromServerInfo(kPairedApollo); // list|view|launch|server_cmd
        ApolloQuickMenu menu;
        menu.build(true, host, true);
        QStringList labels;
        for (const auto& item : menu.items()) labels << item.label;
        // Empty command name keeps index 2 but is not shown; no clipboard bits granted.
        QCOMPARE(labels, QStringList({"Server command: Restart Steam", "Server command: Sleep monitor",
                                      "Toggle stats", "Disconnect", "Quit app on PC"}));
        QCOMPARE(menu.items()[1].commandIndex, 1);
    }

    void quickMenuClipboardItemsFollowBitsAndSetting()
    {
        ApolloHostInfo host;
        host.detected = true; host.permissionsKnown = true;
        host.permissions = ApolloPermissions::ClipboardRead | ApolloPermissions::View;
        ApolloQuickMenu menu;
        menu.build(true, host, true);
        QStringList labels;
        for (const auto& item : menu.items()) labels << item.label;
        QCOMPARE(labels, QStringList({"Pull clipboard from PC", "Toggle stats", "Disconnect"})); // no launch: no quit
        menu.build(true, host, false); // clipboard sync off: no clipboard items
        QCOMPARE(menu.items().size(), 2);
    }

    void quickMenuStockHost()
    {
        ApolloQuickMenu menu;
        menu.build(false, ApolloHostInfo{}, true);
        QStringList labels;
        for (const auto& item : menu.items()) labels << item.label;
        QCOMPARE(labels, QStringList({"Toggle stats", "Disconnect", "Quit app on PC"}));
    }

    void quickMenuNavigationAndText()
    {
        ApolloQuickMenu menu;
        menu.build(false, ApolloHostInfo{}, true);
        menu.open();
        QVERIFY(menu.isOpen());
        QCOMPARE(menu.selected()->kind, ApolloQuickMenu::ToggleStats);
        menu.moveUp(); // wraps
        QCOMPARE(menu.selected()->kind, ApolloQuickMenu::QuitApp);
        menu.moveDown();
        menu.moveDown();
        QCOMPARE(menu.selected()->kind, ApolloQuickMenu::Disconnect);
        QVERIFY(menu.text().contains("> Disconnect\n"));
        QVERIFY(menu.text().contains("   Toggle stats\n"));
        menu.close();
        QVERIFY(!menu.isOpen());
    }

    void quickMenuTextFitsOverlay()
    {
        ApolloHostInfo host;
        host.detected = true; host.permissionsKnown = true;
        host.permissions = ApolloPermissions::ServerCommand;
        for (int i = 0; i < 100; i++) host.serverCommands << QString(80, QChar('a' + (i % 26)));
        ApolloQuickMenu menu;
        menu.build(true, host, true);
        QVERIFY(menu.text().size() <= ApolloQuickMenu::kMaxText);
        QVERIFY(menu.items()[0].label.size() <= 16 + ApolloQuickMenu::kMaxCommandName);
    }
};

QTEST_GUILESS_MAIN(TestApollo)
#include "tst_apollo.moc"
