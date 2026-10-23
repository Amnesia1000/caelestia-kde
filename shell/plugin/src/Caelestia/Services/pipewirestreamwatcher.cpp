// SPDX-License-Identifier: GPL-3.0-only
#include "pipewirestreamwatcher.hpp"

#include <pipewire/pipewire.h>
#include <spa/utils/result.h>

#include <QElapsedTimer>
#include <QHash>
#include <QLoggingCategory>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QTimer>

Q_LOGGING_CATEGORY(lcPipewireStreamWatcher, "caelestia.services.pipewirestreamwatcher", QtInfoMsg)

namespace caelestia::services {

namespace {

bool isStreamingNode(const char* mediaClass, const char* nodeName, const char* mediaName, const char* mediaRole) {
    if (!mediaClass) {
        return false;
    }

    if (strcmp(mediaClass, "Stream/Input/Video") == 0) {
        // Exclude internal quickshell / caelestia-shell previews and KDE screencast helpers
        if (nodeName && (strcmp(nodeName, "quickshell") == 0 || strcmp(nodeName, "caelestia-shell") == 0)) {
            return false;
        }
        if (mediaName && strncmp(mediaName, "plasma-screencast-", 18) == 0) {
            return false;
        }
        return true;
    }

    if (strcmp(mediaClass, "Video/Source") == 0) {
        // Exclude hardware webcams and V4L2 devices
        if (mediaRole && strcmp(mediaRole, "Camera") == 0) {
            return false;
        }
        if (nodeName && strncmp(nodeName, "v4l2_input", 10) == 0) {
            return false;
        }
        return true;
    }

    return false;
}

bool isVideoNodeClass(const char* mediaClass) {
    return mediaClass && (strcmp(mediaClass, "Stream/Input/Video") == 0 || strcmp(mediaClass, "Video/Source") == 0);
}

qint64 elapsedMs() {
    static const QElapsedTimer clock = [] {
        QElapsedTimer t;
        t.start();
        return t;
    }();
    return clock.elapsed();
}

constexpr qint64 STREAM_CONFIRM_INTERVAL_MS = 5000;

} // namespace

struct TrackedNode {
    QString mediaClass;
    QString nodeName;
    QString mediaName;
    QString mediaRole;
    bool isStreaming = false;
    qint64 firstStreamingMs = 0;
    bool confirmed = false;
};

class PipewireStreamWatcherPrivate;

struct NodeBinding {
    uint32_t id = 0;
    pw_node* proxy = nullptr;
    spa_hook listener{};
    PipewireStreamWatcherPrivate* owner = nullptr;
};

class PipewireStreamWatcherPrivate {
public:
    explicit PipewireStreamWatcherPrivate(PipewireStreamWatcher* parent)
        : q(parent) {}

    PipewireStreamWatcher* q = nullptr;
    pw_thread_loop* threadLoop = nullptr;
    pw_context* context = nullptr;
    pw_core* core = nullptr;
    pw_registry* registry = nullptr;
    spa_hook registryListener{};
    spa_hook coreListener{};
    QTimer* reconnectTimer = nullptr;

    mutable QMutex mutex;
    QHash<uint32_t, TrackedNode> trackedNodes;
    QHash<uint32_t, NodeBinding*> bindings;
    QTimer* confirmTimer = nullptr;

    bool m_streaming = false;
    int m_streamCount = 0;
    QStringList m_activeStreams;

    void init();
    void cleanup();
    void tryConnect();
    void scheduleReconnect();
    void notifyStateChangedFromThread();
    void updateState(bool streaming, int count, const QStringList& streams);

    void bindNode(uint32_t id, uint32_t version, const spa_dict* props);
    void releaseBinding(uint32_t id);
    void releaseBindings();
    void applyNodeProps(uint32_t id, const spa_dict* props);

    static void onNodeInfo(void* data, const pw_node_info* info);

    static void onGlobal(
        void* data, uint32_t id, uint32_t permissions, const char* type, uint32_t version, const spa_dict* props);
    static void onGlobalRemove(void* data, uint32_t id);
    static void onCoreError(void* data, uint32_t id, int seq, int res, const char* message);
};

void PipewireStreamWatcherPrivate::init() {
    pw_init(nullptr, nullptr);

    reconnectTimer = new QTimer(q);
    reconnectTimer->setInterval(3000);
    reconnectTimer->setSingleShot(true);
    QObject::connect(reconnectTimer, &QTimer::timeout, q, [this]() {
        tryConnect();
    });

    confirmTimer = new QTimer(q);
    confirmTimer->setInterval(1000);
    QObject::connect(confirmTimer, &QTimer::timeout, q, [this]() {
        notifyStateChangedFromThread();
    });

    tryConnect();
}

void PipewireStreamWatcherPrivate::cleanup() {
    if (reconnectTimer) {
        reconnectTimer->stop();
    }
    if (confirmTimer) {
        confirmTimer->stop();
    }

    if (threadLoop) {
        pw_thread_loop_stop(threadLoop);
        pw_thread_loop_lock(threadLoop);
    }

    if (registry) {
        spa_hook_remove(&registryListener);
        releaseBindings();
        pw_proxy_destroy(reinterpret_cast<pw_proxy*>(registry));
        registry = nullptr;
    }

    if (core) {
        spa_hook_remove(&coreListener);
        pw_core_disconnect(core);
        core = nullptr;
    }

    if (context) {
        pw_context_destroy(context);
        context = nullptr;
    }

    if (threadLoop) {
        pw_thread_loop_unlock(threadLoop);
        pw_thread_loop_destroy(threadLoop);
        threadLoop = nullptr;
    }

    pw_deinit();

    {
        QMutexLocker locker(&mutex);
        trackedNodes.clear();
    }
}

void PipewireStreamWatcherPrivate::tryConnect() {
    if (threadLoop) {
        cleanup();
        pw_init(nullptr, nullptr);
    }

    threadLoop = pw_thread_loop_new("caelestia-stream-watcher", nullptr);
    if (!threadLoop) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to create PipeWire thread loop";
        scheduleReconnect();
        return;
    }

    if (pw_thread_loop_start(threadLoop) < 0) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to start PipeWire thread loop";
        pw_thread_loop_destroy(threadLoop);
        threadLoop = nullptr;
        scheduleReconnect();
        return;
    }

    pw_thread_loop_lock(threadLoop);

    context = pw_context_new(pw_thread_loop_get_loop(threadLoop), nullptr, 0);
    if (!context) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to create PipeWire context";
        pw_thread_loop_unlock(threadLoop);
        scheduleReconnect();
        return;
    }

    core = pw_context_connect(context, nullptr, 0);
    if (!core) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to connect to PipeWire core";
        pw_context_destroy(context);
        context = nullptr;
        pw_thread_loop_unlock(threadLoop);
        scheduleReconnect();
        return;
    }

    static const pw_core_events coreEvents = {
        .version = PW_VERSION_CORE_EVENTS,
        .error = onCoreError,
    };
    spa_zero(coreListener);
    pw_core_add_listener(core, &coreListener, &coreEvents, this);

    registry = pw_core_get_registry(core, PW_VERSION_REGISTRY, 0);
    if (!registry) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to get PipeWire registry";
        pw_thread_loop_unlock(threadLoop);
        scheduleReconnect();
        return;
    }

    static const pw_registry_events registryEvents = {
        .version = PW_VERSION_REGISTRY_EVENTS,
        .global = onGlobal,
        .global_remove = onGlobalRemove,
    };
    spa_zero(registryListener);
    pw_registry_add_listener(registry, &registryListener, &registryEvents, this);

    pw_thread_loop_unlock(threadLoop);
    qCInfo(lcPipewireStreamWatcher) << "Connected to PipeWire registry";
}

void PipewireStreamWatcherPrivate::scheduleReconnect() {
    if (reconnectTimer && !reconnectTimer->isActive()) {
        reconnectTimer->start();
    }
}

void PipewireStreamWatcherPrivate::notifyStateChangedFromThread() {
    bool streaming = false;
    int count = 0;
    QStringList streams;
    bool pending = false;

    {
        QMutexLocker locker(&mutex);
        const qint64 nowMs = elapsedMs();
        for (auto& node : trackedNodes) {
            if (!node.isStreaming) {
                continue;
            }
            if (!node.confirmed) {
                if (nowMs - node.firstStreamingMs >= STREAM_CONFIRM_INTERVAL_MS) {
                    node.confirmed = true;
                    qCInfo(lcPipewireStreamWatcher) << "Streaming node confirmed after grace period:"
                                                    << (!node.mediaName.isEmpty() ? node.mediaName : node.nodeName);
                } else {
                    pending = true;
                    continue;
                }
            }
            ++count;
            streams.append(!node.mediaName.isEmpty() ? node.mediaName : node.nodeName);
        }
        streaming = (count > 0);
    }

    QMetaObject::invokeMethod(
        q,
        [this, streaming, count, streams, pending]() {
            if (pending != confirmTimer->isActive()) {
                if (pending) {
                    confirmTimer->start();
                } else {
                    confirmTimer->stop();
                }
            }
            updateState(streaming, count, streams);
        },
        Qt::QueuedConnection);
}

void PipewireStreamWatcherPrivate::updateState(bool streaming, int count, const QStringList& streams) {
    const bool streamingChanged = (m_streaming != streaming);
    const bool countChanged = (m_streamCount != count);
    const bool streamsChanged = (m_activeStreams != streams);

    m_streaming = streaming;
    m_streamCount = count;
    m_activeStreams = streams;

    if (streamingChanged) {
        qCInfo(lcPipewireStreamWatcher) << "Streaming state changed to" << m_streaming
                                        << "(active count:" << m_streamCount << ")";
        emit q->streamingChanged(m_streaming);
    }
    if (countChanged) {
        emit q->streamCountChanged(m_streamCount);
    }
    if (streamsChanged) {
        emit q->activeStreamsChanged();
    }
}

void PipewireStreamWatcherPrivate::bindNode(uint32_t id, uint32_t version, const spa_dict* props) {
    if (!registry) {
        return;
    }

    releaseBinding(id);

    const uint32_t bindVersion = version < PW_VERSION_NODE ? version : PW_VERSION_NODE;
    auto* proxy = static_cast<pw_node*>(pw_registry_bind(registry, id, PW_TYPE_INTERFACE_Node, bindVersion, 0));
    if (!proxy) {
        qCWarning(lcPipewireStreamWatcher) << "Failed to bind node" << id;
        return;
    }

    auto* binding = new NodeBinding;
    binding->id = id;
    binding->proxy = proxy;
    binding->owner = this;

    static const pw_node_events nodeEvents = {
        .version = PW_VERSION_NODE_EVENTS,
        .info = onNodeInfo,
    };
    pw_node_add_listener(proxy, &binding->listener, &nodeEvents, binding);

    bindings.insert(id, binding);

    if (props) {
        applyNodeProps(id, props);
    }
}

void PipewireStreamWatcherPrivate::releaseBinding(uint32_t id) {
    auto* binding = bindings.take(id);
    if (!binding) {
        return;
    }

    spa_hook_remove(&binding->listener);
    if (binding->proxy) {
        pw_proxy_destroy(reinterpret_cast<pw_proxy*>(binding->proxy));
    }
    delete binding;
}

void PipewireStreamWatcherPrivate::releaseBindings() {
    const auto ids = bindings.keys();
    for (const uint32_t id : ids) {
        releaseBinding(id);
    }
}

void PipewireStreamWatcherPrivate::applyNodeProps(uint32_t id, const spa_dict* props) {
    if (!props) {
        return;
    }

    const char* mediaClass = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS);
    const char* nodeName = spa_dict_lookup(props, PW_KEY_NODE_NAME);
    const char* mediaName = spa_dict_lookup(props, PW_KEY_MEDIA_NAME);
    const char* mediaRole = spa_dict_lookup(props, PW_KEY_MEDIA_ROLE);

    bool wasStreaming = false;
    bool streaming = false;
    {
        QMutexLocker locker(&mutex);
        auto it = trackedNodes.find(id);
        if (it == trackedNodes.end()) {
            return;
        }

        wasStreaming = it->isStreaming;
        const char* effectiveClass = mediaClass;
        const char* effectiveName = nodeName;
        const char* effectiveMediaName = mediaName;
        const char* effectiveRole = mediaRole;

        if (mediaClass) {
            it->mediaClass = QString::fromUtf8(mediaClass);
        }
        if (nodeName) {
            it->nodeName = QString::fromUtf8(nodeName);
        }
        if (mediaName) {
            it->mediaName = QString::fromUtf8(mediaName);
        }
        if (mediaRole) {
            it->mediaRole = QString::fromUtf8(mediaRole);
        }

        const QByteArray classBytes = it->mediaClass.toUtf8();
        const QByteArray nameBytes = it->nodeName.toUtf8();
        const QByteArray mediaBytes = it->mediaName.toUtf8();
        const QByteArray roleBytes = it->mediaRole.toUtf8();

        if (!effectiveClass)
            effectiveClass = classBytes.isEmpty() ? nullptr : classBytes.constData();
        if (!effectiveName)
            effectiveName = nameBytes.isEmpty() ? nullptr : nameBytes.constData();
        if (!effectiveMediaName)
            effectiveMediaName = mediaBytes.isEmpty() ? nullptr : mediaBytes.constData();
        if (!effectiveRole)
            effectiveRole = roleBytes.isEmpty() ? nullptr : roleBytes.constData();

        const bool consumerClass = effectiveClass && strcmp(effectiveClass, "Stream/Input/Video") == 0;
        const bool mediaNameUnknown = !effectiveMediaName;
        streaming = consumerClass && mediaNameUnknown
                        ? false
                        : isStreamingNode(effectiveClass, effectiveName, effectiveMediaName, effectiveRole);

        if (streaming && !wasStreaming) {
            it->firstStreamingMs = elapsedMs();
            it->confirmed = false;
        } else if (!streaming) {
            it->firstStreamingMs = 0;
            it->confirmed = false;
        }
        it->isStreaming = streaming;
    }

    if (streaming != wasStreaming) {
        if (streaming) {
            qCInfo(lcPipewireStreamWatcher)
                << "Detected video streaming node:" << (mediaName ? mediaName : (nodeName ? nodeName : "<unknown>"))
                << "id:" << id << "class:" << (mediaClass ? mediaClass : "<unknown>");
        } else {
            qCInfo(lcPipewireStreamWatcher) << "Video streaming node no longer streaming, id:" << id;
        }
        notifyStateChangedFromThread();
    }
}

void PipewireStreamWatcherPrivate::onNodeInfo(void* data, const pw_node_info* info) {
    auto* binding = static_cast<NodeBinding*>(data);
    if (!binding || !binding->owner || !info) {
        return;
    }

    binding->owner->applyNodeProps(binding->id, info->props);
}

void PipewireStreamWatcherPrivate::onGlobal(
    void* data, uint32_t id, uint32_t /*permissions*/, const char* type, uint32_t version, const spa_dict* props) {
    if (!type || strcmp(type, PW_TYPE_INTERFACE_Node) != 0 || !props) {
        return;
    }

    auto* d = static_cast<PipewireStreamWatcherPrivate*>(data);

    const char* mediaClass = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS);
    if (!isVideoNodeClass(mediaClass)) {
        return;
    }

    const char* nodeName = spa_dict_lookup(props, PW_KEY_NODE_NAME);
    const char* mediaName = spa_dict_lookup(props, PW_KEY_MEDIA_NAME);
    const char* mediaRole = spa_dict_lookup(props, PW_KEY_MEDIA_ROLE);

    const bool consumerClass = strcmp(mediaClass, "Stream/Input/Video") == 0;
    const bool streaming =
        consumerClass && !mediaName ? false : isStreamingNode(mediaClass, nodeName, mediaName, mediaRole);

    {
        QMutexLocker locker(&d->mutex);
        auto& node = d->trackedNodes[id];
        node.mediaClass = mediaClass ? QString::fromUtf8(mediaClass) : QString();
        node.nodeName = nodeName ? QString::fromUtf8(nodeName) : QString();
        node.mediaName = mediaName ? QString::fromUtf8(mediaName) : QString();
        node.mediaRole = mediaRole ? QString::fromUtf8(mediaRole) : QString();
        if (streaming && !node.isStreaming) {
            node.firstStreamingMs = elapsedMs();
            node.confirmed = false;
        } else if (!streaming) {
            node.firstStreamingMs = 0;
            node.confirmed = false;
        }
        node.isStreaming = streaming;
    }

    if (streaming) {
        qCInfo(lcPipewireStreamWatcher) << "Detected video streaming node:" << (nodeName ? nodeName : "<unknown>")
                                        << "id:" << id << "class:" << (mediaClass ? mediaClass : "<unknown>");
    }

    d->bindNode(id, version, props);

    d->notifyStateChangedFromThread();
}

void PipewireStreamWatcherPrivate::onGlobalRemove(void* data, uint32_t id) {
    auto* d = static_cast<PipewireStreamWatcherPrivate*>(data);
    bool wasStreaming = false;

    {
        QMutexLocker locker(&d->mutex);
        auto it = d->trackedNodes.find(id);
        if (it != d->trackedNodes.end()) {
            wasStreaming = it->isStreaming;
            d->trackedNodes.erase(it);
        }
    }

    d->releaseBinding(id);

    if (wasStreaming) {
        qCInfo(lcPipewireStreamWatcher) << "Video streaming node removed, id:" << id;
    }

    d->notifyStateChangedFromThread();
}

void PipewireStreamWatcherPrivate::onCoreError(void* data, uint32_t id, int seq, int res, const char* message) {
    auto* d = static_cast<PipewireStreamWatcherPrivate*>(data);
    qCWarning(lcPipewireStreamWatcher) << "PipeWire core error:" << message << "id:" << id << "seq:" << seq
                                       << "res:" << res;
    if (id == PW_ID_CORE) {
        QMetaObject::invokeMethod(
            d->q,
            [d]() {
                d->scheduleReconnect();
            },
            Qt::QueuedConnection);
    }
}

PipewireStreamWatcher::PipewireStreamWatcher(QObject* parent)
    : QObject(parent)
    , d(std::make_unique<PipewireStreamWatcherPrivate>(this)) {
    d->init();
}

PipewireStreamWatcher::~PipewireStreamWatcher() {
    d->cleanup();
}

bool PipewireStreamWatcher::isStreaming() const {
    return d->m_streaming;
}

int PipewireStreamWatcher::streamCount() const {
    return d->m_streamCount;
}

QStringList PipewireStreamWatcher::activeStreams() const {
    return d->m_activeStreams;
}

void PipewireStreamWatcher::rescan() {
    d->notifyStateChangedFromThread();
}

} // namespace caelestia::services
