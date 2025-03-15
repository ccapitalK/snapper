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

    this(ulong value) nothrow {
        this.value = value;
    }

    this(MCoord coord) {
        setPos(coord, true);
    }

    bool getPos(MCoord coord) const {
        enforce(coord.isInBounds());
        return 1UL & (value >> (8 * coord.y + coord.x));
    }

    void setPos(MCoord coord, byte v) {
        enforce(coord.isInBounds());
        auto mask = coord.bitFromCoord;
        value = (value & (~mask)) | (v * mask);
    }

    void clear() {
        value = 0;
    }

    uint numOccupied() const => value.popcnt;
    PositionMask negated() const => PositionMask(~value);

    PositionMask union_(PositionMask other) const nothrow => PositionMask(value | other.value);
    PositionMask intersection(PositionMask other) const nothrow => PositionMask(value & other.value);

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

    auto coord = MCoord(0, 0);
    mask.setPos(coord, true);
    assert(mask.getPos(coord));
    assert(mask.value == 1UL);

    coord = MCoord(3, 4);
    mask.setPos(coord, true);
    assert(mask.getPos(coord));
    assert(mask.value == 0x8_0000_0001UL);

    coord = MCoord(0, 1);
    assert(!mask.getPos(coord));
    mask.setPos(coord, false);
    assert(!mask.getPos(coord));
    assert(mask.value == 0x8_0000_0001UL);

    coord = MCoord(0, 0);
    mask.setPos(coord, false);
    assert(!mask.getPos(coord));
    assert(mask.value == 0x8_0000_0000UL);

    coord = MCoord(7, 7);
    assert(!mask.getPos(coord));
    mask.setPos(coord, true);
    assert(mask.getPos(coord));
    assert(mask.value == 0x8000_0008_0000_0000UL);

    coord = MCoord(1, 0);
    mask.setPos(coord, true);
    ulong[] arr;
    mask.iterateBits!(v => arr ~= v);
    assert(arr == [0x2UL, 0x8_0000_0000UL, 0x8000_0000_0000_0000UL]);
}

// Note: Invariant that there are no intersections anywhere
// TODO: Convert to white bitboard + piece boards, 12 dwords -> 7 dwords
struct BitBoard {
    // BitMask for each (Piece, Player) combination
    PositionMask whiteMask;
    private PositionMask[numMembers!Piece - 1] masks;
    private PositionMask playerMask(Player player) const
        => player == Player.black ? whiteMask.negated : whiteMask;

    PositionMask occupied(Piece piece, Player player) const
        => masks[piece.nonEmpty - 1].intersection(playerMask(player));

    void setSquare(MCoord pos, Square square) {
        foreach (maskPiece; NONEMPTY_PIECES) {
            masks[maskPiece - 1].setPos(pos, square.getPiece == maskPiece);
        }
        whiteMask.setPos(pos, square.getPlayer == Player.white);
    }
    Square getSquare(MCoord coord) const {
        auto posMask = PositionMask(coord.bitFromCoord);
        foreach (piece; NONEMPTY_PIECES) {
            auto mask = masks[piece - 1];
            if (mask.intersection(posMask) != PositionMask.empty) {
                auto player = whiteMask.intersection(posMask) == PositionMask.empty
                    ? Player.black : Player.white;
                return Square(player, piece);
            }
        }
        return Square.empty;
    }

    PositionMask occupied(Player player) const => occupied.intersection(playerMask(player));
    PositionMask occupied(Piece piece) const => masks[piece.nonEmpty - 1];

    PositionMask occupied() const => masks[].fold!((a, b) => a.union_(b));

    size_t toHash() const nothrow {
        static const auto PRIME = 0x100000001B3UL;
        size_t hash = 0xCBF29CE484222325UL;
        PositionMask all = PositionMask.empty;
        foreach (piece; NONEMPTY_PIECES) {
            auto mask = masks[piece - 1];
            hash = (hash ^ mask.value) * PRIME;
            all = all.union_(mask);
        }
        hash = (hash ^ all.intersection(whiteMask).value) * PRIME;
        return hash;
    }

    bool opEquals(const BitBoard other) const {
        PositionMask all = PositionMask.empty;
        foreach (piece; NONEMPTY_PIECES) {
            auto mask = masks[piece - 1];
            if (mask != other.masks[piece - 1]) {
                return false;
            }
            all = all.union_(mask);
        }
        return all.intersection(whiteMask) == all.intersection(other.whiteMask);
    }
}

static assert(BitBoard.sizeof == 7 * 8);

PositionMask aggregate(alias predicate)(const ref BitBoard board) {
    PositionMask acc;
    foreach (piece; NONEMPTY_PIECES) {
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
    mask.setPos(MCoord(1, 1), true);
    mask.setPos(MCoord(6, 7), true);
    assert(mask.value == 0x4000_0000_0000_0200UL);
    assert(mask.numOccupied == 2);
    mask.iterateBits!(v => board.setSquare(v.coordFromBit, Square(Player.white, Piece.bishop)));
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
