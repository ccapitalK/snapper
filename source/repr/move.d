module snapper.repr.move;

import std.algorithm;
import std.array;
import std.ascii;
import std.exception;
import std.format;
import std.logger;
import std.math : abs;
import std.traits;
import std.typecons;

import snapper.bit;
import snapper.repr;
import snapper.stack_appender;

struct Move {
    MCoord source;
    MCoord dest;
    Piece promotion = Piece.empty;

    static const invalid = Move(MCoord.invalid, MCoord.invalid);
}

Move parseMove(string moveStr) {
    enforce(moveStr.length == 4 || moveStr.length == 5);
    Move move;
    move.source = parseCoord(moveStr[0 .. 2]);
    move.dest = parseCoord(moveStr[2 .. 4]);
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
    data[0 .. 2] = snapper.repr.toString(m.source)[];
    data[2 .. 4] = snapper.repr.toString(m.dest)[];
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

struct CastlingCheck {
    MCoord pos;
    Player player;
    string side;
}

MoveDest performMove(const ref GameState state, MCoord source, MCoord dest, Piece promotion = Piece.empty) {
    const static CastlingCheck[4] castlingChecks = [
        CastlingCheck("a1".parseCoord, Player.white, "queen"),
        CastlingCheck("h1".parseCoord, Player.white, "king"),
        CastlingCheck("a8".parseCoord, Player.black, "queen"),
        CastlingCheck("h8".parseCoord, Player.black, "king"),
    ];
    GameState next = state;
    auto sourceSquare = next.board.getSquare(source);
    auto destSquare = next.board.getSquare(dest);
    enforce(!sourceSquare.isEmpty && sourceSquare.getPlayer == state.turn);
    enforce(destSquare.isEmpty || destSquare.getPlayer != state.turn);

    bool isPawn = sourceSquare.getPiece == Piece.pawn;
    bool isKing = sourceSquare.getPiece == Piece.king;
    bool isCapture = !destSquare.isEmpty;
    bool isCastling = isKing && abs(dest.x - source.x) > 1;

    next.board.setSquare(dest, sourceSquare);
    next.board.setSquare(source, Square.empty);
    // Castling
    if (isCastling) {
        auto rank = dest.y;
        auto origFile = dest.x == 2 ? 0 : 7;
        auto newFile = dest.x == 2 ? 3 : 5;
        next.board.setSquare(MCoord(origFile, rank), Square.empty);
        next.board.setSquare(MCoord(newFile, rank), Square(state.turn, Piece.rook));
    }
    if (isCastling || isKing) {
        next.castling.king[state.turn] = 0;
        next.castling.queen[state.turn] = 0;
    } else {
        static foreach (player; EnumMembers!Player) {
            static foreach (check; castlingChecks) {
                {
                    const static string lookup = ".castling." ~ check.side ~ "[player]";
                    bool isCoord = source == check.pos || dest == check.pos;
                    if (check.player == player && mixin("state" ~ lookup) && isCoord) {
                        mixin("next" ~ lookup) = false;
                    }
                }
            }
        }
    }
    // Pawn moves
    next.enPassant = MCoord.invalid;
    if (isPawn) {
        if (abs(dest.y - source.y) > 1) {
            next.enPassant = MCoord(dest.x, (dest.y + source.y) / 2);
        }
        if (dest == state.enPassant) {
            auto backward = state.turn == Player.black ? 1 : -1;
            auto takenPieceSquare = MCoord(state.enPassant.x, state.enPassant.y + backward);
            next.board.setSquare(takenPieceSquare, Square.empty);
        }
        if (dest.y == 0 || dest.y == 7) {
            enforce(promotion != Piece.empty);
            next.board.setSquare(dest, Square(state.turn, promotion));
        } else {
            enforce(promotion == Piece.empty);
        }
    }
    // Advance states
    next.halfMove = (isPawn || isCapture) ? 0 : cast(ushort)(state.halfMove + 1);
    if (state.turn == Player.black) {
        ++next.fullMove;
    }
    next.turn = cast(Player) !state.turn;
    return MoveDest(next, Move(source, dest, promotion), next.leafEval());
}

MoveDest performMove(const ref GameState state, Move move) {
    return state.performMove(move.source, move.dest, move.promotion);
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
    // Taking En Passant should update the square
    state = "4k3/8/8/8/4p3/8/3P4/4K3 w - - 0 1".parseFen;
    state = state.performMove("d2d4".parseMove).state;
    state = state.performMove("e4d3".parseMove).state;
    assert(state.toFen == "4k3/8/8/8/8/3p4/8/4K3 w - - 0 2");
    // Pawn promotes to queen
    state = "8/7P/8/8/k7/8/8/K7 w - - 0 1".parseFen;
    result = state.performMove(MCoord(7, 6), MCoord(7, 7), Piece.queen);
    assert(result.state.board.getSquare(MCoord(7, 7)) == Square(Player.white, Piece.queen));
    assert(result.move.toString() == "h7h8q");
    // Pawn promotes to knight
    state = "8/7P/8/8/k7/8/8/K7 w - - 0 1".parseFen;
    result = state.performMove(MCoord(7, 6), MCoord(7, 7), Piece.knight);
    assert(result.state.board.getSquare(MCoord(7, 7)) == Square(Player.white, Piece.knight));
    assert(result.move.toString() == "h7h8n");
    // Castling should move the pieces
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("e1g1".parseMove);
    assert(result.state.board.getSquare(MCoord(6, 0)) == Square(Player.white, Piece.king));
    assert(result.state.board.getSquare(MCoord(5, 0)) == Square(Player.white, Piece.rook));
    assert(result.state.castling == Castling.none);
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("e1c1".parseMove);
    assert(result.state.board.getSquare(MCoord(2, 0)) == Square(Player.white, Piece.king));
    assert(result.state.board.getSquare(MCoord(3, 0)) == Square(Player.white, Piece.rook));
    assert(result.state.castling == Castling.none);
    state = "r3k2r/8/8/8/8/8/8/4K3 b kq - 0 1".parseFen;
    result = state.performMove("e8c8".parseMove);
    assert(result.state.board.getSquare(MCoord(2, 7)) == Square(Player.black, Piece.king));
    assert(result.state.board.getSquare(MCoord(3, 7)) == Square(Player.black, Piece.rook));
    assert(result.state.castling == Castling.none);
    // Castling should be invalidated
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("a1b1".parseMove);
    assert(result.state.castling == Castling([true, false], [false, false]));
    state = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1".parseFen;
    result = state.performMove("h1h2".parseMove);
    assert(result.state.castling == Castling([false, false], [true, false]));
    state = "r3k2r/8/8/8/8/8/8/4K3 b kq - 0 1".parseFen;
    result = state.performMove("a8b8".parseMove);
    assert(result.state.castling == Castling([false, true], [false, false]));
    state = "r3k2r/8/8/8/8/8/8/4K3 b kq - 0 1".parseFen;
    result = state.performMove("e8d8".parseMove);
    assert(result.state.castling == Castling([false, false], [false, false]));
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
void addValidMovesForPawn(AppenderT)(const ref GameState state, const ref BitBoard board, AppenderT builder) {
    auto pawns = board.occupied(Piece.pawn, state.turn);
    auto currentTurn = state.turn;
    pawns.iterateBits!((s) {
        // TODO: Optimize
        auto source = s.coordFromBit;
        static const int[2] DOUBLE_RANK = [1, 6];
        static const int[2] FORWARD_DIR = [1, -1];
        bool aboutToPromote = source.y == DOUBLE_RANK[!currentTurn];
        scope auto moveForwardOne = (MCoord dest) {
            if (aboutToPromote) {
                foreach (Piece pieceToPromoteTo; Piece.rook .. Piece.king) {
                    builder.put(state.performMove(source, dest, pieceToPromoteTo));
                }
            } else {
                builder.put(state.performMove(source, dest));
            }
        };
        auto forward = MCoord(source.x, source.y + FORWARD_DIR[currentTurn]);
        // Pawns on the back rank are illegal
        enforce(forward.isInBounds);
        bool canMoveForward = state.board.isEmpty(forward);
        if (canMoveForward) {
            moveForwardOne(forward);
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
                moveForwardOne(dest);
            }
        }
    });
}

pragma(inline, true)
void addValidMovesForBishop(AppenderT)(const ref GameState state, const ref BitBoard board, AppenderT builder) {
    auto bishops = board.occupied(Piece.bishop, state.turn);
    bishops = bishops.union_(board.occupied(Piece.queen, state.turn));
    bishops.iterateBits!((s) {
        auto source = s.coordFromBit;
        // TODO: Optimize
        foreach (xSign; SIGNS) {
            foreach (ySign; SIGNS) {
                ({
                    foreach (step; 1 .. 8) {
                        auto dest = MCoord(
                            source.x + step * xSign,
                            source.y + step * ySign,
                        );
                        if (!state.canTakeOrMove(source, dest)) {
                            return;
                        }
                        builder.put(state.performMove(source, dest));
                        if (!state.board.isEmpty(dest)) {
                            return;
                        }
                    }
                })();
            }
        }
    });
}

pragma(inline, true)
void addValidMovesForRook(AppenderT)(const ref GameState state, const ref BitBoard board, AppenderT builder) {
    auto rooks = board.occupied(Piece.rook, state.turn);
    rooks = rooks.union_(board.occupied(Piece.queen, state.turn));
    rooks.iterateBits!((s) {
        auto source = s.coordFromBit;
        // TODO: Optimize this
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
    });
}

pragma(inline, true)
private void addValidMovesForKnight(AppenderT)(const ref GameState state, const ref BitBoard board, AppenderT builder) {
    auto knights = board.occupied(Piece.knight, state.turn);
    auto noAllyPieceMask = board.occupied(state.turn).negated;
    knights.iterateBits!((s) {
        auto sMask = PositionMask(s);
        auto source = s.coordFromBit;
        auto adj = sMask.getKnightMoves;
        PositionMask dests = adj.intersection(noAllyPieceMask);
        dests.iterateBits!((d) {
            auto dest = d.coordFromBit;
            builder.put(state.performMove(source, dest));
        });
    });
}

pragma(inline, true)
private void addValidMovesForKing(AppenderT)(const ref GameState state, const ref BitBoard board, AppenderT builder) {
    auto king = board.occupied(Piece.king, state.turn);
    auto noAllyPieceMask = board.occupied(state.turn).negated;
    // TODO: Castling
    king.iterateBits!((s) {
        auto sMask = PositionMask(s);
        auto source = s.coordFromBit;
        auto adj = sMask.getAdjacent;
        PositionMask dests = adj.intersection(noAllyPieceMask);
        dests.iterateBits!((d) {
            auto dest = d.coordFromBit;
            builder.put(state.performMove(source, dest));
        });
    });
}

// TODO: Always use a bitboard
MoveDest[] validMovesInner(AppenderT)(const ref GameState parent, AppenderT builder) {
    parent.addValidMovesForKing!AppenderT(parent.board, builder);
    parent.addValidMovesForKnight!AppenderT(parent.board, builder);
    parent.addValidMovesForRook!AppenderT(parent.board, builder);
    parent.addValidMovesForBishop!AppenderT(parent.board, builder);
    parent.addValidMovesForPawn!AppenderT(parent.board, builder);
    auto moves = builder.data;
    return moves;
}

// TODO: Compile times went up from 600ms to 8s when I did the stack appender change. It appears to be caused by
// writing large array constructors inline in a struct, look at blame for when this message was introduced to see
// what fixed the issue.
MoveDest[] validMoves(
    const ref GameState parent,
    StackAppender!MoveDest* builder,
) {
    return validMovesInner!(typeof(builder))(parent, builder);
}

MoveDest[] validMoves(const ref GameState parent) {
    Appender!(MoveDest[]) builder;
    return validMovesInner(parent, &builder);
}

unittest {
    // King moves
    auto state = "1k6/8/8/8/8/8/8/K7 w - - 0 1".parseFen;
    assert(state.validMoves.length == 3);
    state.turn = Player.black;
    assert(state.validMoves.length == 5);
    // Knight moves
    state = "1k6/8/8/4N3/3p4/8/2N5/K6N w - - 0 1".parseFen;
    assert(state.validMoves.length == 18);
    // Rook moves
    state = "8/5r2/8/8/5R2/8/3R4/8 w - - 0 1".parseFen;
    assert(state.validMoves.length == 27);
    state = "K7/5r2/8/8/2Q5/8/8/k7 w - - 0 1".parseFen;
    assert(state.validMoves.length == 27);

    // Pawn moves

    // auto state = "4k3/4p3/8/8/8/8/4P3/4K3 b KQkq - 0 1".parseFen;
    // assert(state.validMoves.length == 6);
    // state = "k7/8/8/5Pp1/8/8/8/K7 w - g6 0 1".parseFen;
    // assert(state.validMoves.length == 5);
}
