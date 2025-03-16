module snapper.repr.types;

import std.ascii;
import std.exception;
import std.range;
import std.typecons;
import std.traits;

static const int[2] SIGNS = [-1, 1];
static const MCoord[4] DIRS = [
    MCoord(0, 1), MCoord(1, 0), MCoord(0, -1), MCoord(-1, 0),
];
static auto atMostOne() => iota(-1, 2);

size_t numMembers(E)() if (is(E == enum)) {
    return (EnumMembers!E).length;
}

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

string toString(MCoord m) {
    enforce(m.isInBounds);
    return cast(string)['a' + m.x, '1' + m.y];
}

MCoord parseCoord(string coordString) {
    enforce(coordString.length == 2);
    auto coord = MCoord(
        cast(ubyte)(coordString[0] - 'a'),
        cast(ubyte)(coordString[1] - '1'),
    );
    enforce(coord.isInBounds);
    return coord;
}

enum Player : ubyte {
    white = 0,
    black,
}

static assert(numMembers!Player == 2);

// Note: A bunch of code assumes these exact backing values for each piece
enum Piece : ubyte {
    empty = 0,
    pawn,
    rook,
    knight,
    bishop,
    queen,
    king,
}

static assert(numMembers!Piece == 7);

static const auto pieceByFenName = [
    tuple('p', Piece.pawn, 1),
    tuple('r', Piece.rook, 5),
    tuple('n', Piece.knight, 3),
    tuple('b', Piece.bishop, 3),
    tuple('q', Piece.queen, 9),
    tuple('k', Piece.king, 100_000),
];

int value(Piece piece) {
    static foreach (t; pieceByFenName) {
        if (piece == t[1]) {
            return t[2];
        }
    }
    return 0;
}

static const auto NONEMPTY_PIECES = EnumMembers!Piece[1 .. $];

Piece nonEmpty(Piece v) {
    enforce(v != Piece.empty);
    return v;
}

private int[16] genValuesArr() {
    int[16] x;
    foreach (i; 0 .. pieceByFenName.length) {
        x[i + 1] = pieceByFenName[i][2];
        x[8 + i + 1] = -pieceByFenName[i][2];
    }
    return x;
}

align(1) struct Square {
    private const static int[16] VALUES = genValuesArr();
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

    char toString() const {
        char c = ' ';
        auto piece = getPiece;
        static foreach (v; pieceByFenName) {
            if (piece == v[1]) {
                c = v[0];
            }
        }
        return getPlayer == Player.white ? std.ascii.toUpper(c) : c;
    }

    int value() const nothrow => VALUES[v & 0xf];

    bool isEmpty() const => v == 0;
    static const Square empty;
}

static assert(Square.sizeof == 1);
