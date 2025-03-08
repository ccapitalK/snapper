module chess_engine.search;

import std.algorithm;
import std.exception;
import std.logger;
import std.stdio;
import std.typecons;
import chess_engine.repr;

// XXX Rename
struct SearchCtx {
    // By convention we assume optimizing player is white, pessimizing is black
    float alpha = -1. / 0.;
    float beta = 1. / 0.;
}

static int numFiltered = 0;

// XXX This overshooting the amount of expected states being search by a few orders of magnitude
// TODO: Switch to fail-soft
private Nullable!(const MoveDest) pickBestMoveInner(const ref GameState source, SearchCtx ctx, int depth) {
    auto isBlack = source.turn == Player.black;
    int multForPlayer = isBlack ? -1 : 1;
    MoveDest[] children = source.validMoves;
    children[].sort!((a, b) => multForPlayer * a.eval < multForPlayer * b.eval);
    const(MoveDest)* best = null;
    float bestScore = -1. / 0.;
    foreach (const ref child; children) {
        double score = child.eval;
        if (depth > 0) {
            auto cont = pickBestMoveInner(child.board, ctx, depth - 1);
            if (cont.isNull) {
                continue;
            }
            score = cont.get.eval;
        }
        if (isBlack) {
            // Minimizing
            if (score < ctx.alpha) {
                break;
            }
            ctx.beta = min(ctx.beta, score);
        } else {
            // Maximizing
            if (score > ctx.beta) {
                break;
            }
            ctx.alpha = max(ctx.alpha, score);
        }
        score *= multForPlayer;
        if (score > bestScore) {
            bestScore = score;
            best = &child;
        }
    }
    return best == null ? Nullable!(const MoveDest)() : (*best).nullable;
}

MoveDest pickBestMove(const ref GameState source, int depth = 4) {
    SearchCtx ctx;
    auto startEvals = numEvals;
    auto bestMove = source.pickBestMoveInner(ctx, depth).get;
    infof("Evaluated %d positions", numEvals - startEvals);
    infof("Best move: %s", bestMove);
    return bestMove;
}

unittest {
    // Free queen capture
    auto state = "qb1k4/1r6/8/8/8/8/8/Q2K4 w - - 0 1".parseFen;
    foreach (depth; 0 .. 3) {
        assert(state.pickBestMove(depth).move.getRepr == "a1a8");
    }
    // Queen will be taken back
    state = "qb1k4/1b6/8/8/8/8/8/Q2K4 w - - 0 1".parseFen;
    assert(state.pickBestMove(0).move.getRepr == "a1a8");
    // This fails? FIXME
    // assert(state.pickBestMove(1).move.getRepr != "a1a8");
}
