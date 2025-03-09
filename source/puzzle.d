module chess_engine.puzzle;

import std.algorithm;
import std.datetime;
import std.exception;
import std.format;
import std.stdio;
import std.range;
import chess_engine.agent;
import chess_engine.repr;
import chess_engine.search;


void check(string orig, string[] moves, Duration duration = 100.msecs) {
    ChessAgent agent = new ChessAgent;
    auto state = orig.parseFen;
    agent.handleUciPositionCommand("position fen " ~ state.toFen);
    void applyMove(string moveString) {
        auto move = moveString.parseMove;
        state = state.performMove(move).state;
    }
    foreach (pair; moves.chunks(2)) {
        auto expectedMove = pair[0];
        auto agentMove = agent.bestMove("", duration);
        enforce(expectedMove == agentMove, "Expected %s, got %s".format(expectedMove, agentMove));
        if (pair.length > 1) {
            applyMove(agentMove);
            applyMove(pair[1]);
            agent.handleUciPositionCommand("position fen " ~ state.toFen);
        }
    }
}

void runHeavyTests() {
    check("r2r2k1/1q3ppp/8/7P/6P1/3R4/B7/3R2K1 w - - 0 1", ["d3d8", "a8d8", "d1d8"]);
    writeln("All tests passed!");
}
