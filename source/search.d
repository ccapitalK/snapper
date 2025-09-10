module snapper.search;

import core.atomic;
import std.algorithm;
import std.datetime;
import std.exception;
import std.logger;
import std.math : abs;
import std.stdio;
import std.typecons;

import snapper.state_table;
import snapper.repr;
import snapper.sort;
import snapper.stack_appender;

class StopException : Throwable {
    this(string file = __FILE__, size_t line = __LINE__) {
        super("StopException", file, line);
    }
}

const static size_t GAMESTATE_TABLE_MEMORY_BUDGET = 32 * 1024 * 1024;

// TODO: Clean this whole module up
struct SearchContext {
    Move[] currentBestVariation;
    // Transposition table
    GameStateTable seen;
    SysTime endTime;
    StackAppender!MoveDest appender;
    size_t numEvals = 1;
    size_t iterationsPerTimeoutCheck = size_t.max;

    void clear() {
        seen = GameStateTable(GAMESTATE_TABLE_MEMORY_BUDGET);
    }
}

SearchContext searchContext() {
    return SearchContext(
        seen: GameStateTable(GAMESTATE_TABLE_MEMORY_BUDGET),
        appender: StackAppender!MoveDest(1024),
    );
}

SearchContext *makeSearchContext() {
    return new SearchContext(
        seen: GameStateTable(GAMESTATE_TABLE_MEMORY_BUDGET),
        appender: StackAppender!MoveDest(1024),
    );
}

struct SearchFrame {
    // By convention we assume optimizing player is white, pessimizing is black
    // Lower bound for how good a position white can force for itself
    float alpha = -1. / 0.;
    // Lower bound for how good a position black can force for itself
    float beta = 1. / 0.;
    const(Move)[] principalSubchain;

    bool hasPrincipalChild() const nothrow => principalSubchain.length > 0;
    Move nextMoveInPrincipal() const nothrow => hasPrincipalChild
        ? principalSubchain[0] : Move.invalid;

    SearchFrame lower(Move move) const nothrow {
        auto rest = move == nextMoveInPrincipal ? principalSubchain[1 .. $] : [];
        return SearchFrame(alpha, beta, rest);
    }
}

class SearchNode {
    MoveDest move;
    float depthEval = 0.0;
    SearchNode principal;

    this(MoveDest move, float depthEval, SearchNode principal) {
        this.move = move;
        this.depthEval = depthEval;
        this.principal = principal;
    }
}

// TODO: Is there a more idiomatic way of doing this?
// Faster to sort indices than sort the array
struct SortOrder {
    ubyte[256] inds;
    MoveDest[] vals;
    Move principal;

    this(MoveDest[] vals, int mult, Move principal) {
        enforce(vals.length <= 256);
        this.vals = vals;
        this.principal = principal;
        if (vals.length == 0) {
            return;
        }
        size_t start = 0;
        foreach (i; 0 .. vals.length) {
            inds[i] = cast(ubyte) i;
            if (vals[i].move == principal) {
                swap(inds[0], inds[i]);
                ++start;
            }
        }
        // TODO use snapper.quicksort
        inds[start .. vals.length].sort!((i, j) => vals[i].eval * mult > vals[j].eval * mult);
    }

    auto range() const => inds[0 .. vals.length].map!(i => &vals[i]);
}

private SearchNode pickBestMoveInner(
    const ref GameState source,
    SearchFrame frame,
    SearchContext* context,
    int depth,
) {
    if (context.numEvals % context.iterationsPerTimeoutCheck == 0) {
        if (Clock.currTime + 10.msecs > context.endTime) {
            throw new StopException();
        }
    }
    ++context.numEvals;
    if (context.seen.containsOrReplace(source)) {
        return null;
    }

    auto appender = &context.appender;
    auto guard = StackAppenderResetGuard!MoveDest(appender);
    MoveDest[] children = validMoves(source, appender);

    auto isBlack = source.turn == Player.black;
    int multForPlayer = isBlack ? -1 : 1;
    auto sortOrder = SortOrder(children, multForPlayer, frame.nextMoveInPrincipal);
    const(MoveDest)* best = null;
    SearchNode bestNode = null;
    float bestScore = -double.infinity;
    foreach (const child; sortOrder.range) {
        SearchNode childNode;
        double score = child.eval;
        // FIXME: We should be checking if both kings are present,
        // as a quick hack we are only checking if a king is gone (+100k)
        bool isTerminal = abs(score) > 10_000;
        if (depth > 0) {
            if (isTerminal) {
                // Don't recurse if a king is gone, you can't trade a king for a king
                score *= depth; // Favour later defeat and earlier checkmate
            } else {
                auto cont = pickBestMoveInner(child.state, frame.lower(child.move), context, depth - 1);
                if (cont is null) {
                    continue;
                }
                score = cont.depthEval;
                childNode = cont;
            }
        }
        float scoreForPlayer = score * multForPlayer;
        if (scoreForPlayer > bestScore) {
            bestScore = scoreForPlayer;
            best = child;
            bestNode = childNode;
        }
        if (isBlack) {
            // Minimizing
            if (score < frame.alpha) {
                // Opponent won't permit this
                break;
            }
            frame.beta = min(frame.beta, score);
        } else {
            // Maximizing
            if (score > frame.beta) {
                // Opponent won't permit this
                break;
            }
            frame.alpha = max(frame.alpha, score);
        }
    }
    if (best == null) {
        return null;
    }
    return new SearchNode(*best, bestScore * multForPlayer, bestNode);
}

MoveDest pickBestMove(
    const ref GameState source,
    int depth = 6,
    SearchFrame frame = SearchFrame(),
    SearchContext* context = null,
) {
    bool isLocalContext = false;
    if (context == null) {
        context = makeSearchContext;
    }
    auto startEvals = numEvals;
    auto bestMove = source.pickBestMoveInner(frame, context, depth);
    infof("Evaluated %d positions for depth %d search", numEvals - startEvals, depth);
    infof("Best move: %s", bestMove.move);
    context.currentBestVariation = [];
    for (SearchNode node = bestMove; node !is null; node = node.principal) {
        context.currentBestVariation ~= node.move.move;
    }
    if (isLocalContext) {
        destroy(context);
    }
    return bestMove.move;
}

unittest {
    // Free queen capture
    auto state = "qb1k4/1r6/8/8/8/8/8/Q2K4 w - - 0 1".parseFen;
    foreach (depth; 0 .. 3) {
        assert(state.pickBestMove(depth).move.toString == "a1a8");
    }
    // Queen will be taken back
    state = "rb1k4/1b6/8/8/8/8/8/Q2K4 w - - 0 1".parseFen;
    assert(state.pickBestMove(0).move.toString == "a1a8"); // Free Rook (TODO Quiescence)
    assert(state.pickBestMove(1).move.toString != "a1a8"); // Realize that the queen will be taken in response
    // Queen must be taken back
    state = "Qb1k4/1b6/8/8/8/8/8/3K4 b - - 0 1".parseFen;
    assert(state.pickBestMove(0).move.toString == "b7a8");
    state = "r1bqkbnr/pppppppp/2n5/8/3P4/6P1/PPP1PP1P/RNBQKBNR b KQkq - 0 1".parseFen;
    assert(state.pickBestMove(1).move.toString != "c6d4");
    state = "7k/5ppp/8/8/8/4r3/8/2QK4 w - - 0 1".parseFen;
    assert(state.pickBestMove(1).move.toString != "c1c3");
    assert(state.pickBestMove(3).move.toString != "c1c8");
}

// TODO: We should be keeping some stuff from the previous iteration. This is more ad-hoc
MoveDest pickBestMoveIterativeDeepening(
    const ref GameState source,
    SearchContext* context,
    int startNumIterations = 1,
) {
    MoveDest move;
    bool hasMove = false;
    SearchFrame frame;
    context.iterationsPerTimeoutCheck = 20_000;
    try {
        // We aren't ever going above 15
        foreach (depth; startNumIterations .. 15) {
            context.clear();
            MoveDest found = source.pickBestMove(depth, frame, context);
            move = found;
            hasMove = true;
            frame.principalSubchain = context.currentBestVariation;
        }
    } catch (StopException) {
        info("Interrupted!");
    }
    enforce(hasMove);
    return move;
}
