pragma Singleton

import QtQuick

QtObject {
    // Marks are emitted unconditionally rather than behind a test-only flag:
    // tests/runtime-smoke.sh asserts on them from an ordinary install, and the
    // shell already logs its startup timings the same way.
    function mark(name: string): void {
        console.info(`[caelestia] ${name}`);
    }
}
