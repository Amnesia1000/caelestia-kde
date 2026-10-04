#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: runtime-smoke.sh --install-root PATH [options]

Options:
  --install-root PATH  Installed tree containing etc/xdg and usr/lib/qt6/qml
  --runs COUNT         Number of launch and shutdown cycles (default: 3)
  --timeout SECONDS    Per-cycle readiness timeout (default: 30)
    --max-startup-ms N   Fail when a cycle exceeds this startup time
    --max-rss-kb N       Fail when a cycle exceeds this resident memory
    --max-ipc-ms N       Fail when an IPC interaction exceeds this latency
    --baseline PATH      JSON file containing max_startup_ms, max_rss_kb, and max_ipc_ms
  --log-dir PATH       Directory for Weston and Quickshell logs
EOF
}

install_root=
runs=3
timeout_seconds=30
max_startup_ms=
max_rss_kb=
max_ipc_limit_ms=
baseline=
log_dir=

while (($#)); do
    case "$1" in
        --install-root)
            install_root=${2:?missing value for --install-root}
            shift 2
            ;;
        --runs)
            runs=${2:?missing value for --runs}
            shift 2
            ;;
        --timeout)
            timeout_seconds=${2:?missing value for --timeout}
            shift 2
            ;;
        --max-startup-ms)
            max_startup_ms=${2:?missing value for --max-startup-ms}
            shift 2
            ;;
        --max-rss-kb)
            max_rss_kb=${2:?missing value for --max-rss-kb}
            shift 2
            ;;
        --max-ipc-ms)
            max_ipc_limit_ms=${2:?missing value for --max-ipc-ms}
            shift 2
            ;;
        --baseline)
            baseline=${2:?missing value for --baseline}
            shift 2
            ;;
        --log-dir)
            log_dir=${2:?missing value for --log-dir}
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$install_root" ]]; then
    echo "--install-root is required" >&2
    usage >&2
    exit 2
fi

if ! [[ "$runs" =~ ^[1-9][0-9]*$ && "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
    echo "--runs and --timeout must be positive integers" >&2
    exit 2
fi
if [[ -n "$max_startup_ms" && ! "$max_startup_ms" =~ ^[1-9][0-9]*$ ]] || \
    [[ -n "$max_rss_kb" && ! "$max_rss_kb" =~ ^[1-9][0-9]*$ ]] || \
    [[ -n "$max_ipc_limit_ms" && ! "$max_ipc_limit_ms" =~ ^[1-9][0-9]*$ ]]; then
    echo "performance limits must be positive integers" >&2
    exit 2
fi
if [[ -n "$baseline" ]]; then
    [[ -f "$baseline" ]] || { echo "baseline not found: $baseline" >&2; exit 2; }
    baseline_value() {
        python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' "$baseline" "$1"
    }
    max_startup_ms=${max_startup_ms:-$(baseline_value max_startup_ms)}
    max_rss_kb=${max_rss_kb:-$(baseline_value max_rss_kb)}
    max_ipc_limit_ms=${max_ipc_limit_ms:-$(baseline_value max_ipc_ms)}
fi

for command_name in dbus-run-session quickshell weston; do
    command -v "$command_name" >/dev/null || {
        echo "required runtime command not found: $command_name" >&2
        exit 2
    }
done

config_path="$install_root/etc/xdg/quickshell/caelestia/shell.qml"
qml_import_path="$install_root/usr/lib/qt6/qml"
[[ -f "$config_path" ]] || { echo "installed shell not found: $config_path" >&2; exit 2; }
[[ -d "$qml_import_path" ]] || { echo "installed QML imports not found: $qml_import_path" >&2; exit 2; }

if [[ -z "$log_dir" ]]; then
    log_dir=$(mktemp -d)
    remove_log_dir=1
else
    mkdir -p "$log_dir"
    remove_log_dir=0
fi

runtime_dir=$(mktemp -d)
chmod 700 "$runtime_dir"
weston_pid=

cleanup() {
    if [[ -n "$weston_pid" ]] && kill -0 "$weston_pid" 2>/dev/null; then
        kill "$weston_pid" 2>/dev/null || true
        wait "$weston_pid" 2>/dev/null || true
    fi
    rm -rf "$runtime_dir"
    if ((remove_log_dir)); then
        rm -rf "$log_dir"
    fi
}
trap cleanup EXIT INT TERM

export XDG_RUNTIME_DIR="$runtime_dir"
export XDG_CONFIG_HOME="$install_root/etc/xdg"
export XDG_STATE_HOME="$runtime_dir/state"
export QML2_IMPORT_PATH="$qml_import_path"
export QT_QPA_PLATFORM=wayland
export CAELESTIA_RUNTIME_TEST=1
export LD_LIBRARY_PATH="$install_root/usr/lib/caelestia${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$XDG_STATE_HOME/caelestia"
printf '{invalid scheme state' >"$XDG_STATE_HOME/caelestia/scheme.json"

weston --backend=headless-backend.so --socket=wayland-runtime --idle-time=0 \
    >"$log_dir/weston.log" 2>&1 &
weston_pid=$!

for _ in {1..50}; do
    [[ -S "$runtime_dir/wayland-runtime" ]] && break
    sleep 0.1
done
[[ -S "$runtime_dir/wayland-runtime" ]] || {
    echo "Weston did not create a Wayland socket" >&2
    exit 1
}

now_ms() {
    date +%s%3N
}

ipc_call() {
    echo "runtime IPC: $*" >&2
    ipc_start_ms=$(now_ms)
    if ! quickshell ipc --path "$config_path" --newest --any-display call "$@" >/dev/null; then
        echo "runtime IPC failed: $*" >&2
        return 1
    fi
    ipc_elapsed_ms=$(( $(now_ms) - ipc_start_ms ))
    ((ipc_elapsed_ms > max_ipc_ms)) && max_ipc_ms=$ipc_elapsed_ms
}

ipc_try() {
    ipc_call "$@" 2>/dev/null || true
}

printf '{"runs":%d,"results":[' "$runs"
for ((run = 1; run <= runs; run++)); do
    log_file="$log_dir/quickshell-$run.log"
    max_ipc_ms=0
    start_ms=$(now_ms)
    dbus-run-session -- env WAYLAND_DISPLAY=wayland-runtime \
        timeout "$timeout_seconds" quickshell --no-color --log-times \
        --path "$config_path" >"$log_file" 2>&1 &
    quickshell_pid=$!
    ready=0
    while kill -0 "$quickshell_pid" 2>/dev/null; do
        if grep -Fq 'Configuration Loaded' "$log_file"; then
            ready=1
            break
        fi
        if (( $(now_ms) - start_ms >= timeout_seconds * 1000 )); then
            break
        fi
        sleep 0.1
    done
    end_ms=$(now_ms)
    startup_ms=$((end_ms - start_ms))

    if ((ready == 0)); then
        echo >&2
        echo "runtime smoke run $run did not reach Configuration Loaded" >&2
        cat "$log_file" >&2
        kill "$quickshell_pid" 2>/dev/null || true
        wait "$quickshell_pid" 2>/dev/null || true
        exit 1
    fi

    for drawer in launcher sidebar dashboard utilities overview session; do
        ipc_try drawers toggle "$drawer"
        ipc_try drawers toggle "$drawer"
    done
    ipc_try notifs toggleDnd
    ipc_try notifs toggleDnd
    ipc_try notifs clear
    ipc_try wallpaper get
    ipc_try wallpaper list
    ipc_try plugins count
    ipc_try nexus open
    ipc_try nexus openPage 0 -1
    ipc_try nexus open
    ipc_try nexus close
    ipc_try nexus open
    ipc_try nexus close

    shell_pid=$(pgrep -n -f "quickshell.*${config_path}" || true)
    rss_kb=0
    idle_cpu_percent=0
    sleep 2
    if [[ -n "$shell_pid" && -r "/proc/$shell_pid/status" ]]; then
        rss_kb=$(awk '/VmRSS:/ {print $2}' "/proc/$shell_pid/status")
        idle_cpu_percent=$(ps -p "$shell_pid" -o %cpu= | tr -d ' ')
    fi
    for marker in 'Configuration Loaded' '[perf] bar-ready' '[perf] wallpaper-ready' '[perf] shortcuts-ready' \
        '[Preload] Utilities loaded successfully' '[perf][ContextMenuStore] load disk' \
        '[perf][DesktopContextMenu] build model' \
        '[lifecycle] nexus=created' '[lifecycle] nexus=reused' '[lifecycle] nexus=destroyed' \
        '[lifecycle] drawer=launcher toggled' '[lifecycle] drawer=sidebar toggled' \
        '[lifecycle] drawer=dashboard toggled' '[lifecycle] drawer=utilities toggled' \
        '[lifecycle] drawer=overview toggled' '[lifecycle] drawer=session toggled'; do
        grep -Fq "$marker" "$log_file" || {
            echo "runtime smoke run $run missed readiness marker: $marker" >&2
            cat "$log_file" >&2
            exit 1
        }
    done
    for marker in '[lifecycle] nexus=created' '[lifecycle] nexus=reused' '[lifecycle] nexus=destroyed' \
        '[lifecycle] drawer=launcher toggled' '[lifecycle] drawer=sidebar toggled' \
        '[lifecycle] drawer=dashboard toggled' '[lifecycle] drawer=utilities toggled' \
        '[lifecycle] drawer=overview toggled' '[lifecycle] drawer=session toggled'; do
        marker_count=$(grep -Fc "$marker" "$log_file" || true)
        if ((marker_count < 2)); then
            echo "runtime smoke run $run did not observe two lifecycle events: $marker" >&2
            cat "$log_file" >&2
            exit 1
        fi
    done
    if grep -Eq 'ERROR: Failed to load configuration|Cannot load library|Type .* unavailable' "$log_file"; then
        echo "runtime smoke run $run reported a fatal QML/plugin error" >&2
        grep -E 'ERROR: Failed to load configuration|Cannot load library|Type .* unavailable' "$log_file" >&2
        exit 1
    fi

    kill "$quickshell_pid" 2>/dev/null || true
    wait "$quickshell_pid" 2>/dev/null || true
    if [[ -n "$max_startup_ms" && "$startup_ms" -gt "$max_startup_ms" ]]; then
        echo "runtime smoke run $run exceeded startup limit: ${startup_ms}ms > ${max_startup_ms}ms" >&2
        exit 1
    fi
    if [[ -n "$max_rss_kb" && "$rss_kb" -gt "$max_rss_kb" ]]; then
        echo "runtime smoke run $run exceeded RSS limit: ${rss_kb}KiB > ${max_rss_kb}KiB" >&2
        exit 1
    fi
    if [[ -n "$max_ipc_limit_ms" && "$max_ipc_ms" -gt "$max_ipc_limit_ms" ]]; then
        echo "runtime smoke run $run exceeded IPC limit: ${max_ipc_ms}ms > ${max_ipc_limit_ms}ms" >&2
        exit 1
    fi
    ((run > 1)) && printf ','
    scenario=cold
    ((run > 1)) && scenario=warm
    printf '{"run":%d,"scenario":"%s","startup_ms":%d,"rss_kb":%d,"idle_cpu_percent":"%s","max_ipc_ms":%d}' \
        "$run" "$scenario" "$startup_ms" "$rss_kb" "$idle_cpu_percent" "$max_ipc_ms"
done
printf '],"log_dir":"%s"}\n' "$log_dir"
