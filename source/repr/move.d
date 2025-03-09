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

struct Move {
    MCoord source;
    MCoord dest;
    Piece promotion = Piece.empty;
}

Move parseMove(string moveStr) {
    enforce(moveStr.length == 4 || moveStr.length == 5);
    Move move;
    move.source.x = cast(ubyte) (moveStr[0] - 'a');
    move.source.y = cast(ubyte) (moveStr[1] - '1');
    move.dest.x = cast(ubyte) (moveStr[2] - 'a');
    move.dest.y = cast(ubyte) (moveStr[3] - '1');
    if (moveStr.length == 5) {
        static foreach (v; pieceByFenName) {
            if (moveStr[4] == v[0]) {
                move.promotion = v[1];
            }
        }
    }
    return move;
}

string toString(Move m) {
    auto end = 4;
    char[5] data;
    // BLEGH, modules don't allow the same symbol to be defined in
    // two spaces, even for different types?
    data[0 .. 2] = chess_engine.repr.board.toString(m.source)[];
    data[2 .. 4] = chess_engine.repr.board.toString(m.dest)[];
    static foreach (v; pieceByFenName) {
        if (m.promotion == v[1]) {
            data[4] = v[0];
            end = 5;
        }
    }
    return data[0 .. end].idup;
}

struct MoveDest {
    GameState state;
    Move move;
    // Positive for white, negative for black
    float eval;

    string toString() const => format("%s => leaf(%s)", move.toString, eval);
}

MoveDest performMove(const ref GameState state, MCoord source, MCoord dest) {
    Piece promotion = Piece.empty;
    GameState next = state;
    auto sourceSquare = next.board.getSquare(source);
    auto destSquare = next.board.getSquare(dest);
    enforce(!sourceSquare.isEmpty && sourceSquare.getPlayer == state.turn);
    enforce(destSquare.isEmpty || destSquare.getPlayer != state.turn);

    bool isPawn = sourceSquare.getPiece == Piece.pawn;
    bool isCapture = !destSquare.isEmpty;
    bool isCastling = sourceSquare.getPiece == Piece.king && abs(dest.x - source.x) > 1;

    *destSquare = *sourceSquare;
    *sourceSquare = Square.empty;
    if (isCastling) {
        auto rank = dest.y;
        auto origFile = dest.x == 2 ? 0 : 7;
        auto newFile = dest.x == 2 ? 3 : 5;
        *next.board.getSquare(MCoord(origFile, rank)) = Square.empty;
        *next.board.getSquare(MCoord(newFile, rank)) = Square(state.turn, Piece.rook);
    }
    next.enPassant = MCoord.invalid;
    if (isPawn && abs(dest.y - source.y) > 1) {
        next.enPassant = MCoord(dest.x, (dest.y + source.y) / 2);
    }
    next.halfMove = (isPawn || isCapture) ? 0 : cast(ushort)(state.halfMove + 1);
    // FIXME: Promotion to pieces other than the queen are possible
    if (isPawn && (dest.y == 0 || dest.y == 7)) {
        *destSquare = Square(destSquare.getPlayer, Piece.queen);
        promotion = Piece.queen;
    }
    if (state.turn == Player.black) {
        ++next.fullMove;
    }
    next.turn = cast(Player) !state.turn;
    return MoveDest(next, Move(source, dest, promotion), next.leafEval());
}

MoveDest performMove(const ref GameState state, Move move) {
    return state.performMove(move.source, move.dest);
}

unittest {
    // Fomatting
    assert(Move(MCoord(3, 4), MCoord(7, 0)).toString == "d5h1");
    assert(Move(MCoord(3, 4), MCoord(7, 0), Piece.empty).toString == "d5h1");
    assert(Move(MCoord(3, 4), MCoord(7, 0), Piece.queen).toString == "d5h1q");
    assert(Move(MCoord(3, 4), MCoord(7, 0), Piece.knight).toString == "d5h1n");
    // Two simple moves
    auto state = "3k4/8/8/8/8/8/4B3/3K4 w - - 0 1".parseFen;
    auto result = state.performMove(MCoord(4, 1), MCoord(2, 3));
    assert(result.state.toFen == "3k4/8/8/8/2B5/8/8/3K4 b - - 1 1");
    state = result.state;
    result = state.performMove(MCoord(3, 7), MCoord(4, 6));
    assert(result.state.toFen == "8/4k3/8/8/2B5/8/8/3K4 w - - 2 2");
    // Pawn double move (test enPassant + halfMove)
    state = "3k4/8/8/8/8/8/3P4/3K4 w - - 0 1".parseFen;
    result = state.performMove(MCoord(3, 1), MCoord(3, 3));
    assert(result.state.toFen == "3k4/8/8/8/3P4/8/8/3K4 b - d3 0 1");
    state = result.state;
    result = state.performMove(MCoord(3, 7), MCoord(3, 6));
    assert(result.state.toFen == "8/3k4/8/8/3P4/8/8/3K4 w - - 1 2");
    // Pawn promotes to queen
    state = "8/7P/8/8/k7/8/8/K7 w - - 0 1".parseFen;
    result = state.performMove(MCoord(7, 6), MCoord(7, 7));
    assert(*result.state.board.getSquare(7, 7) == Square(Player.white, Piece.queen));
    assert(result.move.toString() == "h7h8q");
    // Castling
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("e1g1".parseMove);
    assert(*result.state.board.getSquare(6, 0) == Square(Player.white, Piece.king));
    assert(*result.state.board.getSquare(5, 0) == Square(Player.white, Piece.rook));
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("e1c1".parseMove);
    assert(*result.state.board.getSquare(2, 0) == Square(Player.white, Piece.king));
    assert(*result.state.board.getSquare(3, 0) == Square(Player.white, Piece.rook));
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
    // TODO: Promotion to pieces that aren't queen
    static const int[2] DOUBLE_RANK = [1, 6];
    static const int[2] FORWARD_DIR = [1, -1];
    auto currentTurn = state.turn;
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
    foreach (sign; SIGNS) {
        auto dest = MCoord(source.x + sign, source.y + FORWARD_DIR[currentTurn]);
        if (state.canTake(source, dest) || state.enPassant == dest) {
            builder.put(state.performMove(source, dest));
        }
    }
}

unittest {
    auto state = "4k3/4p3/8/8/8/8/4P3/4K3 b KQkq - 0 1".parseFen;
    assert(state.validMoves.length == 6);
    state = "k7/8/8/5Pp1/8/8/8/K7 w - g6 0 1".parseFen;
    assert(state.validMoves.length == 5);
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
    return moves;
}
