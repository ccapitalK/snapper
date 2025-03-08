module chess_engine.agent;

import core.atomic;
import core.thread;
import core.time;
import std.algorithm;
import std.exception;
import std.logger;
import std.parallelism;
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
        // Random
        // return allMoves[uniform(0, allMoves.length, rnd)].move.getRepr;
        // Best
        immutable string encoded = currentBoard.toFen();
        auto context = new shared SearchContext;
        auto searchTask = task(&getBestMove, context, encoded);
        searchTask.executeInNewThread();
        Thread.sleep(3.seconds);
        context.isStopped.atomicStore(true);
        return searchTask.yieldForce;
    }
}

string getBestMove(shared SearchContext *context, immutable string fenBoard) {
    auto board = fenBoard.parseFen;
    return board.pickBestMoveIterativeDeepening(context).move.getRepr;
}
