module snapper.uci;

import std.algorithm;
import std.exception;
import std.logger;
import std.stdio;

import snapper.agent;
import snapper.opening_table;

class UciChessEngine {
    ChessAgent agent;
    bool pipeClosed = false;
    string lastCommand;

    this(string moveDatabaseData = null) {
        this.agent = new ChessAgent(MOVES_DB_STRING);
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
        while (true) {
            auto command = readCommand();
            if (pipeClosed || command.startsWith("quit")) {
                break;
            }
            if (command.startsWith("position")) {
                agent.handleUciPositionCommand(command);
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
        sendCommand("id name Snapper\n");
        sendCommand("id author ccapitalK\n");
        sendCommand("uciok\n");
        enforce(expectCommand() == "isready", "Unknown command in handshake");
        sendCommand("readyok\n");
    }
}
