module piranha.slist;

import std.exception;

// I'm surprised this is the first allocator I needed
struct SListNode(T) {
    uint next;
    T value;
}

struct SListPool(T) {
    private SListNode[] nodes;
    size_t first;
    const static uint noneIndex = uint.max;

    this(uint capacity) {
        enforce(capacity > 0 && capacity < uint.max - 1);
        this.nodes = new SListNode!T[capacity];
        this.first = 0;
        foreach (i; 0 .. capacity) {
            nodes[i].next = i + 1;
        }
        nodes[capacity - 1].next = noneIndex;
    }

    SListNode *getAtIndex(uint index) => nodes[index];

    uint allocate() {
        enforce(first != noneIndex, "No space left in SListPool");
        uint index = first;
        first = nodes[index].next;
        nodes[index].next = noneIndex;
        return index;
    }

    void free(uint index) {
        enforce(index < nodes.length);
        nodes[index].next = first;
        first = index;
    }
}

