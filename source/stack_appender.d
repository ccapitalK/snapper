module snapper.stack_appender;
import std.array;
import std.exception;
import std.stdio;
import std.traits;

bool isAppender(T)() {
    // TODO: Check types on these?
    return hasMember!(T, "put")
        && hasMember!(T, "data");
}

struct StackAppender(T) {
    private T[] array;
    private size_t offset = 0;
    private size_t start = 0;

    @disable
    this();

    this(size_t capacity) {
        // TODO: GC.NoScan?
        array = new T[capacity];
    }

    size_t getOffset() const => offset;

    T[] data() {
        enforce(start <= offset);
        auto v = array[start .. offset];
        start = offset;
        return v;
    }

    void put(T val) {
        enforce(offset < array.length);
        array[offset++] = val;
    }
}

struct StackAppenderResetGuard(T) {
    private StackAppender!T* pusher;
    private size_t position;

    @disable
    this();

    this(StackAppender!T* pusher) {
        this.pusher = pusher;
        position = pusher.offset;
    }

    ~this() {
        enforce(pusher.offset >= pusher.start);
        enforce(pusher.start >= position);
        pusher.offset = position;
        pusher.start = position;
    }
}

static assert(isAppender!(StackAppender!int));
static assert(isAppender!(StackAppender!int*));
static assert(isAppender!(Appender!(int[])));
static assert(isAppender!(Appender!(int[])));

unittest {
    auto pusher = StackAppender!int(16);
    enforce(pusher.getOffset == 0);
    pusher.put(3);
    pusher.put(2);
    pusher.put(10);
    enforce(pusher.data() == [3, 2, 10]);
    enforce(pusher.data() == []);
    {
        auto guard = StackAppenderResetGuard!int(&pusher);
        auto start = pusher.getOffset();
        assert(start == 3);
        pusher.put(1);
        pusher.put(2);
        pusher.put(4);
        assert(pusher.data == [1, 2, 4]);
    }
    assert(pusher.getOffset == 3);
    assertThrown({
        auto guard = StackAppenderResetGuard!int(&pusher);
        foreach (i; 0 .. 16) {
            pusher.put(i);
        }
    }());
    assert(pusher.getOffset == 3);
    pusher.put(1);
    pusher.put(2);
    assert(pusher.data == [1, 2]);
}
