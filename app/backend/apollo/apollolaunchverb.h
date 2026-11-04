#pragma once

#include "backend/nvapp.h"

#include <QString>

// Which request to send when the user picks an app, given what the host says
// is running (currentgame / currentgameuuid in /serverinfo).
namespace ApolloLaunchVerb {

enum class Verb {
    Launch,          // nothing relevant running: /launch
    Resume,          // this app is running: /resume
    QuitThenLaunch,  // another app is running: the UI asks before quitting it
};

// Remote Input sessions carry no app. Choosing a real app replaces them on the
// host (Vibepollo src/nvhttp.cpp:5383); /resume would reattach to input-only.
inline bool isRemoteInput(const QString& uuid)
{
    return uuid.compare(QLatin1String("8CB5C136-DA67-4F99-B4A1-F9CD35005CF4"), Qt::CaseInsensitive) == 0 ||   // legacy Apollo
           uuid.compare(QLatin1String("9a1c5a25-58fe-40e0-b9aa-7d3f00000006"), Qt::CaseInsensitive) == 0;      // Vibepollo tile
}

inline Verb choose(int currentGameId, const QString& currentGameUuid, const NvApp& app)
{
    if (!currentGameUuid.isEmpty()) {
        if (!app.uuid.isEmpty() && currentGameUuid.compare(app.uuid, Qt::CaseInsensitive) == 0) {
            return Verb::Resume;
        }
        return isRemoteInput(currentGameUuid) ? Verb::Launch : Verb::QuitThenLaunch;
    }

    if (currentGameId == 0) {
        return Verb::Launch;
    }
    return currentGameId == app.id ? Verb::Resume : Verb::QuitThenLaunch;
}

} // namespace ApolloLaunchVerb
