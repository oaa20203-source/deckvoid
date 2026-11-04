#pragma once

#include <QSettings>

class NvApp
{
public:
    NvApp() {}
    explicit NvApp(QSettings& settings);

    bool operator==(const NvApp& other) const
    {
        return id == other.id &&
                name == other.name &&
                hdrSupported == other.hdrSupported &&
                isAppCollectorGame == other.isAppCollectorGame &&
                hidden == other.hidden &&
                directLaunch == other.directLaunch &&
                uuid == other.uuid &&
                hostIndex == other.hostIndex &&
                artVersion == other.artVersion;
    }

    bool operator!=(const NvApp& other) const
    {
        return !operator==(other);
    }

    bool isInitialized()
    {
        // We use isNull() instead of isEmpty() here because we want
        // to detect cases where the name is unassigned, not empty.
        return id != 0 && !name.isNull();
    }

    void
    serialize(QSettings& settings) const;

    // Apollo hosts send this placeholder (ID 114514, no UUID) instead of the app
    // list when the client has none of the list, view or launch permissions; its
    // title tells the user what to enable (Vibepollo src/nvhttp.cpp:4762-4775).
    bool isApolloPermissionNotice() const
    {
        return id == 114514 && uuid.isEmpty();
    }

    int id = 0;
    QString name;
    bool hdrSupported = false;
    bool isAppCollectorGame = false;
    bool hidden = false;
    bool directLaunch = false;

    // Apollo-family /applist extensions (empty / -1 on other hosts).
    QString uuid;
    qint64 hostIndex = -1; // host order (IDX); -1 when unnumbered
    QString artVersion;    // changes when the host's box art changes
};

Q_DECLARE_METATYPE(NvApp)
