module snapper.app;
import std.logger;

import snapper.puzzle;
import snapper.search;
import snapper.tools;
import snapper.uci;

void main(string[] args) {
    sharedLog = cast(shared) new FileLogger("/tmp/engine_run.log", LogLevel.info);
    if (args.length > 1) {
        runTool(args);
        return;
    }
    // TODO: Increase log level to trace with a cmdline flag
    try {
        info("Starting engine");
        auto engine = new UciChessEngine();
        engine.run();
    } catch (Throwable e) {
        // We catch throwable here since we always want to try to fatal log
        fatal(e);
        throw e;
    }
}
