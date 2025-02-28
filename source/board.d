import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.string;
import std.typecons;

struct MCoord {
    // File, from 0
    ubyte x;
    // Rank, from 0
    ubyte y;
    static const MCoord invalid = MCoord(255, 255);
}

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

    Square* getSquare(size_t file, size_t rank) => &pieces[file + 8 * rank];
    const(Square)* getSquare(size_t file, size_t rank) const => &pieces[file + 8 * rank];
}

string getAsciiArtRepr(const ref Board board) {
    auto builder = appender(cast(string) []);
    foreach (y; 0 .. 8) {
        auto rank = 7 - y;
        builder.put(format("%d  ", rank + 1));
        foreach (x; 0 .. 8) {
            auto file = 7 - x;
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

struct Castling {
    bool whiteKing;
    bool whiteQueen;
    bool blackKing;
    bool blackQueen;
}

struct ParsedFen {
    Board board;
    Player move;
    Castling castling;
    MCoord enPassant;
    uint halfMove;
    uint fullMove;
}

ParsedFen parseFen(string input) {
    ParsedFen fen;
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
            *fen.board.getSquare(7 - file, 7 - rank) = Square(player, piece);
            ++file;
        }
    }

    fen.move = parts[1][0] == 'b' ? Player.black : Player.white;
    string castling = parts[2];
    fen.castling = Castling(false, false, false, false);
    foreach (c; castling) {
        switch (c) {
        case 'K':
            fen.castling.whiteKing = 1;
            break;
        case 'Q':
            fen.castling.whiteQueen = 1;
            break;
        case 'k':
            fen.castling.blackKing = 1;
            break;
        case 'q':
            fen.castling.blackQueen = 1;
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
    fen.halfMove = parts[4].to!int;
    fen.fullMove = parts[5].to!int;
    return fen;
}

unittest {
    auto parsed = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2 ".parseFen;
    assert(*parsed.board.getSquare(5, 5) == Square());
    assert(*parsed.board.getSquare(0, 0) == Square(Player.white, Piece.rook));
    assert(parsed.move == Player.black);
    assert(parsed.castling == Castling(true, true, true, true));
    assert(parsed.halfMove == 1);
    assert(parsed.fullMove == 2);
}
