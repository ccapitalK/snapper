import std.algorithm;
import std.exception;
import std.logger;
import std.random;
import std.stdio;

import board;

class ChessAgent {
    Mt19937 rnd;
    GameState currentBoard;

    this() {
        rnd.seed(1337);
    }

    void setPosition(string fen) {
        currentBoard = fen.findSplitAfter(" ")[1].parseFen;
        info("Parsed position:");
        info(currentBoard.board.getAsciiArtRepr);
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
