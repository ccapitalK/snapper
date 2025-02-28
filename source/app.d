import std.algorithm;
import std.exception;
import std.stdio;

import agent;
import board;

class ChessEngine {
    ChessAgent agent;
    // XXX Use std.logging
    File logFile;
    bool pipeClosed = false;
    string lastCommand;

    this() {
         logFile = File("run.log", "w");
         this.agent = new ChessAgent(&logFile);
    }

    string readCommand() {
        string line;
        line = readln();
        if (line == "") {
            pipeClosed = true;
            logFile.write("Closed pipe");
            logFile.flush();
        } else {
            logFile.write("Read: ", line);
            logFile.flush();
            lastCommand = line[0 .. $ - 1];
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
        logFile.write("Wrote: ", line);
        logFile.flush();
        write(line);
        stdout.flush();
    }

    void run() {
        performHandshake();
        while (true) {
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
    auto engine = new ChessEngine();
    engine.run();
}
