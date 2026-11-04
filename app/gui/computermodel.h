#include "backend/computermanager.h"
#include "streaming/session.h"

#include <QAbstractListModel>

class ComputerModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QVariantList onlineHosts READ onlineHosts NOTIFY onlineHostsChanged)

    enum Roles
    {
        NameRole = Qt::UserRole,
        OnlineRole,
        PairedRole,
        BusyRole,
        WakeableRole,
        StatusUnknownRole,
        ServerSupportedRole,
        DetailsRole,
        // DeckVoid redesign (docs/design/DESIGN.md)
        HostKindRole,          // "Apollo", "Sunshine", "GeForce Experience"
        RunningAppRole,        // name of the app this device is running on the host, or ""
        AddressRole,           // active address without the port
        VirtualDisplayRole,    // short summary, "" when the host has no virtual display
        PermissionsSummaryRole // e.g. "Launch · Clipboard · Commands", "" when unknown
    };

public:
    explicit ComputerModel(QObject* object = nullptr);

    // Must be called before any QAbstractListModel functions
    Q_INVOKABLE void initialize(ComputerManager* computerManager);

    QVariant data(const QModelIndex &index, int role) const override;

    int rowCount(const QModelIndex &parent) const override;

    virtual QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void deleteComputer(int computerIndex);

    Q_INVOKABLE QString generatePinString();

    Q_INVOKABLE void pairComputer(int computerIndex, QString pin);

    // Apollo hosts: pair with a one-time PIN and passphrase created on the host
    Q_INVOKABLE void pairComputerWithOtp(int computerIndex, QString pin, QString passphrase);
    Q_INVOKABLE bool isApolloHost(int computerIndex);
    Q_INVOKABLE bool isValidOtp(QString pin, QString passphrase);

    Q_INVOKABLE void testConnectionForComputer(int computerIndex);

    Q_INVOKABLE void wakeComputer(int computerIndex);

    Q_INVOKABLE void renameComputer(int computerIndex, QString name);

    Q_INVOKABLE QString uuidAt(int computerIndex) const;

    QVariantList onlineHosts() const;

    Q_INVOKABLE Session* createSessionForCurrentGame(int computerIndex);

signals:
    void onlineHostsChanged();
    void pairingCompleted(QVariant error);
    void connectionTestCompleted(int result, QString blockedPorts);

private slots:
    void handleComputerStateChanged(NvComputer* computer);

    void handlePairingCompleted(NvComputer* computer, QString error);

private:
    QString apolloDetails(const NvComputer* computer) const;

    QVector<NvComputer*> m_Computers;
    ComputerManager* m_ComputerManager;
};
