import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
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
auto atMostOne() => iota(-1, 2);

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
    tuple('p', Piece.pawn),
    tuple('r', Piece.rook),
    tuple('n', Piece.knight),
    tuple('b', Piece.bishop),
    tuple('q', Piece.queen),
    tuple('k', Piece.king),
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

void print(const ref Board board) {
    write(board.getAsciiArtRepr);
}

bool isEmpty(const ref Board board, MCoord coord) => board.getSquare(coord).isEmpty;

struct Castling {
    bool[EnumMembers!Player.length] king;
    bool[EnumMembers!Player.length] queen;
}

struct GameState {
    Board board;
    Player turn;
    Castling castling;
    MCoord enPassant;
    ushort halfMove;
    ushort fullMove;
}

float leafEval(GameState state) {
    return 0;
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
    fen.castling = Castling([false, false], [false, false]);
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

unittest {
    auto parsed = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2 ".parseFen;
    assert(*parsed.board.getSquare(5, 5) == Square());
    assert(*parsed.board.getSquare(0, 0) == Square(Player.white, Piece.rook));
    assert(parsed.turn == Player.black);
    assert(parsed.castling == Castling([true, true], [true, true]));
    assert(parsed.halfMove == 1);
    assert(parsed.fullMove == 2);
    assert(MCoord(3, 4).getRepr == "d5");
    assert(Move(MCoord(3, 4), MCoord(7, 0)).getRepr == "d5h1");
}

struct MoveDest {
    GameState board;
    Move move;
}

MoveDest performMove(const ref GameState state, MCoord source, MCoord dest) {
    // TODO: Mutate the board as well, needed for tree search
    return MoveDest(state, Move(source, dest));
}

pragma(inline, true)
bool canTakeOrMove(const ref GameState state, MCoord source, MCoord dest) {
    writefln("Check %s %s", source, dest);
    if (!dest.isInBounds) {
        return false;
    }
    auto destSquare = state.board.getSquare(dest);
    return destSquare.isEmpty || destSquare.getPlayer != state.turn;
}

pragma(inline, true)
bool canTake(const ref GameState state, MCoord source, MCoord dest) {
    writefln("Check %s %s", source, dest);
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
            writefln("Adding king move %d %d", dx, dy);
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
    foreach (move; moves) {
        info(move.move.getRepr);
    }
    return moves;
}
