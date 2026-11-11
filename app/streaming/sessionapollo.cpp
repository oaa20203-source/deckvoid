// The parts of Session that only !ink has: Apollo clipboard transfers and the
// in-stream quick menu. They are kept out of session.cpp so that merges from
// upstream moonlight-qt do not conflict with them.

#include "session.h"
#include "sessionapollo.h"

#include "backend/nvhttp.h"
#include "SDL_compat.h"

#include <Limelight.h>

#include <QRunnable>
#include <QThreadPool>

namespace {
// Runs one Apollo clipboard request off the SDL main thread and posts the result back.
class ApolloClipboardTask : public QRunnable
{
public:
    ApolloClipboardTask(NvComputer* computer, bool push, QString text)
        : m_Computer(computer), m_Push(push), m_Text(std::move(text)) {}

    void run() override
    {
        int status = 0;
        QString* pulled = nullptr;
        try {
            NvHTTP http(m_Computer);
            if (m_Push) {
                http.setClipboard(m_Text);
            }
            else {
                pulled = new QString(http.getClipboard());
            }
        } catch (const GfeHttpResponseException& e) {
            status = e.getStatusCode();
        } catch (const QtNetworkReplyException&) {
            status = -1;
        }

        SDL_Event event = {};
        event.type = SDL_USEREVENT;
        event.user.code = SDL_CODE_APOLLO_CLIPBOARD;
        event.user.data1 = pulled;
        event.user.data2 = (void*)(intptr_t)status;
        if (SDL_PushEvent(&event) <= 0) {
            delete pulled;
        }
    }

private:
    NvComputer* m_Computer;
    bool m_Push;
    QString m_Text;
};
}

void Session::startClipboardTransfer(bool push, const QString& text)
{
    if (push) {
        // Record before sending so a quick pull cannot bounce the text back.
        m_ClipboardSync.pushed(text);
    }
    QThreadPool::globalInstance()->start(new ApolloClipboardTask(m_Computer, push, text));
}

void Session::handleClipboardResult(SDL_Event& event)
{
    QString* pulled = static_cast<QString*>(event.user.data1);
    const int status = (int)(intptr_t)event.user.data2;
    if (status == 401) {
        qWarning() << "Host refused clipboard access (permission); clipboard sync disabled for this session";
        m_ClipboardSync.permissionDenied();
    }
    else if (status != 0) {
        qInfo() << "Clipboard request failed:" << status;
    }
    if (pulled) {
        char* localText = SDL_GetClipboardText();
        const QString local = localText ? QString::fromUtf8(localText) : QString();
        SDL_free(localText);
        if (m_ClipboardSync.acceptPulled(*pulled, local)) {
            SDL_SetClipboardText(pulled->toUtf8().constData());
        }
        delete pulled;
    }
}


void Session::openQuickMenu()
{
    if (m_QuickMenu.isOpen()) {
        return;
    }
    m_QuickMenu.build(m_Computer->isApollo(), m_Computer->apollo,
                      m_Preferences->apolloClipboardSync != ApolloClipboardSync::Off);
    m_QuickMenu.open();
    // Nothing may stay pressed on the host while the menu has the input.
    m_InputHandler->releaseAllGamepads();
    m_InputHandler->raiseAllKeys();
    refreshQuickMenuOverlay();
    m_OverlayManager.setOverlayState(Overlay::OverlayQuickMenu, true);
}

void Session::closeQuickMenu()
{
    m_QuickMenu.close();
    m_OverlayManager.setOverlayState(Overlay::OverlayQuickMenu, false);
}

void Session::refreshQuickMenuOverlay()
{
    m_OverlayManager.updateOverlayText(Overlay::OverlayQuickMenu, m_QuickMenu.text().constData());
}

bool Session::handleQuickMenuInput(SDL_Event& event)
{
    switch (event.type) {
    case SDL_KEYDOWN:
        switch (event.key.keysym.sym) {
        case SDLK_UP: m_QuickMenu.moveUp(); refreshQuickMenuOverlay(); break;
        case SDLK_DOWN: m_QuickMenu.moveDown(); refreshQuickMenuOverlay(); break;
        case SDLK_RETURN:
        case SDLK_KP_ENTER:
        case SDLK_SPACE: activateQuickMenuItem(); break;
        case SDLK_ESCAPE: closeQuickMenu(); break;
        default: break;
        }
        return true;
    case SDL_CONTROLLERBUTTONDOWN:
        switch (event.cbutton.button) {
        case SDL_CONTROLLER_BUTTON_DPAD_UP: m_QuickMenu.moveUp(); refreshQuickMenuOverlay(); break;
        case SDL_CONTROLLER_BUTTON_DPAD_DOWN: m_QuickMenu.moveDown(); refreshQuickMenuOverlay(); break;
        case SDL_CONTROLLER_BUTTON_A: activateQuickMenuItem(); break;
        case SDL_CONTROLLER_BUTTON_B: closeQuickMenu(); break;
        default: break;
        }
        // Keep the input handler's button state in sync without sending a press.
        return true;
    case SDL_KEYUP:
        // Releases still go through so the host and local key state stay consistent.
        return false;
    case SDL_CONTROLLERBUTTONUP:
        return false;
    case SDL_TEXTINPUT:
    case SDL_MOUSEBUTTONDOWN:
    case SDL_MOUSEBUTTONUP:
    case SDL_MOUSEMOTION:
    case SDL_MOUSEWHEEL:
    case SDL_CONTROLLERAXISMOTION:
#if SDL_VERSION_ATLEAST(2, 0, 14)
    case SDL_CONTROLLERSENSORUPDATE:
    case SDL_CONTROLLERTOUCHPADDOWN:
    case SDL_CONTROLLERTOUCHPADUP:
    case SDL_CONTROLLERTOUCHPADMOTION:
#endif
    case SDL_FINGERDOWN:
    case SDL_FINGERMOTION:
    case SDL_FINGERUP:
        return true;
    default:
        return false;
    }
}

void Session::activateQuickMenuItem()
{
    const auto* item = m_QuickMenu.selected();
    if (item == nullptr) {
        return;
    }
    const auto kind = item->kind;
    const int commandIndex = item->commandIndex;
    closeQuickMenu();

    switch (kind) {
    case ApolloQuickMenu::ServerCommand: {
        const int rc = LiSendExecServerCmd((uint8_t)commandIndex);
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Server command %d sent: %d", commandIndex, rc);
        break;
    }
    case ApolloQuickMenu::PushClipboard: {
        char* localText = SDL_GetClipboardText();
        const QString text = localText ? QString::fromUtf8(localText) : QString();
        SDL_free(localText);
        if (!text.isEmpty() && m_ClipboardSync.canPush()) {
            startClipboardTransfer(true, text);
        }
        break;
    }
    case ApolloQuickMenu::PullClipboard:
        if (m_ClipboardSync.canPull()) {
            startClipboardTransfer(false, QString());
        }
        break;
    case ApolloQuickMenu::ToggleStats:
        m_OverlayManager.setOverlayState(Overlay::OverlayDebug, !m_OverlayManager.isStatsEnabled());
        break;
    case ApolloQuickMenu::QuitApp:
        m_QuitHostAppOnEnd = true;
        [[fallthrough]];
    case ApolloQuickMenu::Disconnect: {
        SDL_Event quit = {};
        quit.type = SDL_QUIT;
        quit.quit.timestamp = SDL_GetTicks();
        SDL_PushEvent(&quit);
        break;
    }
    }
}
