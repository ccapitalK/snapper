module snapper.bit.move;

import core.bitop;
import std.logger;

import snapper.bit;
import snapper.repr;

/// Get the position of the lowest set bit of v, with bit 0 being 0;
uint bitPos(ulong v) {
    assert(v > 0);
    return bsf(v);
}

MCoord coordFromBit(ulong v) {
    auto pos = v.bitPos;
    return MCoord(pos % 8, pos / 8);
}

// Get mask with entire rows filled if any item in row present
PositionMask fillRows(PositionMask input) {
    ulong set;
    input.iterateBits!(v => set |= 0xFFUL << (8 * (v.bitPos / 8)));
    return PositionMask(set);
}

// Get mask with entire columns filled if any item in column present
PositionMask fillCols(PositionMask input) {
    const ulong pattern = 0x0101_0101_0101_0101UL;
    ulong set;
    input.iterateBits!(v => set |= pattern << (v.bitPos % 8));
    return PositionMask(set);
}

unittest {
    assert((0x01UL).bitPos == 0);
    assert((0x08UL).bitPos == 3);
    assert((0x10UL).bitPos == 4);
    auto mask = PositionMask(0x0030_3A00_0000_0100UL);
    assert(mask.fillRows.value == 0x00FF_FF00_0000_FF00UL);
    assert(mask.fillCols.value == 0x3B3B_3B3B_3B3B_3B3BUL);
}

struct DiagonalTable {
    // Mask for each diagonal, each diagonal spanning from top left -> bottom right
    ulong[15] bottomRight;
    // Mask for each diagonal, each diagonal spanning from top right -> bottom left
    ulong[15] topRight;
}

static const DiagonalTable DIAGONAL_TABLE = {
    DiagonalTable table;
    foreach (i; 0 .. 64) {
        auto v = 1UL << i;
        auto x = i % 8;
        auto y = i / 8;
        table.bottomRight[x + y] |= v;
        table.topRight[7 + x - y] |= v;
    }
    return table;
}();

PositionMask fillDiagonal(PositionMask input) {
    ulong set;
    input.iterateBits!((ulong v) {
        auto pos = v.bitPos;
        auto x = pos % 8;
        auto y = pos / 8;
        set |= DIAGONAL_TABLE.bottomRight[x + y];
        set |= DIAGONAL_TABLE.topRight[x + 7 - y];
    });
    return PositionMask(set);
}

PositionMask getDiagonalFirstIntersect(PositionMask source, PositionMask obstacles) {
    assert(source.numOccupied == 1);
    PositionMask diag = source.fillDiagonal();
    ulong set;
    // TODO: This might be possible without iterating, if so we should do so
    diag.iterateBits!((ulong v) {
        if ((obstacles.value & v) == 0) {
            return;
        }
        auto pos = v.bitPos;
        auto x = pos % 8;
        auto y = pos / 8;
        set |= DIAGONAL_TABLE.bottomRight[x + y];
        set |= DIAGONAL_TABLE.topRight[x + 7 - y];
    });
    return PositionMask(set);
}

// .X.....X
// ..X...X.
// ...X.X..
// ....X...
// ...X.X..
// ..X...X.
// .X.....X
// X.......

unittest {
    assert(PositionMask(1).fillDiagonal.numOccupied == 8);
    assert(PositionMask(128).fillDiagonal.numOccupied == 8);

    assert(PositionMask(MCoord(4, 4)).fillDiagonal.numOccupied == 14);
    assert(PositionMask(MCoord(3, 4)).fillDiagonal.numOccupied == 14);

    foreach (i; 0 .. 8) {
        assert(PositionMask(MCoord(i, 7)).fillDiagonal.numOccupied == 8);
    }

    PositionMask bishopMask, interceptMask;
    bishopMask.setPos(MCoord(2, 4), true);
    bishopMask.setPos(MCoord(7, 7), true);
    assert(bishopMask.fillDiagonal.intersection(PositionMask(MCoord(3, 3))) != PositionMask.empty);
    assert(bishopMask.fillDiagonal.intersection(PositionMask(MCoord(1, 1))) != PositionMask.empty);
    assert(bishopMask.fillDiagonal.intersection(PositionMask(MCoord(6, 1))) == PositionMask.empty);
    interceptMask.setPos(MCoord(5, 1), true);
    interceptMask.setPos(MCoord(6, 0), true);
    interceptMask.setPos(MCoord(6, 1), true);
    interceptMask.setPos(MCoord(3, 3), true);
    assert(bishopMask.fillDiagonal.intersection(interceptMask).numOccupied == 3);
}
