module snapper.bit.board;

import core.bitop;
import std.exception;
import std.logger;
import std.traits;

import snapper.repr.types;

// TODO: We may want to replace enforcements with assertions here

struct PositionMask {
    ulong value = 0;

    static bool inBounds(byte x, byte y) => 0 <= x && x < 8 && 0 <= y && y < 8;

    bool getPos(byte x, byte y) const {
        enforce(inBounds(x, y));
        return 1UL & (value >> (8 * y + x));
    }

    void setPos(byte x, byte y, byte v) {
        enforce(inBounds(x, y));
        auto mask = 1UL << (8 * y + x);
        value = (value & (~mask)) | (v * mask);
    }

    uint numOccupied() const => value.popcnt;

    PositionMask negated() const => PositionMask(~value);
}

// TODO: Experiment and benchmark MSSB vs LSSB iteration
void iterate(alias func)(const ref PositionMask mask) {
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
    mask.iterate!(v => arr ~= v);
    assert(arr == [0x2UL, 0x8_0000_0000UL, 0x8000_0000_0000_0000UL]);
}

// TODO: Convert to white bitboard + piece boards, 12 dwords -> 7 dwords
struct BitBoard {
    // BitMask for each (Piece, Player) combination
    private PositionMask[numMembers!Piece - 1][numMembers!Player] masks;

    PositionMask occupied(Piece piece, Player player) const => masks[player][piece.nonEmpty - 1];
    PositionMask setMask(Piece piece, Player player, PositionMask mask) => masks[player][piece.nonEmpty - 1] = mask;

    PositionMask occupied(Player playerToMatch) const => this.aggregate!((_, player) => player == playerToMatch);
    PositionMask occupied(Piece pieceToMatch) const => this.aggregate!((piece, _) => piece == pieceToMatch);

    PositionMask occupied() const => this.aggregate!((_1, _2) => true);
}

static assert(BitBoard.sizeof == 12 * 8);

PositionMask aggregate(alias predicate)(const ref BitBoard board) {
    PositionMask acc;
    foreach (player; EnumMembers!Player) {
        foreach (piece; EnumMembers!Piece[1 .. $]) {
            if (predicate(piece, player)) {
                acc.value |= board.occupied(piece, player).value;
            }
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
    board.setMask(Piece.bishop, Player.white, mask);
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
