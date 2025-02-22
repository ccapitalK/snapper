import std.algorithm;
import std.exception;
import std.stdio;

class ChessEngine {
    File outFile;
    bool pipeClosed = false;
    string lastCommand;

    this() {
         outFile = File("run.log", "w");
    }

    string readCommand() {
        string line;
        line = readln();
        if (line == "") {
            pipeClosed = true;
            outFile.write("Closed pipe");
        } else {
            outFile.write("Read: ", line);
        }
        lastCommand = line[0 .. $ - 1];
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
        outFile.write("Wrote: ", line);
        write(line);
        stdout.flush();
    }

    void run() {
        performHandshake();
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
