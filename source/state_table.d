module snapper.state_table;

import std.exception;
import snapper.repr;

bool isSame(const GameState *a, const GameState *b) {
    return *a == *b;
}

struct GameStateTable {
    GameState[] states;

    @disable
    this();

    this(size_t numBytesToUse) {
        auto length = numBytesToUse / GameState.sizeof;
        enforce(length > 16);
        states.length = length;
    }

    ulong hashSlot(const ref GameState state) {
        return state.hashOf % states.length;
    }

    void replace(const ref GameState state) {
        states[hashSlot(state)] = state;
    }

    bool contains(const ref GameState state) {
        return (&state).isSame(&states[hashSlot(state)]);
    }

    // Returns true if already contained. Replaces and returns false if not.
    bool containsOrReplace(const ref GameState state) {
        auto slot = hashSlot(state);
        if ((&state).isSame(&states[slot])) {
            return true;
        }
        states[slot] = state;
        return false;
    }
}
