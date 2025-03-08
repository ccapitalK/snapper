module chess_engine.repr.board;

import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.math;
import std.exception;
import std.logger;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;

static const int[2] SIGNS = [-1, 1];
static const MCoord[4] DIRS = [
    MCoord(0, 1),
    MCoord(1, 0),
    MCoord(0, -1),
    MCoord(-1, 0),
];
static auto atMostOne() => iota(-1, 2);

struct MCoord {
    // File, from 0
    byte x;
    // Rank, from 0
    byte y;
    static const MCoord invalid = MCoord(127, 127);

    this(int x, int y) {
        this.x = cast(ubyte) x;
        this.y = cast(ubyte) y;
    }
}

bool isInBounds(MCoord coord) => ((coord.x & 7) == coord.x) && ((coord.y & 7) == coord.y);

struct Move {
    MCoord source;
    MCoord dest;
}

string getRepr(MCoord m) {
    enforce(m != MCoord.invalid);
    return cast(string)['a' + m.x, '1' + m.y];
}

string getRepr(Move m) => m.source.getRepr ~ m.dest.getRepr;

enum Player : ubyte {
    white = 0,
    black,
}

enum Piece : ubyte {
    empty = 0,
    pawn,
    rook,
    knight,
    bishop,
    queen,
    king,
}

static const auto pieceByFenName = [
    tuple('p', Piece.pawn, 1),
    tuple('r', Piece.rook, 5),
    tuple('n', Piece.knight, 3),
    tuple('b', Piece.bishop, 3),
    tuple('q', Piece.queen, 9),
    tuple('k', Piece.king, 4),
];

align(1)
struct Square {
    ubyte v;

    this(Player player, Piece piece) {
        setPlayer(player);
        setPiece(piece);
    }

    Piece getPiece() const => cast(Piece)(v & 7);
    void setPiece(Piece p) {
        v = (v & 0xF8) | p;
    }

    Player getPlayer() const => cast(Player)((v >> 3) & 1);
    void setPlayer(Player p) {
        v = cast(ubyte)((v & ~0x08) | (p << 3));
    }

    char getRepr() const {
        char c;
        auto piece = getPiece;
    pieceSwitch:
        final switch (piece) {
        case Piece.empty:
            return ' ';
            static foreach (v; pieceByFenName) {
        case v[1]:
                c = v[0];
                break pieceSwitch;
            }
        }
        return getPlayer == Player.white ? std.ascii.toUpper(c) : c;
    }

    bool isEmpty() const => v == 0;
    static const Square empty;
}

static assert(Square.sizeof == 1);

struct Board {
    // TODO: Bitboard
    // TODO: Pack into half the space
    Square[64] pieces;

    // Rank major order
    Square* getSquare(size_t file, size_t rank) => &pieces[file + 8 * rank];
    const(Square)* getSquare(size_t file, size_t rank) const => &pieces[file + 8 * rank];

    Square* getSquare(MCoord coord) => getSquare(coord.x, coord.y);
    const(Square)* getSquare(MCoord coord) const => getSquare(coord.x, coord.y);
}

string getAsciiArtRepr(const ref Board board) {
    auto builder = appender(cast(string)[]);
    foreach (y; 0 .. 8) {
        auto rank = 7 - y;
        builder.put(format("%d  ", rank + 1));
        foreach (x; 0 .. 8) {
            auto file = x;
            auto square = *board.getSquare(file, rank);
            char c;
        pSwitch:
            final switch (square.getPiece()) {
            case Piece.empty:
                c = ' ';
                break;
                static foreach (v; pieceByFenName) {
            case v[1]:
                    c = v[0];
                    break pSwitch;
                }
            }
            builder.put(square.getPlayer == Player.white ? std.ascii.toUpper(c) : c);
        }
        builder.put('\n');
    }
    builder.put("\n   ABCDEFGH");
    return builder.data;
}

bool isEmpty(const ref Board board, MCoord coord) => board.getSquare(coord).isEmpty;

struct Castling {
    bool[EnumMembers!Player.length] king;
    bool[EnumMembers!Player.length] queen;

    static const Castling none = Castling([false, false], [false, false]);
    static const Castling all = Castling([true, true], [true, true]);
}

struct GameState {
    Board board;
    Player turn;
    Castling castling;
    MCoord enPassant;
    ushort halfMove;
    ushort fullMove;
}

bool isInCheck(const ref GameState state, Player playerToCheck) {
    return false;
}

GameState parseFen(string input) {
    GameState fen;
    auto parts = input.strip.splitter(' ').staticArray!6;
    foreach (rank, line; parts[0].splitter('/').enumerate) {
        auto file = 0;
        foreach (c; line) {
            if (c.isDigit) {
                file += c - '0';
                continue;
            }
            enforce(c.isAlpha);
            Player player = c.isLower ? Player.black : Player.white;
            Piece piece;
        sw:
            switch (std.ascii.toLower(c)) {
                static foreach (v; pieceByFenName) {
            case v[0]:
                    piece = v[1];
                    break sw;
                }
            default:
                break;
            }
            enforce(file < 8 && rank < 8);
            *fen.board.getSquare(file, 7 - rank) = Square(player, piece);
            ++file;
        }
    }

    fen.turn = parts[1][0] == 'b' ? Player.black : Player.white;
    string castling = parts[2];
    fen.castling = Castling.none;
    foreach (c; castling) {
        switch (c) {
        case 'K':
            fen.castling.king[Player.white] = 1;
            break;
        case 'Q':
            fen.castling.queen[Player.white] = 1;
            break;
        case 'k':
            fen.castling.king[Player.black] = 1;
            break;
        case 'q':
            fen.castling.queen[Player.black] = 1;
            break;
        default:
            break;
        }
    }
    if (parts[3] == "-") {
        fen.enPassant = MCoord.invalid;
    } else {
        fen.enPassant = MCoord(cast(ubyte)(parts[3][1] - '1'), cast(ubyte)(parts[3][0] - 'a'));
    }
    fen.halfMove = parts[4].to!ushort;
    fen.fullMove = parts[5].to!ushort;
    return fen;
}

string toFen(const ref GameState state) {
    auto builder = appender("");
    foreach (rank; iota(8).retro) {
        size_t numEmpty = 0;
        foreach (file; iota(8)) {
            auto square = state.board.getSquare(file, rank);
            if (square.isEmpty) {
                ++numEmpty;
                continue;
            }
            if (numEmpty > 0) {
                builder.put(numEmpty.to!string);
                numEmpty = 0;
            }
            builder.put(square.getRepr);
        }
        if (numEmpty > 0) {
            builder.put(numEmpty.to!string);
        }
        if (rank > 0) {
            builder.put('/');
        }
    }
    // Turn
    builder.put(state.turn == Player.black ? " b" : " w");
    // Castling
    builder.put(" ");
    if (state.castling == Castling.none) {
        builder.put("-");
    } else {
        foreach (c; "KQkq") {
            Player player = std.ascii.isLower(c) ? Player.black : Player.white;
            bool canCastle = std.ascii.toLower(c) == 'k'
                ? state.castling.king[player] : state.castling.queen[player];
            if (canCastle) {
                builder.put(c);
            }
        }
    }
    // En passant
    builder.put(" ");
    builder.put(state.enPassant == MCoord.invalid ? "-" : state.enPassant.getRepr);
    // Half and FullMove
    builder.put(" %d %d".format(state.halfMove, state.fullMove));
    return builder.data();
}

unittest {
    const boards = [
        "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
        "3k4/8/8/8/2B5/8/8/3K4 w - - 0 1",
        "3k4/8/8/8/2B5/8/8/3K4 w KQk - 0 1",
        "3k4/8/8/8/2B5/8/8/3K4 b KQk - 1 1",
        "3k4/8/8/8/2B5/8/8/3K4 w KQk - 2 2",
        "4k3/4p3/8/8/8/8/4P3/4K3 b KQkq - 0 1",
    ];
    foreach (board; boards) {
        auto parsed = board.parseFen;
        assert(parsed.toFen == board);
    }
}

unittest {
    auto parsed = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2".parseFen;
    assert(*parsed.board.getSquare(5, 5) == Square());
    assert(*parsed.board.getSquare(0, 0) == Square(Player.white, Piece.rook));
    assert(parsed.turn == Player.black);
    assert(parsed.castling == Castling.all);
    assert(parsed.halfMove == 1);
    assert(parsed.fullMove == 2);
    assert(MCoord(3, 4).getRepr == "d5");
    assert(Move(MCoord(3, 4), MCoord(7, 0)).getRepr == "d5h1");
}

struct MoveDest {
    GameState board;
    Move move;
    // Positive for white, negative for black
    float eval;

    string toString() const => format("%s = %s", move, eval);
}

static ulong numEvals;

float leafEval(GameState state) {
    auto sum = 0.0;
    // TODO: One true source for this
    static const int[] VALUES = [0, 1, 5, 3, 3, 9, 4];
    foreach (rank; 0 .. 8) {
        foreach (file; 0 .. 8) {
            const auto square = state.board.getSquare(file, rank);
            auto piece = square.getPiece();
            if (piece == Piece.empty) {
                continue;
            }
            auto centerCoeff = abs(((rank / 3.5) - 1) * ((file / 3.5) - 1));
            if (piece != Piece.king) {
                centerCoeff = 1 - centerCoeff;
            }
            auto sign = square.getPlayer == Player.black ? -1 : 1;
            int value = VALUES[piece];
            sum += sign * value * (1 + .05 * centerCoeff);
        }
    }
    ++numEvals;
    return sum;
}

unittest {
    // KB > k, even if K close to center
    assert("8/8/8/3k4/8/8/4B3/3K4 w - - 0 1".parseFen.leafEval >= 0);
    // KB < kb if b closer to center
    assert("3k4/8/8/4b3/8/8/4B3/3K4 w - - 0 1".parseFen.leafEval <= 0);
    // KBB > kb
    assert("3k4/8/8/4b3/8/8/3BB3/3K4 w - - 0 1".parseFen.leafEval >= 0);
    // KQR > krr with rr close to center
    assert("3k4/8/8/3rr3/8/8/8/Q2K3R w - - 0 1".parseFen.leafEval > 0);
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
