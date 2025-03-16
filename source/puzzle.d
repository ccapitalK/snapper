module snapper.puzzle;

import std.algorithm;
import std.datetime;
import std.exception;
import std.format;
import std.parallelism;
import std.range;
import std.random;
import std.stdio;
import snapper.agent;
import snapper.repr;
import snapper.search;

struct HeavyTest {
    string origFen;
    string[] expectedMoves;
    Duration duration = 100.msecs;
}

void check(const ref HeavyTest test) {
    ChessAgent agent = new ChessAgent;
    auto state = test.origFen.parseFen;
    agent.handleUciPositionCommand("position fen " ~ state.toFen);
    void applyMove(string moveString) {
        auto move = moveString.parseMove;
        state = state.performMove(move).state;
    }

    foreach (pair; test.expectedMoves.chunks(2)) {
        auto expectedMove = pair[0];
        auto agentMove = agent.bestMove("", test.duration);
        enforce(expectedMove == agentMove, "%s: Expected %s, got %s".format(test, expectedMove, agentMove));
        if (pair.length > 1) {
            applyMove(agentMove);
            applyMove(pair[1]);
            agent.handleUciPositionCommand("position fen " ~ state.toFen);
        }
    }
}

void runHeavyTests() {
    auto rnd = Mt19937(1337);
    HeavyTest[] tests;
    // Random simple puzzles
    tests ~= HeavyTest("r2r2k1/1q3ppp/8/7P/6P1/3R4/B7/3R2K1 w - - 0 1", [
        "d3d8", "a8d8", "d1d8"
    ]);
    tests ~= HeavyTest("5q1k/7p/6pP/p7/1pp5/2P5/PPB2R1P/5K2 w - - 1 39", [
        "f2f8"
    ]);
    tests ~= HeavyTest("6k1/5ppp/p2pp3/6P1/2r1bP1P/2N5/PPR5/1K6 w - - 1 2", [
        "c3e4", "c4c2", "b1c2"
    ]);
    tests ~= HeavyTest("8/5ppp/1R2p3/2p5/k1K5/8/5r1P/8 w - - 0 33", ["b6a6"]);
    tests ~= HeavyTest("B4rk1/5ppp/3b2q1/pp6/3P1n2/P1P2N1P/5P1K/R1BQ1R2 b - - 2 20", [
        "g6g2"
    ]);
    tests ~= HeavyTest("B4rk1/5ppp/3b2q1/pp6/3P1n2/P1P2N1P/5P1K/R1BQ1R2 b - - 2 20", [
        "g6g2"
    ]);
    tests ~= HeavyTest("r4rk1/1p1Q3p/pqp3p1/8/1P6/P6p/2P2P1P/3RR1K1 b - - 3 23", [
        "b6f2", "g1h1", "f2g2"
    ]);
    tests ~= HeavyTest("r4r1k/ppp3bp/4Q1p1/6q1/4bB2/3B4/PPP2PPP/3RR1K1 b - - 0 21", [
        "g5g2"
    ]);
    tests ~= HeavyTest("1nb1kb1r/2pp3p/1p2p1p1/pP6/4BPn1/B1P3P1/P2PN2q/RN1QK1R1 b Qk - 1 17", [
        "h2f2"
    ]);
    // Queen promotion checkmate
    tests ~= HeavyTest("8/p3Pkb1/5p2/2B5/2P2P2/7q/PP2R1p1/6K1 w - - 0 42", [
        "e7e8q"
    ]);
    // Knight Promotion checkmate
    tests ~= HeavyTest("nN6/knP5/nr6/8/8/6B1/8/4K3 w - - 0 1", ["c7c8n"]);
    tests ~= HeavyTest("8/8/6q1/8/8/4NQ2/4K1pk/8 b - - 5 1", ["g2g1n", "e2f2", "g1f3"]);
    tests ~= HeavyTest("5rk1/2p1p2n/p1pqN2Q/5bpp/8/1P6/P1P3PP/5R1K w - - 2 26", [
        "h6g7"
    ]);
    tests ~= HeavyTest("kr6/p1n2pp1/8/2Q1p3/2P1Pn2/P4P2/6P1/5KBr w - - 1 31", [
        "c5a7"
    ]);

    // Difficult, re-enable some time in the future
    tests ~= HeavyTest("5rk1/ppR2ppp/3N1n2/4p3/3p4/1Q1P2Pq/PP2PP1P/6K1 b - - 1 1", [
        "f6g4", "b3f7", "f8f7", "c7c8", "f7f8", "c8f8", "g8f8", "d6b7", "h3h2"
    ], 1.seconds);

    tests ~= HeavyTest("5rk1/p5p1/1p1N2Q1/3qp3/8/8/P5RP/7K b - - 1 36", ["f8f1"]);
    tests ~= HeavyTest("2kr1b1r/ppp4q/3p1p2/1P1PpPp1/4B1p1/P2P2P1/5P2/R1BQ1RK1 b - - 2 19", [
        "h7h2"
    ]);
    tests ~= HeavyTest("r1bqr1k1/1pppnp1p/p1n3p1/4p3/2B1P3/P2P1Q2/1PP1NPPP/R3K2R w KQ - 0 12", [
        "f3f7", "g8h8", "f7f6"
    ], 300.msecs);
    tests ~= HeavyTest("3rk2r/p3bp1p/p3p1pB/2p1P1N1/8/8/PPPR1PbP/1K1R4 w - - 0 17", [
        "d2d8", "e7d8", "d1d8", "e8d8", "g5f7"
    ], 1.seconds);
    tests ~= HeavyTest("r4rk1/p4p2/1p2p1Np/3p4/6Q1/6R1/P1q1bPPP/3R2K1 w - - 1 26", [
        "g6e7", "g8h8", "g4g7"
    ]);
    tests ~= HeavyTest("8/p6p/1pkbQ3/8/4n2q/4B3/PPP1BPPP/R2R2K1 b - - 0 22", [
        "h4h2", "g1f1", "h2h1"
    ]);
    tests ~= HeavyTest("rq3r1k/pp3p2/2p3pp/2bpPb2/2BR1Q2/3P4/PPP2PPP/R5K1 w - - 2 19", [
        "f4h6", "h8g8", "d4h4"
    ], 1.seconds);

    // Doesn't pass
    // tests ~= HeavyTest("1r2k2r/pppq1ppp/2P2n2/8/Q2P1P2/2N1BpP1/PP3P1P/R4RK1 b k - 0 18", ["d7h3"]);
    // tests ~= HeavyTest("8/kpp5/p7/5rp1/P2P4/2B4Q/1PP1q1PP/R5K1 b - - 4 30", [
    //     "e2f2", "g1h1", "f2f1", "a1f1", "f5f1"
    // ], 1.seconds);

    tests.randomShuffle(rnd);
    foreach (test; tests.parallel) {
        writeln("Running test ", test);
        test.check();
    }
    writeln("All tests passed!");
}
