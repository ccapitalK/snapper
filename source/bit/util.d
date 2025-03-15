module snapper.bit.util;

import core.bitop;

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

ulong bitFromCoord(MCoord coord) {
    assert(coord.isInBounds);
    return 1UL << (coord.x + 8 * coord.y);
}

ulong bitsWhere(alias predicate)() {
    ulong set;
    foreach (y; 0 .. 8) {
        foreach (x; 0 .. 8) {
            ulong v = MCoord(x, y).bitFromCoord;
            if (predicate(x, y)) {
                set |= v;
            }
        }
    }
    return set;
}
