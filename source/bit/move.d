module snapper.bit.move;

import core.bitop;
import std.logger;
import std.range;

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

ulong bitsWhere(alias predicate)() {
    ulong set;
    foreach (y; 0 .. 8) {
        foreach (x; 0 .. 8) {
            ulong v = 1UL << (x + 8 * y);
            if (predicate(x, y)) {
                set |= v;
            }
        }
    }
    return set;
}

struct StaticTables {
    // Mask for each diagonal, each diagonal spanning from top left -> bottom right
    ulong[15] diagBottomRight;
    // Mask for each diagonal, each diagonal spanning from top right -> bottom left
    ulong[15] diagTopRight;
    // Masks of bits that are exclusively in a specific direction (ignoring other axis) of index
    ulong[8] left;
    ulong[8] right;
    ulong[8] up;
    ulong[8] down;
    // Masks of positions that are the same row/column as the index
    ulong[8] row;
    ulong[8] column;
    static const string[2] xDirs = ["left", "right"];
    static const string[2] yDirs = ["down", "up"];
}

// Initialize the static tables
static const StaticTables STATIC_TABLES = {
    StaticTables tables;
    foreach (i; 0 .. 64) {
        auto v = 1UL << i;
        auto x = i % 8;
        auto y = i / 8;
        tables.diagBottomRight[x + y] |= v;
        tables.diagTopRight[7 + x - y] |= v;
    }
    foreach (i; 0 .. 8) {
        tables.left[i] = bitsWhere!((x, y) => x < i);
        tables.right[i] = bitsWhere!((x, y) => x > i);
        tables.up[i] = bitsWhere!((x, y) => y > i);
        tables.down[i] = bitsWhere!((x, y) => y < i);
        tables.row[i] = bitsWhere!((x, y) => y == i);
        tables.column[i] = bitsWhere!((x, y) => x == i);
    }
    return tables;
}();

// Get mask with entire rows filled if any item in row present
PositionMask fillRows(PositionMask input) {
    ulong set;
    // input.iterateBits!(v => set |= 0xFFUL << (8 * (v.bitPos / 8)));
    input.iterateBits!(v => set |= STATIC_TABLES.row[v.bitPos / 8]);
    return PositionMask(set);
}

// Get mask with entire columns filled if any item in column present
PositionMask fillCols(PositionMask input) {
    // const ulong pattern = 0x0101_0101_0101_0101UL;
    // ulong set;
    // input.iterateBits!(v => set |= pattern << (v.bitPos % 8));
    ulong set;
    input.iterateBits!(v => set |= STATIC_TABLES.column[v.bitPos % 8]);
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

PositionMask fillDiagonal(PositionMask input) {
    ulong set;
    if (input.numOccupied < 6) {
        input.iterateBits!((ulong v) {
            auto pos = v.bitPos;
            auto x = pos % 8;
            auto y = pos / 8;
            set |= STATIC_TABLES.diagBottomRight[x + y];
            set |= STATIC_TABLES.diagTopRight[x + 7 - y];
        });
    } else {
        foreach (v; STATIC_TABLES.diagTopRight[].chain(STATIC_TABLES.diagBottomRight[])) {
            if ((input.value & v) != 0) {
                set |= v;
            }
        }
    }
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
        throw new Exception("Unimplemented");
    });
    return PositionMask(set);
}

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

PositionMask getKnightMoves(PositionMask input) {
    ulong set;
    // For each of the 8 knight moves
    static foreach (sx; 0 .. 2) {
        static foreach (sy; 0 .. 2) {
            static foreach (dxIsLarger; 0 .. 2) {
                {
                    static const int udx = (dxIsLarger ? 2 : 1);
                    static const int udy = (dxIsLarger ? 1 : 2);
                    // Construct the knight move as a (dx, dy) tuple from the source square
                    const int dx = udx * SIGNS[sx];
                    const int dy = udy * SIGNS[sy];
                    // We want to ignore source positions that would go off the board when performing this
                    // move. Mask only the set bits in input that can perform this move.
                    static const auto xMask = mixin("STATIC_TABLES." ~ STATIC_TABLES.xDirs[!sx])[sx ? 8 - udx: udx - 1];
                    static const auto yMask = mixin("STATIC_TABLES." ~ STATIC_TABLES.yDirs[!sy])[sy ? 8 - udy: udy - 1];
                    // The final calculated shift left (can be negative) that this move is equivalent to
                    static const auto shift = dx + 8 * dy;
                    auto validSourcePositions = input.value & xMask & yMask;
                    static if (shift > 0) {
                        set |= validSourcePositions << shift;
                    } else {
                        set |= validSourcePositions >> -shift;
                    }
                }
            }
        }
    }
    return PositionMask(set);
}

unittest {
    assert(PositionMask.empty.getKnightMoves.numOccupied == 0);
    assert(PositionMask(MCoord(0, 0)).getKnightMoves.numOccupied == 2);
    assert(PositionMask(MCoord(7, 0)).getKnightMoves.numOccupied == 2);
    assert(PositionMask(MCoord(7, 7)).getKnightMoves.numOccupied == 2);
    assert(PositionMask(MCoord(1, 1)).getKnightMoves.numOccupied == 4);
    assert(PositionMask(MCoord(1, 2)).getKnightMoves.numOccupied == 6);
    assert(PositionMask(MCoord(2, 2)).getKnightMoves.numOccupied == 8);
    assert(PositionMask(MCoord(5, 5)).getKnightMoves.numOccupied == 8);
    assert(PositionMask(MCoord(6, 5)).getKnightMoves.numOccupied == 6);
    assert(PositionMask(MCoord(2, 2)).getKnightMoves.value == 0x0000_000A_1100_110AUL);
}

PositionMask getAdjacent(PositionMask input) {
    ulong set;
    static foreach (dy; atMostOne) {
        static foreach (dx; atMostOne) {
            if (dx != 0 || dy != 0) {
                static const auto sx = dx >= 0;
                static const auto sy = dy >= 0;
                static const auto xMask = mixin("STATIC_TABLES." ~ STATIC_TABLES.xDirs[!sx])[sx ? 7: 0];
                static const auto yMask = mixin("STATIC_TABLES." ~ STATIC_TABLES.yDirs[!sy])[sy ? 7: 0];
                static const auto shift = dx + 8 * dy;
                auto validSourcePositions = input.value & (dx != 0 ? xMask
                        : ~0UL) & (dy != 0 ? yMask : ~0UL);
                static if (shift > 0) {
                    set |= validSourcePositions << shift;
                } else {
                    set |= validSourcePositions >> -shift;
                }
            }
        }
    }
    return PositionMask(set);
}

unittest {
    assert(PositionMask.empty.getAdjacent.numOccupied == 0);
    assert(PositionMask(MCoord(0, 0)).getAdjacent.numOccupied == 3);
    assert(PositionMask(MCoord(0, 1)).getAdjacent.numOccupied == 5);
    assert(PositionMask(MCoord(1, 0)).getAdjacent.numOccupied == 5);
    assert(PositionMask(MCoord(7, 7)).getAdjacent.numOccupied == 3);
    assert(PositionMask(MCoord(7, 1)).getAdjacent.numOccupied == 5);
    assert(PositionMask(MCoord(6, 1)).getAdjacent.numOccupied == 8);
    assert(PositionMask(MCoord(1, 1)).getAdjacent.value == 0x0000_0000_0007_0507UL);
}

PositionMask fillLeft(PositionMask input) {
    auto v = input.value;
    v |= (v & STATIC_TABLES.right[3]) >> 4;
    v |= (v & STATIC_TABLES.right[1]) >> 2;
    v |= (v & STATIC_TABLES.right[0]) >> 1;
    return PositionMask(v);
}

PositionMask fillRight(PositionMask input) {
    auto v = input.value;
    v |= (v & STATIC_TABLES.left[4]) << 4;
    v |= (v & STATIC_TABLES.left[6]) << 2;
    v |= (v & STATIC_TABLES.left[7]) << 1;
    return PositionMask(v);
}

PositionMask fillDown(PositionMask input) {
    auto v = input.value;
    v |= v >> 32;
    v |= v >> 16;
    v |= v >> 8;
    return PositionMask(v);
}

PositionMask fillUp(PositionMask input) {
    auto v = input.value;
    v |= v << 32;
    v |= v << 16;
    v |= v << 8;
    return PositionMask(v);
}

unittest {
    auto v = PositionMask(0x0000_0000_1000_0500UL);
    assert(v.fillLeft == PositionMask(0x0000_0000_1f00_0700UL));
    assert(v.fillRight == PositionMask(0x0000_0000_f000_ff00UL));
    assert(v.fillDown == PositionMask(0x0000_0000_1010_1515UL));
    assert(v.fillUp == PositionMask(0x1515_1515_1505_0500UL));
}
