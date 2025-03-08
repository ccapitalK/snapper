module chess_engine.repr.board;

import std.algorithm;
import std.ascii;
import std.array;
import std.conv;
import std.format;
import std.math;
import std.exception;
import std.logger;
import std.range;
import std.stdio;
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
        char c = ' ';
        auto piece = getPiece;
        static foreach (v; pieceByFenName) {
            if (piece == v[1]) {
                c = v[0];
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
