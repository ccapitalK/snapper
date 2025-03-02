import std.algorithm;
import std.exception;
import std.logger;
import std.stdio;

import agent;
import board;

class ChessEngine {
    ChessAgent agent;
    // XXX Use std.logging
    bool pipeClosed = false;
    string lastCommand;

    this() {
         this.agent = new ChessAgent();
    }

    string readCommand() {
        string line;
        line = readln();
        if (line == "") {
            pipeClosed = true;
            info("Closed pipe");
        } else {
            lastCommand = line[0 .. $ - 1];
            info("Read: ", lastCommand);
        }
        return lastCommand;
    }

    string expectCommand() {
        try {
            return readCommand();
        } finally {
            enforce(!pipeClosed, "Unexpected EOF");
        }
    }

    void sendCommand(string line) {
        enforce(line.length > 0 && line[$ - 1] == '\n');
        info("Wrote: ", line[0 .. $ - 1]);
        write(line);
        stdout.flush();
    }

    void run() {
        performHandshake();
        while (!pipeClosed) {
            auto command = readCommand();
            if (command.startsWith("position")) {
                auto fen = command.findSplitAfter(" ")[1];
                agent.setPosition(fen);
                continue;
            }
            if (command.startsWith("go")) {
                auto opts = command.findSplitAfter(" ")[1];
                auto move = agent.bestMove(opts);
                sendCommand("bestmove " ~ move ~ "\n");
            }
        }
        info("Pipe closed, exiting");
    }

    void performHandshake() {
        enforce(expectCommand() == "uci", "Driver is not a UCI chess frontend");
        sendCommand("id name Fax\n");
        sendCommand("id author ccapitalK\n");
        sendCommand("uciok\n");
        enforce(expectCommand() == "isready", "Unknown command in handshake");
        sendCommand("readyok\n");
    }
}

void main() {
    sharedLog = cast(shared) new FileLogger("run.log");
    // TODO: Increase log level to trace with a cmdline flag
    try {
        auto engine = new ChessEngine();
        engine.run();
    } catch (Throwable e) {
        // We catch throwable here since we always want to try to fatal log
        fatal(e);
        throw e;
    }
}
