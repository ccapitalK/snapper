module snapper.bit.board;

import core.bitop;
import std.algorithm;
import std.exception;
import std.format;
import std.logger;
import std.traits;

import snapper.bit;
import snapper.repr.types;

// TODO: We may want to replace enforcements with assertions here

struct PositionMask {
    ulong value = 0;

    this(ulong value) {
        this.value = value;
    }

    this(MCoord coord) {
        setPos(coord, true);
    }

    static bool inBounds(byte x, byte y) => 0 <= x && x < 8 && 0 <= y && y < 8;

    bool getPos(MCoord coord) const => getPos(coord.x, coord.y);
    bool getPos(byte x, byte y) const {
        enforce(inBounds(x, y));
        return 1UL & (value >> (8 * y + x));
    }

    void setPos(MCoord coord, byte v) => setPos(coord.x, coord.y, v);
    void setPos(byte x, byte y, byte v) {
        enforce(inBounds(x, y));
        auto mask = 1UL << (8 * y + x);
        value = (value & (~mask)) | (v * mask);
    }

    void clear() {
        value = 0;
    }

    uint numOccupied() const => value.popcnt;
    PositionMask negated() const => PositionMask(~value);

    PositionMask union_(PositionMask other) const => PositionMask(value | other.value);
    PositionMask intersection(PositionMask other) const => PositionMask(value & other.value);

    string toString() const => format("PositionMask(%x)", value);

    static const PositionMask empty = PositionMask();
}

// TODO: Experiment and benchmark MSSB vs LSSB iteration
// Iterate over every set bit of the mask, as the isolated bit
void iterateBits(alias func)(const ref PositionMask mask) {
    ulong value = mask.value;
    while (value > 0) {
        // Iterate by Least Significant Set Bit (LSSB)
        auto minBit = value & -value;
        func(minBit);
        value ^= minBit;
    }
}

static assert(PositionMask.sizeof == 8);

unittest {
    PositionMask mask;

    mask.setPos(0, 0, true);
    assert(mask.getPos(0, 0));
    assert(mask.value == 1UL);

    mask.setPos(3, 4, true);
    assert(mask.getPos(3, 4));
    assert(mask.value == 0x8_0000_0001UL);

    assert(!mask.getPos(0, 1));
    mask.setPos(0, 1, false);
    assert(!mask.getPos(0, 1));
    assert(mask.value == 0x8_0000_0001UL);

    mask.setPos(0, 0, false);
    assert(!mask.getPos(0, 0));
    assert(mask.value == 0x8_0000_0000UL);

    assert(!mask.getPos(7, 7));
    mask.setPos(7, 7, true);
    assert(mask.getPos(7, 7));
    assert(mask.value == 0x8000_0008_0000_0000UL);

    mask.setPos(1, 0, true);
    ulong[] arr;
    mask.iterateBits!(v => arr ~= v);
    assert(arr == [0x2UL, 0x8_0000_0000UL, 0x8000_0000_0000_0000UL]);
}

// Note: Invariant that there are no intersections anywhere
// TODO: Convert to white bitboard + piece boards, 12 dwords -> 7 dwords
struct BitBoard {
    // BitMask for each (Piece, Player) combination
    private PositionMask white;
    private PositionMask[numMembers!Piece - 1] masks;
    private PositionMask playerMask(Player player) const
        => player == Player.black ? white.negated : white;

    PositionMask occupied(Piece piece, Player player) const
        => masks[piece.nonEmpty - 1].intersection(playerMask(player));

    void setPiece(Piece piece, Player player, MCoord pos) {
        foreach (maskPiece; EnumMembers!Piece[1 .. $]) {
            masks[maskPiece - 1].setPos(pos, piece == maskPiece);
        }
        white.setPos(pos, player == Player.white);
    }

    PositionMask occupied(Player player) const => occupied.intersection(playerMask(player));
    PositionMask occupied(Piece piece) const => masks[piece.nonEmpty - 1];

    PositionMask occupied() const => masks[].fold!((a, b) => a.union_(b));
}

static assert(BitBoard.sizeof == 7 * 8);

PositionMask aggregate(alias predicate)(const ref BitBoard board) {
    PositionMask acc;
    foreach (piece; EnumMembers!Piece[1 .. $]) {
        if (predicate(piece)) {
            acc.value |= board.occupied(piece).value;
        }
    }
    return acc;
}

unittest {
    BitBoard board;
    assert(board.occupied.value == 0);
    PositionMask mask;
    mask.setPos(1, 1, true);
    mask.setPos(6, 7, true);
    assert(mask.value == 0x4000_0000_0000_0200UL);
    mask.iterateBits!(v => board.setPiece(Piece.bishop, Player.white, v.coordFromBit));
    assert(board.occupied() == mask);
    assert(board.occupied(Player.white) == mask);
    assert(board.occupied(Player.black) != mask);
    assert(board.occupied(Piece.bishop) == mask);
    assert(board.occupied(Piece.king) != mask);
    assert(board.occupied(Piece.queen) != mask);
    assert(board.occupied(Piece.bishop, Player.white) == mask);
    assert(board.occupied(Piece.bishop, Player.black) != mask);
    assert(board.occupied(Piece.pawn, Player.white) != mask);
}
