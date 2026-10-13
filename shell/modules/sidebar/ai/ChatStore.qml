import QtQuick
import Caelestia.Config
import "chatsessions.js" as Sessions

QtObject {
    id: root

    property var sessions: []
    property string currentChatId: ""
    property string provider
    property int revision: 0

    readonly property ListModel messages: ListModel {}

    signal titleNeeded(string chatId, string firstMessage)

    function load(): void {
        sessions = Sessions.parseStored(GlobalConfig.ai.ollamaHistoryJson);
        revision++;
    }

    function persist(): void {
        if (GlobalConfig.ai.saveChatHistory)
            GlobalConfig.ai.ollamaHistoryJson = Sessions.serialize(sessions);
    }

    function forgetStored(ids: var): void {
        if (GlobalConfig.ai.saveChatHistory)
            return;
        const json = Sessions.withoutChats(GlobalConfig.ai.ollamaHistoryJson, ids);
        if (json !== null)
            GlobalConfig.ai.ollamaHistoryJson = json;
    }

    function session(id: string): var {
        return Sessions.find(sessions, id);
    }

    function current(): var {
        return session(currentChatId);
    }

    function currentProp(key: string): var {
        revision;
        const s = current();
        return s ? s[key] : undefined;
    }

    function newChat(props: var): string {
        dropIfEmpty(currentChatId);
        const s = {
            "id": "chat_" + Date.now(),
            "title": "New Chat",
            "messages": []
        };
        for (const k in props || {})
            s[k] = props[k];
        sessions = [s].concat(sessions);
        show(s.id);
        return s.id;
    }

    function open(id: string): bool {
        if (!session(id))
            return false;
        if (id !== currentChatId)
            dropIfEmpty(currentChatId);
        show(id);
        return true;
    }

    function append(chatId: string, fields: var): string {
        const s = session(chatId);
        if (!s)
            return "";
        const m = Sessions.newMessage(fields);
        m.isNew = true;
        Sessions.editMessage(s, viewOf(chatId), "append", m.msgId, m);
        if (m.isUser)
            s.provider = provider;
        touch(s);
        if (m.isUser && !s.titleLocked && Sessions.isDefaultTitle(s.title))
            titleNeeded(chatId, Sessions.firstUserText(s));
        persist();
        return m.msgId;
    }

    function message(chatId: string, msgId: string): var {
        return Sessions.findMessage(session(chatId), msgId);
    }

    function update(chatId: string, msgId: string, patch: var): void {
        const s = session(chatId);
        if (!s || !Sessions.editMessage(s, viewOf(chatId), "update", msgId, patch))
            return;
        if (patch.isFinished)
            touch(s);
        persist();
    }

    function remove(chatId: string, msgId: string): void {
        const s = session(chatId);
        if (s) {
            Sessions.editMessage(s, viewOf(chatId), "remove", msgId, null);
            persist();
        }
    }

    function setChatProps(chatId: string, patch: var): void {
        const s = session(chatId);
        if (!s)
            return;
        for (const k in patch)
            s[k] = patch[k];
        persist();
        revision++;
    }

    function setTitle(chatId: string, title: string): void {
        const s = session(chatId);
        if (!s || !title || s.titleLocked)
            return;
        s.title = title;
        persist();
        revision++;
    }

    function rename(chatId: string, title: string): void {
        const s = session(chatId);
        if (!s || !title || title === s.title)
            return;
        s.title = title;
        s.titleLocked = true;
        persist();
        revision++;
    }

    function takeChats(ids: var): var {
        const taken = [];
        for (let i = 0; i < sessions.length; i++) {
            if (ids.indexOf(sessions[i].id) !== -1) {
                const s = sessions[i];
                for (let j = 0; j < s.messages.length; j++) {
                    if (!s.messages[j].isFinished)
                        Sessions.editMessage(s, viewOf(s.id), "update", s.messages[j].msgId, { "isFinished": true });
                }
                taken.push({
                    "index": i,
                    "session": s
                });
            }
        }
        if (taken.length === 0)
            return taken;
        sessions = sessions.filter(s => ids.indexOf(s.id) === -1);
        persist();
        forgetStored(ids);
        revision++;
        return taken;
    }

    function restoreChats(taken: var): void {
        for (let i = 0; i < taken.length; i++)
            if (!session(taken[i].session.id))
                sessions.splice(Math.min(taken[i].index, sessions.length), 0, taken[i].session);
        persist();
        revision++;
    }

    function show(id: string): void {
        currentChatId = id;
        Sessions.showMessages(session(id), messages);
        revision++;
    }

    function touch(s: var): void {
        if (!s)
            return;
        s.updatedAt = Date.now();
        const i = sessions.indexOf(s);
        if (i > 0) {
            sessions.splice(i, 1);
            sessions.unshift(s);
        }
        revision++;
    }

    function dropIfEmpty(id: string): void {
        const s = session(id);
        if (s && s.messages.length === 0)
            sessions = sessions.filter(x => x !== s);
    }

    function viewOf(chatId: string): ListModel {
        return chatId === currentChatId ? messages : null;
    }
}
