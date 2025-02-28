import std.algorithm;
import std.stdio;

import board;

class ChessAgent {
    ParsedFen currentBoard;
    File *logFile;

    this(File *logFile) {
        this.logFile = logFile;
    }

    void setPosition(string fen) {
        currentBoard = fen.findSplitAfter(" ")[1].parseFen;
        logFile.writeln("Parsed position:");
        logFile.writeln(currentBoard.board.getAsciiArtRepr);
        logFile.flush();
    }

    string bestMove(string opts) {
        switch (currentBoard.fullMove) {
        case 0:
            return "e7e5";
        case 1:
            return "d7d5";
        case 2:
            return "c7c5";
        default:
            return "b7b5";
        }
    }
}
