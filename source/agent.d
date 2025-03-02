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
        auto allMoves = currentBoard.validMoves();
        enforce(allMoves.length > 0);
        int multForPlayer = currentBoard.turn == Player.black ? -1 : 1;
        // Random
        // return allMoves[uniform(0, allMoves.length, rnd)].move.getRepr;
        // Best
        return allMoves[].maxElement!(a => a.eval * multForPlayer).move.getRepr;
    }
}
