module snapper.opening_table;

import std.array;
import std.algorithm;
import std.logger;
import std.typecons;
import snapper.agent;
import snapper.repr;

struct OpeningTable {
    private uint[Move][GameState] validMoves;

    // Returns KV pair of Move -> incidence
    Tuple!(Move, uint)[] lookupPosition(const ref GameState state) {
        if (state !in validMoves) {
            return [];
        }
        return validMoves[state].byPair.map!(a => tuple(a[0], a[1])).array;
    }
}

OpeningTable makeOpeningTable(string tableData) {
    OpeningTable table;
    GameState initial = START_POSITION.parseFen;
    foreach (line; tableData.splitter('\n')) {
        GameState state = initial;
        foreach (moveStr; line.splitter(' ')) {
            auto move = moveStr.parseMove;
            table.validMoves[state][move] += 1;
            state = state.performMove(move).state;
        }
    }
    info("Initialized opening table with ", table.validMoves.length, " positions");
    return table;
}

unittest {
    auto table = "e2e4 g8f6 d2d3\ne2e4 g8f6 e4e5 f6d5 b1a3".makeOpeningTable;
    auto initial = START_POSITION.parseFen;
    info(table.lookupPosition(initial));
    assert(table.lookupPosition(initial).length == 1);
    auto e2e4Pos = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1".parseFen;
    info(table.lookupPosition(e2e4Pos));
    assert(table.lookupPosition(e2e4Pos).length == 1);
    auto g8f6Pos = "rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2".parseFen;
    info(table.lookupPosition(g8f6Pos));
    assert(table.lookupPosition(g8f6Pos).length == 2);
}
