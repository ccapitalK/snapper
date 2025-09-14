module snapper.state_table;

import std.exception;

import snapper.repr;
import snapper.search;

bool isSame(const GameState *a, const GameState *b) {
    return *a == *b;
}

struct ScoredGameState {
    GameState state;
    SearchNode node;
}

struct GameStateTable {
    ScoredGameState[] states;

    @disable
    this();

    this(size_t numBytesToUse) {
        auto length = numBytesToUse / ScoredGameState.sizeof;
        enforce(length > 16);
        states.length = length;
    }

    void clear() {
        foreach (ref v; states) {
            v.node = null;
        }
    }

    ulong hashSlot(const ref GameState state) {
        return state.hashOf % states.length;
    }

    ScoredGameState *get(const ref GameState state) {
        return &states[hashSlot(state)];
    }
}

bool hasScore(const ref GameState state, ScoredGameState *scored) {
    return scored.node !is null && (&state).isSame(&scored.state);
}
