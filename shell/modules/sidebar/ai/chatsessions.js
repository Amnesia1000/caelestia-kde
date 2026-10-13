.pragma library

var nextMessageSerial = 0;

var messageDefaults = {
    "msgId": "",
    "isUser": false,
    "text": "",
    "isFinished": true,
    "thoughtText": "",
    "toolsJson": "",
    "usageText": "",
    "attachments": "",
    "isNew": false,
    "thoughtExpanded": false,
    "expandedTools": ""
};

var viewOnlyFields = ["isNew", "thoughtExpanded", "expandedTools"];

function newMessageId() {
    nextMessageSerial++;
    return "m_" + Date.now().toString(36) + "_" + nextMessageSerial;
}

function newMessage(fields) {
    var m = {};
    for (var k in messageDefaults)
        m[k] = messageDefaults[k];
    for (var f in fields || {})
        if (f in messageDefaults && fields[f] !== undefined && fields[f] !== null)
            m[f] = fields[f];
    if (!m.msgId)
        m.msgId = newMessageId();
    return m;
}

function isDefaultTitle(title) {
    return !title || title === "Legacy Chat" || String(title).indexOf("New Chat") === 0;
}

function find(sessions, id) {
    for (var i = 0; i < sessions.length; i++)
        if (sessions[i].id === id)
            return sessions[i];
    return null;
}

function findMessage(session, msgId) {
    if (!session)
        return null;
    var msgs = session.messages;
    for (var i = msgs.length - 1; i >= 0; i--)
        if (msgs[i].msgId === msgId)
            return msgs[i];
    return null;
}

function editMessage(session, view, op, msgId, fields) {
    var msgs = session.messages;
    if (op === "append") {
        msgs.push(fields);
        if (view)
            view.append(fields);
        return fields;
    }
    var i = msgs.length - 1;
    while (i >= 0 && msgs[i].msgId !== msgId)
        i--;
    if (i < 0)
        return null;
    var m = msgs[i];
    if (op === "update") {
        for (var k in fields)
            m[k] = fields[k];
        if (view)
            view.set(i, fields);
    } else if (op === "remove") {
        msgs.splice(i, 1);
        if (view)
            view.remove(i);
    }
    return m;
}

function showMessages(session, view) {
    view.clear();
    var msgs = session ? session.messages : [];
    for (var i = 0; i < msgs.length; i++) {
        msgs[i].isNew = false;
        view.append(msgs[i]);
    }
}

function parseStored(json) {
    var parsed;
    try {
        parsed = JSON.parse(json || "[]");
    } catch (e) {
        return [];
    }
    if (!Array.isArray(parsed))
        return [];
    var out = [];
    for (var i = 0; i < parsed.length; i++) {
        var s = parsed[i];
        if (!s || !s.id)
            continue;
        var msgs = [];
        var stored = Array.isArray(s.messages) ? s.messages : [];
        for (var j = 0; j < stored.length; j++) {
            var m = stored[j];
            if (!m || (!m.isUser && !m.text && !m.toolsJson))
                continue;
            msgs.push(newMessage({
                "msgId": m.msgId,
                "isUser": m.isUser === true,
                "text": m.text || "",
                "isFinished": true,
                "thoughtText": m.thoughtText || "",
                "toolsJson": m.toolsJson || "",
                "usageText": m.usageText || "",
                "attachments": m.attachments || ""
            }));
        }
        var session = {};
        for (var key in s)
            session[key] = s[key];
        session.messages = msgs;
        out.push(session);
    }
    return out;
}

function serialize(sessions) {
    var out = [];
    for (var i = 0; i < sessions.length; i++) {
        var s = sessions[i];
        var msgs = [];
        for (var j = 0; j < s.messages.length; j++) {
            var m = s.messages[j];
            if (!m.isUser && !m.isFinished && !m.text && !m.toolsJson)
                continue;
            var copy = {};
            for (var k in m)
                if (viewOnlyFields.indexOf(k) === -1)
                    copy[k] = m[k];
            msgs.push(copy);
        }
        if (msgs.length === 0)
            continue;
        var session = {};
        for (var key in s)
            session[key] = s[key];
        session.messages = msgs;
        out.push(session);
    }
    return JSON.stringify(out);
}

function withoutChats(json, ids) {
    var stored;
    try {
        stored = JSON.parse(json || "[]");
    } catch (e) {
        return null;
    }
    if (!Array.isArray(stored))
        return null;
    var kept = stored.filter(s => !s || ids.indexOf(s.id) === -1);
    return kept.length === stored.length ? null : JSON.stringify(kept);
}

function firstUserText(session) {
    var msgs = session ? session.messages : [];
    for (var i = 0; i < msgs.length; i++)
        if (msgs[i].isUser)
            return msgs[i].text || "";
    return "";
}

function chatTimestamp(session) {
    if (session.updatedAt)
        return session.updatedAt;
    var m = /^chat_(\d+)/.exec(session.id || "");
    return m ? Number(m[1]) : 0;
}

function plainPreview(text) {
    return (text || "").replace(/```[\s\S]*?(```|$)/g, " [code] ").replace(/[#*`>_~|]/g, "").replace(/\s+/g, " ").trim();
}

var dayMs = 86400000;

function historySection(pinned, ts, now) {
    if (pinned)
        return "pinned";
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    if (ts >= today)
        return "today";
    if (ts >= today - dayMs)
        return "yesterday";
    if (ts >= today - 6 * dayMs)
        return "week";
    if (ts >= today - 29 * dayMs)
        return "month";
    return "older";
}

function chatAge(ts, now) {
    if (!ts)
        return { "kind": "", "minutes": 0 };
    var diff = now.getTime() - ts;
    var d = new Date(ts);
    var kind;
    if (diff < 60000)
        kind = "now";
    else if (diff < 3600000)
        kind = "minutes";
    else if (d.toDateString() === now.toDateString())
        kind = "time";
    else if (diff < 6 * dayMs)
        kind = "weekday";
    else if (d.getFullYear() === now.getFullYear())
        kind = "date";
    else
        kind = "fullDate";
    return { "kind": kind, "minutes": Math.floor(diff / 60000) };
}

function historyRows(sessions, query, now) {
    var q = (query || "").trim().toLowerCase();
    var rows = [];
    var pinned = 0;
    var unpinnedIds = [];
    for (var i = 0; i < sessions.length; i++) {
        var s = sessions[i];
        var msgs = s.messages || [];
        if (msgs.length === 0)
            continue;
        if (s.pinned === true)
            pinned++;
        else
            unpinnedIds.push(String(s.id));

        var title = s.title || "New Chat";
        var preview = "";
        var previewIsUser = false;
        var matched = !q || title.toLowerCase().indexOf(q) !== -1;

        if (q) {
            for (var j = 0; j < msgs.length; j++) {
                var plain = plainPreview(msgs[j].text);
                var at = plain.toLowerCase().indexOf(q);
                if (at !== -1) {
                    var from = Math.max(0, at - 24);
                    preview = (from > 0 ? "…" : "") + plain.substring(from, at + q.length + 80);
                    matched = true;
                    break;
                }
            }
        }
        if (!matched)
            continue;
        if (!preview) {
            for (var k = msgs.length - 1; k >= 0; k--) {
                var last = plainPreview(msgs[k].text);
                if (last) {
                    preview = last.substring(0, 120);
                    previewIsUser = msgs[k].isUser === true;
                    break;
                }
            }
        }

        var isClaudeCode = s.provider === "claude-code" || !!s.claudeCodeSessionId;
        var ts = chatTimestamp(s);
        rows.push({
            "chatId": String(s.id),
            "title": title,
            "preview": preview,
            "previewIsUser": previewIsUser,
            "pinned": s.pinned === true,
            "ts": ts,
            "section": historySection(s.pinned === true, ts, now),
            "msgCount": msgs.length,
            "isClaudeCode": isClaudeCode,
            "cwd": isClaudeCode ? (s.claudeCodeCwd || "") : ""
        });
    }
    rows.sort((a, b) => (b.pinned - a.pinned) || (b.ts - a.ts));
    return {
        "rows": rows,
        "total": pinned + unpinnedIds.length,
        "pinned": pinned,
        "unpinnedIds": unpinnedIds
    };
}

function asMarkdown(session) {
    var parts = ["# " + (session.title || "Chat")];
    var msgs = session.messages || [];
    for (var i = 0; i < msgs.length; i++)
        if (msgs[i].text)
            parts.push("**" + (msgs[i].isUser ? "You" : "Assistant") + ":**\n\n" + msgs[i].text);
    return parts.join("\n\n");
}
