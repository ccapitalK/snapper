module chess_engine.agent;

import std.algorithm;
import std.exception;
import std.logger;
import std.random;
import std.stdio;

import chess_engine.repr;
import chess_engine.search;

class ChessAgent {
    Mt19937 rnd;
    GameState currentBoard;

    this() {
        rnd.seed(1337);
    }

    void setPosition(string fen) {
        currentBoard = fen.findSplitAfter(" ")[1].parseFen;
        info("Parsed position:");
        info("\n" ~ currentBoard.board.getAsciiArtRepr);
    }

    string bestMove(string opts) {
        auto allMoves = currentBoard.validMoves();
        enforce(allMoves.length > 0);
        // Random
        // return allMoves[uniform(0, allMoves.length, rnd)].move.getRepr;
        // Best
        return currentBoard.pickBestMove().move.getRepr;
    }
}
