.pragma library

var bypassMode = "bypassPermissions";

function parseModelList(text) {
    var ids = [];
    var seen = {};
    var lines = (text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var id = lines[i].trim();
        if (id === "" || seen[id])
            continue;
        if (/-\d{5,}$/.test(id) || /-0$/.test(id))
            continue;
        seen[id] = true;
        ids.push(id);
    }

    ids = ids.filter(id => !ids.some(other => other !== id && other.indexOf(id + "-") === 0));

    ids.sort((a, b) => {
        var va = (a.match(/\d+/g) || []).map(Number);
        var vb = (b.match(/\d+/g) || []).map(Number);
        for (var k = 0; k < Math.max(va.length, vb.length); k++) {
            var d = (vb[k] || 0) - (va[k] || 0);
            if (d !== 0)
                return d;
        }
        return a.localeCompare(b);
    });

    return ["default"].concat(ids);
}

function effortLevelsFor(model) {
    var m = String(model || "default").toLowerCase();
    if (m === "haiku")
        return [];
    if (m === "default" || m === "opus" || m === "sonnet" || m === "fable")
        return ["low", "medium", "high", "xhigh", "max"];

    var fam = m.indexOf("opus") !== -1 ? "opus"
            : m.indexOf("sonnet") !== -1 ? "sonnet"
            : m.indexOf("haiku") !== -1 ? "haiku"
            : m.indexOf("fable") !== -1 ? "fable" : "";
    var nums = (m.match(/\d+/g) || []).map(Number);
    var major = nums.length >= 1 ? nums[0] : 0;
    var minor = nums.length >= 2 ? nums[1] : 0;

    if (fam === "haiku")
        return [];
    if (fam === "fable")
        return ["low", "medium", "high", "xhigh", "max"];
    if (fam === "opus") {
        if (major > 4 || (major === 4 && minor >= 7))
            return ["low", "medium", "high", "xhigh", "max"];
        if (major === 4 && minor === 6)
            return ["low", "medium", "high", "max"];
        if (major === 4 && minor === 5)
            return ["low", "medium", "high"];
        return [];
    }
    if (fam === "sonnet") {
        if (major >= 5)
            return ["low", "medium", "high", "xhigh", "max"];
        if (major === 4 && minor === 6)
            return ["low", "medium", "high", "max"];
        return [];
    }
    return [];
}

function effectivePermissionMode(mode, bypassAllowed) {
    mode = mode || (bypassAllowed ? bypassMode : "default");
    if (mode === bypassMode && !bypassAllowed)
        return "default";
    return mode;
}

function permissionArgs(mode, bypassAllowed, sidebarAllowedTools) {
    mode = effectivePermissionMode(mode, bypassAllowed);
    if (mode === bypassMode)
        return ["--dangerously-skip-permissions"];
    if (mode === "default")
        return [];
    var args = ["--permission-mode", mode];
    if (mode === "acceptEdits")
        args = args.concat(["--allowedTools", sidebarAllowedTools.join(",")]);
    return args;
}

function replyCommand(opts) {
    var cmd = [opts.bin, "-p", opts.prompt];

    var dirs = [];
    var attachments = opts.attachments || [];
    for (var a = 0; a < attachments.length; a++) {
        var d = attachments[a].replace(/\/[^\/]*$/, "") || "/";
        if (dirs.indexOf(d) === -1)
            dirs.push(d);
    }
    if (dirs.length > 0)
        cmd = cmd.concat(["--add-dir"], dirs);

    cmd = cmd.concat(["--output-format", "stream-json", "--verbose", "--include-partial-messages"]);
    cmd = cmd.concat(permissionArgs(opts.permissionMode, opts.bypassAllowed, opts.allowedTools || []));

    var model = opts.model || "default";
    if (model !== "default")
        cmd.push("--model", model);

    var effort = opts.effort || "default";
    if (effort !== "default" && effortLevelsFor(model).indexOf(effort) !== -1)
        cmd.push("--effort", effort);

    if (opts.sessionId)
        cmd.push("--resume", opts.sessionId);
    return cmd;
}

function withAttachmentList(text, paths) {
    if (!paths || paths.length === 0)
        return text;
    return ((text || "").trim() + "\n\nAttached files (use the Read tool to view them):\n"
        + paths.map(p => "- " + p).join("\n")).trim();
}

function transcript(messages) {
    var lines = [];
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (!m.isUser && !m.isFinished)
            continue;
        var t = (m.text || "").trim();
        if (m.isUser && (m.attachments || "") !== "")
            t = withAttachmentList(t, m.attachments.split("\n"));
        if (t === "")
            continue;
        lines.push((m.isUser ? "User: " : "Assistant: ") + t);
    }
    if (lines.length <= 1)
        return "";
    return "Continue this conversation. Conversation so far:\n\n" + lines.join("\n\n") + "\n\nReply to the last user message.";
}

function isAgentTool(name) {
    return name === "Agent" || name === "Task";
}

function toolSummary(name, input) {
    if (!input)
        return "";
    if (isAgentTool(name))
        return input.description || "";
    var s = input.command || input.skill || input.file_path || input.notebook_path || input.pattern
        || input.url || input.query || input.description || input.prompt || "";
    if (s === "" && name === "TodoWrite" && Array.isArray(input.todos))
        s = input.todos.length + " todos";
    if (s === "") {
        try {
            s = JSON.stringify(input);
        } catch (e) {}
    }
    s = String(s).replace(/\s+/g, " ").trim();
    return s.length > 200 ? s.substring(0, 200) + "…" : s;
}

function shortPaths(text, home) {
    if (!text || !home)
        return text || "";
    return String(text).split(home + "/").join("~/");
}

function toolResultText(content) {
    var t = "";
    if (typeof content === "string")
        t = content;
    else if (Array.isArray(content))
        for (var i = 0; i < content.length; i++) {
            if (content[i].type === "text")
                t += (t ? "\n" : "") + (content[i].text || "");
            else if (content[i].type === "image")
                t += (t ? "\n" : "") + "[image]";
        }
    t = t.trim();
    return t.length > 2000 ? t.substring(0, 2000) + "\n…" : t;
}

function formatTokens(n) {
    n = n || 0;
    if (n >= 1000000)
        return (n / 1000000).toFixed(1) + "M";
    if (n >= 1000)
        return (n / 1000).toFixed(1) + "k";
    return String(n);
}

function agentStatsText(t) {
    var parts = [];
    if (t.toolUses)
        parts.push(t.toolUses + (t.toolUses === 1 ? " tool" : " tools"));
    if (t.tokens)
        parts.push(formatTokens(t.tokens) + " tokens");
    if (t.durationMs)
        parts.push((t.durationMs / 1000).toFixed(1) + "s");
    return parts.join(" · ");
}

function mergeResultUsage(prev, evt) {
    if (!prev)
        return evt;
    var a = prev.usage || {};
    var b = evt.usage || {};
    return {
        duration_ms: (prev.duration_ms || 0) + (evt.duration_ms || 0),
        num_turns: (prev.num_turns || 0) + (evt.num_turns || 0),
        usage: {
            input_tokens: (a.input_tokens || 0) + (b.input_tokens || 0),
            cache_read_input_tokens: (a.cache_read_input_tokens || 0) + (b.cache_read_input_tokens || 0),
            cache_creation_input_tokens: (a.cache_creation_input_tokens || 0) + (b.cache_creation_input_tokens || 0),
            output_tokens: (a.output_tokens || 0) + (b.output_tokens || 0)
        },
        total_cost_usd: typeof evt.total_cost_usd === "number" ? evt.total_cost_usd : prev.total_cost_usd
    };
}

function usageSummary(evt) {
    var parts = [];
    if (evt.duration_ms)
        parts.push((evt.duration_ms / 1000).toFixed(1) + "s");
    if (evt.num_turns)
        parts.push(evt.num_turns + (evt.num_turns === 1 ? " turn" : " turns"));
    var u = evt.usage;
    if (u) {
        var inTok = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
        parts.push(formatTokens(inTok) + " in / " + formatTokens(u.output_tokens) + " out");
    }
    if (typeof evt.total_cost_usd === "number")
        parts.push("$" + evt.total_cost_usd.toFixed(evt.total_cost_usd < 1 ? 3 : 2));
    return parts.join(" · ");
}

function isAuthError(text) {
    if (!text)
        return false;
    var t = String(text).toLowerCase();
    var needles = ["login", "log in", "logged in", "not authenticated", "unauthorized", "authentication",
        "oauth", "invalid api key", "api key", "expired", "sign in", "credentials"];
    return needles.some(n => t.indexOf(n) !== -1);
}

var authHint = "It appears that Claude is not logged into your account.\n\nOpen a terminal, run the command `claude`, and log in with your subscription, then try again here.";

function createState() {
    return {
        acc: "",
        thought: "",
        sessionId: "",
        errAcc: "",
        usage: "",
        resultUsage: null,
        tools: [],
        needSep: false,
        thoughtSep: false,
        doneTokens: 0,
        agentOf: {},
        msgChars: 0,
        done: false
    };
}

function findTool(st, id) {
    for (var i = 0; i < st.tools.length; i++)
        if (st.tools[i].id === id)
            return st.tools[i];
    return null;
}

function textPos(st) {
    return st.acc.trim().length;
}

function newTool(st, id, name) {
    return { id: id, name: name || "tool", summary: "", result: "", isError: false, done: false, at: textPos(st) };
}

function agentCardFor(st, parentId) {
    return findTool(st, st.agentOf[parentId] || parentId);
}

function appendText(st, text, out) {
    if (!text)
        return;
    if (st.needSep && st.acc.trim() !== "")
        st.acc = st.acc.replace(/\s+$/, "") + "\n\n";
    st.needSep = false;
    st.acc += text;
    out.push({ type: "text", text: st.acc.trim() });
}

function handleLine(st, line) {
    var out = [];
    line = (line || "").trim();
    if (line === "")
        return out;

    var evt;
    try {
        evt = JSON.parse(line);
    } catch (e) {
        return out;
    }

    if (evt.session_id)
        st.sessionId = evt.session_id;

    if (evt.type === "system")
        handleTaskEvent(st, evt, out);
    else if (evt.parent_tool_use_id)
        handleSubagentEvent(st, evt, out);
    else if (evt.type === "stream_event" && evt.event)
        handleStreamEvent(st, evt.event, out);
    else if (evt.type === "assistant" && evt.message && evt.message.content)
        handleAssistantMessage(st, evt.message.content, out);
    else if (evt.type === "user" && evt.message && Array.isArray(evt.message.content))
        handleToolResults(st, evt, out);
    else if (evt.type === "result")
        handleResult(st, evt, out);
    return out;
}

function handleStreamEvent(st, ev, out) {
    if (ev.type === "message_start") {
        st.needSep = true;
        st.msgChars = 0;
    } else if (ev.type === "message_delta" && ev.usage && ev.usage.output_tokens) {
        st.doneTokens += ev.usage.output_tokens;
        st.msgChars = 0;
        out.push({ type: "tokens", count: st.doneTokens });
    } else if (ev.type === "content_block_start" && ev.content_block) {
        var cb = ev.content_block;
        if (cb.type === "thinking")
            st.thoughtSep = true;
        if (cb.type === "tool_use") {
            st.needSep = true;
            if (!findTool(st, cb.id)) {
                st.tools.push(newTool(st, cb.id, cb.name));
                out.push({ type: "tools", tools: st.tools });
            }
            out.push({ type: "toolStarted", name: cb.name || "tool" });
        }
    } else if (ev.type === "content_block_delta" && ev.delta) {
        st.msgChars += (ev.delta.text || ev.delta.thinking || ev.delta.partial_json || "").length;
        out.push({ type: "tokens", count: st.doneTokens + Math.round(st.msgChars / 3) });
        if (ev.delta.type === "text_delta") {
            appendText(st, ev.delta.text || "", out);
        } else if (ev.delta.type === "thinking_delta") {
            if (st.thoughtSep && st.thought.trim() !== "")
                st.thought = st.thought.replace(/\s+$/, "") + "\n\n";
            st.thoughtSep = false;
            st.thought += ev.delta.thinking || "";
            out.push({ type: "thought", text: st.thought.trim() });
        }
    }
}

function handleAssistantMessage(st, content, out) {
    var hasTool = false;
    for (var i = 0; i < content.length; i++) {
        var b = content[i];
        if (b.type === "tool_use") {
            hasTool = true;
            var t = findTool(st, b.id);
            if (!t) {
                t = newTool(st, b.id, b.name);
                st.tools.push(t);
            }
            t.summary = toolSummary(b.name, b.input);
            if (b.name)
                out.push({ type: "toolStarted", name: b.name });
        } else if (b.type === "text") {
            var bt = (b.text || "").trim();
            if (bt !== "" && st.acc.indexOf(bt) === -1) {
                st.needSep = true;
                appendText(st, b.text, out);
            }
        }
    }
    if (hasTool)
        out.push({ type: "tools", tools: st.tools });
}

function handleToolResults(st, evt, out) {
    var changed = false;
    var content = evt.message.content;
    for (var j = 0; j < content.length; j++) {
        var r = content[j];
        if (r.type !== "tool_result")
            continue;
        var tr = findTool(st, r.tool_use_id);
        if (!tr)
            continue;
        tr.result = toolResultText(r.content);
        var tur = evt.tool_use_result;
        if (isAgentTool(tr.name) && tur && tur.isAsync === true) {
            tr.result = "";
            tr.async = true;
            changed = true;
            continue;
        }
        if (isAgentTool(tr.name) && tur && typeof tur === "object") {
            if (tur.content)
                tr.result = toolResultText(tur.content);
            tr.toolUses = tur.totalToolUseCount || tr.toolUses || 0;
            tr.tokens = tur.totalTokens || tr.tokens || 0;
            tr.durationMs = tur.totalDurationMs || tr.durationMs || 0;
        }
        tr.isError = r.is_error === true;
        tr.done = true;
        tr.progress = "";
        changed = true;
    }
    if (changed) {
        out.push({ type: "tools", tools: st.tools });
        out.push({ type: "toolsDone" });
    }
}

function handleResult(st, evt, out) {
    var resText = (evt.result !== undefined && evt.result !== null) ? String(evt.result) : "";
    var errored = (evt.is_error === true) || (evt.subtype && String(evt.subtype).indexOf("error") !== -1);
    st.resultUsage = mergeResultUsage(st.resultUsage, evt);
    st.usage = usageSummary(st.resultUsage);
    if (st.done) {
        out.push({ type: "usage", text: st.usage });
        return;
    }
    if (!errored && st.tools.some(t => t.async && !t.done))
        return;
    if (errored && (isAuthError(resText) || isAuthError(st.errAcc)))
        st.acc = authHint;
    else if (st.acc.trim() === "" && resText !== "")
        st.acc = resText;
    else if (errored && resText !== "" && st.acc.indexOf(resText) === -1)
        st.acc = st.acc.replace(/\s+$/, "") + "\n\n⚠️ " + resText;
    out.push({ type: "finished", reply: finish(st) });
}

function handleTaskEvent(st, evt, out) {
    if (!evt.tool_use_id || String(evt.subtype || "").indexOf("task_") !== 0)
        return;
    var t = findTool(st, evt.tool_use_id);
    if (!t) {
        var top = agentCardFor(st, evt.tool_use_id);
        if (top && top.id !== evt.tool_use_id && evt.description && evt.subtype === "task_progress") {
            top.progress = evt.description;
            out.push({ type: "tools", tools: st.tools });
        }
        return;
    }
    if (evt.subagent_type)
        t.agentType = evt.subagent_type;
    if (evt.subtype === "task_progress" && evt.description)
        t.progress = evt.description;
    if (evt.usage) {
        t.toolUses = evt.usage.tool_uses || t.toolUses || 0;
        t.tokens = evt.usage.total_tokens || t.tokens || 0;
        t.durationMs = evt.usage.duration_ms || t.durationMs || 0;
    }
    if (evt.subtype === "task_notification") {
        if (evt.status && evt.status !== "completed")
            t.isError = true;
        if (t.async && !t.done) {
            t.result = evt.summary || "";
            t.done = true;
            t.progress = "";
            var st2 = t.steps || [];
            for (var k = 0; k < st2.length; k++)
                st2[k].done = true;
        }
    }
    if (evt.subtype === "task_progress" && t.progress)
        out.push({ type: "progress", text: t.progress });
    out.push({ type: "tools", tools: st.tools });
}

function handleSubagentEvent(st, evt, out) {
    var card = agentCardFor(st, evt.parent_tool_use_id);
    if (!card || !evt.message || !Array.isArray(evt.message.content))
        return;
    if (!card.steps)
        card.steps = [];
    var changed = false;
    for (var i = 0; i < evt.message.content.length; i++) {
        var b = evt.message.content[i];
        if (evt.type === "assistant" && b.type === "tool_use") {
            st.agentOf[b.id] = card.id;
            card.steps.push({ id: b.id, name: b.name || "tool", summary: toolSummary(b.name, b.input), done: false, isError: false });
            changed = true;
        } else if (evt.type === "user" && b.type === "tool_result") {
            for (var j = 0; j < card.steps.length; j++)
                if (card.steps[j].id === b.tool_use_id) {
                    card.steps[j].done = true;
                    card.steps[j].isError = b.is_error === true;
                    changed = true;
                }
        }
    }
    if (card.steps.length > 30)
        card.steps = card.steps.slice(card.steps.length - 30);
    if (changed)
        out.push({ type: "tools", tools: st.tools });
}

function finish(st) {
    st.done = true;
    for (var i = 0; i < st.tools.length; i++) {
        st.tools[i].done = true;
        st.tools[i].progress = "";
        var steps = st.tools[i].steps || [];
        for (var k = 0; k < steps.length; k++)
            steps[k].done = true;
    }
    return { text: st.acc.trim(), tools: st.tools, usage: st.usage, sessionId: st.sessionId };
}

function handleExit(st, code, stopped) {
    if (st.done)
        return null;
    if (st.acc.trim() === "" && !stopped) {
        if (isAuthError(st.errAcc)) {
            st.acc = authHint;
        } else if (code !== 0) {
            var err = st.errAcc.trim();
            var lines = err.split("\n");
            if (lines.length > 20)
                err = lines.slice(lines.length - 20).join("\n");
            st.acc = "⚠️ Claude Code exited with code " + code + "."
                + (err !== "" ? "\n\n```\n" + err + "\n```" : "\n\nIs the `claude` CLI installed and logged in? Try running `claude` in a terminal.");
        }
    }
    return finish(st);
}
