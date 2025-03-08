module chess_engine.repr.move;

import std.algorithm;
import std.array;
import std.ascii;
import std.format;
import std.logger;
import std.math : abs;
import std.exception;
import std.typecons;

import chess_engine.repr.board;
import chess_engine.repr.state;

struct MoveDest {
    GameState board;
    Move move;
    // Positive for white, negative for black
    float eval;

    string toString() const => format("%s = %s", move, eval);
}

MoveDest performMove(const ref GameState state, MCoord source, MCoord dest) {
    GameState next = state;
    auto sourceSquare = next.board.getSquare(source);
    auto destSquare = next.board.getSquare(dest);
    assert(!sourceSquare.isEmpty && sourceSquare.getPlayer == state.turn);
    assert(destSquare.isEmpty || destSquare.getPlayer != state.turn);
    bool isPawn = sourceSquare.getPiece == Piece.pawn;
    bool isCapture = !destSquare.isEmpty;
    *destSquare = *sourceSquare;
    *sourceSquare = Square.empty;
    // TODO: Castling
    next.enPassant = MCoord.invalid;
    if (isPawn && abs(dest.y - source.y) > 1) {
        next.enPassant = MCoord(dest.x, (dest.y + source.y) / 2);
    }
    next.halfMove = (isPawn || isCapture) ? 0 : cast(ushort)(state.halfMove + 1);
    if (state.turn == Player.black) {
        ++next.fullMove;
    }
    next.turn = cast(Player) !state.turn;
    return MoveDest(next, Move(source, dest), next.leafEval());
}

unittest {
    // Two simple moves
    auto state = "3k4/8/8/8/8/8/4B3/3K4 w - - 0 1".parseFen;
    auto result = state.performMove(MCoord(4, 1), MCoord(2, 3));
    assert(result.board.toFen == "3k4/8/8/8/2B5/8/8/3K4 b - - 1 1");
    state = result.board;
    result = state.performMove(MCoord(3, 7), MCoord(4, 6));
    assert(result.board.toFen == "8/4k3/8/8/2B5/8/8/3K4 w - - 2 2");
    // Pawn double move (test enPassant + halfMove)
    state = "3k4/8/8/8/8/8/3P4/3K4 w - - 0 1".parseFen;
    result = state.performMove(MCoord(3, 1), MCoord(3, 3));
    assert(result.board.toFen == "3k4/8/8/8/3P4/8/8/3K4 b - d3 0 1");
    state = result.board;
    result = state.performMove(MCoord(3, 7), MCoord(3, 6));
    assert(result.board.toFen == "8/3k4/8/8/3P4/8/8/3K4 w - - 1 2");
}

pragma(inline, true)
bool canTakeOrMove(const ref GameState state, MCoord source, MCoord dest) {
    if (!dest.isInBounds) {
        return false;
    }
    auto destSquare = state.board.getSquare(dest);
    return destSquare.isEmpty || destSquare.getPlayer != state.turn;
}

pragma(inline, true)
bool canTake(const ref GameState state, MCoord source, MCoord dest) {
    if (!dest.isInBounds) {
        return false;
    }
    auto destSquare = state.board.getSquare(dest);
    return !destSquare.isEmpty && destSquare.getPlayer != state.turn;
}

pragma(inline, true)
void addValidMovesForPawn(const ref GameState state, Appender!(MoveDest[])* builder, MCoord source) {
    // TODO: Promotion? How does UCI even handle that
    static const int[2] DOUBLE_RANK = [1, 6];
    static const int[2] FORWARD_DIR = [1, -1];
    auto currentTurn = state.turn;
    // TODO: Double move
    auto forward = MCoord(source.x, source.y + FORWARD_DIR[currentTurn]);
    // Pawns on the back rank are illegal
    enforce(forward.isInBounds);
    bool canMoveForward = state.board.isEmpty(forward);
    if (canMoveForward) {
        builder.put(state.performMove(source, forward));
    }
    if (canMoveForward && source.y == DOUBLE_RANK[currentTurn]) {
        auto doubleForward = MCoord(source.x, source.y + 2 * FORWARD_DIR[currentTurn]);
        if (state.board.isEmpty(doubleForward)) {
            builder.put(state.performMove(source, doubleForward));
        }
    }
    // TODO: En-passant
    foreach (sign; SIGNS) {
        auto dest = MCoord(source.x + sign, source.y + FORWARD_DIR[currentTurn]);
        if (state.canTake(source, dest)) {
            builder.put(state.performMove(source, dest));
        }
    }
}

unittest {
    auto state = "4k3/4p3/8/8/8/8/4P3/4K3 b KQkq - 0 1".parseFen;
    assert(state.validMoves.length == 6);
}

pragma(inline, true)
void addValidMovesForBishop(const ref GameState state, Appender!(MoveDest[])* builder, MCoord source) {
    foreach (xSign; SIGNS) {
        foreach (ySign; SIGNS) {
            foreach (step; 1 .. 8) {
                auto dest = MCoord(
                    source.x + step * xSign,
                    source.y + step * ySign,
                );
                if (!state.canTakeOrMove(source, dest)) {
                    break;
                }
                builder.put(state.performMove(source, dest));
                if (!state.board.isEmpty(dest)) {
                    break;
                }
            }
        }
    }
}

pragma(inline, true)
void addValidMovesForRook(const ref GameState state, Appender!(MoveDest[])* builder, MCoord source) {
    foreach (dir; DIRS) {
        foreach (step; 1 .. 8) {
            auto dest = MCoord(
                source.x + step * dir.x,
                source.y + step * dir.y,
            );
            if (!state.canTakeOrMove(source, dest)) {
                break;
            }
            builder.put(state.performMove(source, dest));
            if (!state.board.isEmpty(dest)) {
                break;
            }
        }
    }
}

pragma(inline, true)
void addValidMovesForKnight(const ref GameState state, Appender!(MoveDest[])* builder, MCoord source) {
    foreach (xSign; SIGNS) {
        foreach (ySign; SIGNS) {
            foreach (flip; 0 .. 2) {
                auto dx = flip ? 2 : 1;
                auto dy = flip ? 1 : 2;
                auto dest = MCoord(
                    source.x + dx * xSign,
                    source.y + dy * ySign,
                );
                if (state.canTakeOrMove(source, dest)) {
                    builder.put(state.performMove(source, dest));
                }
            }
        }
    }
}

pragma(inline, true)
void addValidMovesForKing(const ref GameState state, Appender!(MoveDest[])* builder, MCoord source) {
    // TODO: Castle
    foreach (dx; atMostOne) {
        foreach (dy; atMostOne) {
            if (dx == 0 && dy == 0) {
                continue;
            }
            auto destSquare = MCoord(source.x + dx, source.y + dy);
            if (state.canTakeOrMove(source, destSquare)) {
                builder.put(state.performMove(source, destSquare));
            }
        }
    }
}

MoveDest[] validMoves(const ref GameState parent) {
    // TODO: Pass in arena allocator
    auto builder = appender(new MoveDest[0]);
    foreach (i; 0 .. 64) {
        auto file = i & 7;
        auto rank = i >> 3;
        auto square = *parent.board.getSquare(file, rank);
        auto piece = square.getPiece;
        auto owner = square.getPlayer;
        if (piece == Piece.empty || owner != parent.turn) {
            continue;
        }
        auto piecePos = MCoord(cast(ubyte) file, cast(ubyte) rank);
        switch (piece) {
        case Piece.pawn:
            addValidMovesForPawn(parent, &builder, piecePos);
            break;
        case Piece.bishop:
            addValidMovesForBishop(parent, &builder, piecePos);
            break;
        case Piece.rook:
            addValidMovesForRook(parent, &builder, piecePos);
            break;
        case Piece.knight:
            addValidMovesForKnight(parent, &builder, piecePos);
            break;
        case Piece.queen:
            addValidMovesForBishop(parent, &builder, piecePos);
            addValidMovesForRook(parent, &builder, piecePos);
            break;
        case Piece.king:
            addValidMovesForKing(parent, &builder, piecePos);
            break;
        default:
            assert(0);
        }
    }
    auto moves = builder.data;
    // XXX This still uses CPU cycles, even when not enabled? wtf?
    // foreach (move; moves) {
    //     trace(move.eval, ' ', move.move.getRepr);
    // }
    return moves;
}

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
    enforce(children.length > 0);
    const(MoveDest) *best = null;
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
