module snapper.sort;

import std.algorithm;
import std.logger;
import std.functional : binaryFun;
import std.traits;

// Apparently the stdlib quicksort was taking up a non-trivial amount of time, so we forked and implemented our own
// Right now it's slower, but eventually we should be able to get something that is better for our specific use case
// TODO: Investigate other off the shelf implementations, almost certainly going to be one of those that wins.
Range quicksort(alias fun = "a < b", Range)(Range vals)
        if (__traits(compiles, vals[0]) && __traits(compiles, vals.length)) {
    alias T = typeof(vals[0]);
    alias lessFun = binaryFun!(fun);
    if (vals.length < 2) {
        return vals;
    }
    auto mid = lomutoPartitionBranchfree!lessFun(vals.ptr, vals.ptr + vals.length);
    // auto mid = hoarePartition!lessFun(vals.ptr, vals.ptr + vals.length);
    auto midOffset = mid - vals.ptr;
    quicksort!fun(vals[0 .. midOffset]);
    quicksort!fun(vals[midOffset + 1 .. $]);
    return vals;
}

// Also taken from https://dlang.org/blog/2020/05/14/lomutos-comeback/
// FIXME: This is broken with OOB access in the tests
T* hoarePartition(alias fun, T)(T* first, T* last) {
    assert(first <= last);
    if (last - first < 2)
        return first; // nothing interesting to do
    --last;
    if (fun(*first, *last)) {
        swap(*first, *last);
    }
    auto pivot_pos = first;
    auto pivot = *pivot_pos;
    for (;;) {
        ++first;
        auto f = *first;
        while (fun(f, pivot)) {
            f = *++first;
        }
        auto l = *last;
        while (fun(pivot, l)) {
            l = *--last;
        }
        if (first >= last) {
            break;
        }
        *first = l;
        *last = f;
        --last;
    }
    --first;
    swap(*first, *pivot_pos);
    return first;
}

// Taken from https://dlang.org/blog/2020/05/14/lomutos-comeback/
T* lomutoPartitionBranchfree(alias fun, T)(T* first, T* last) {
    assert(first <= last);
    if (last - first < 2) {
        return first; // nothing interesting to do
    }
    --last;
    if (fun(*last, *first))
        swap(*first, *last);
    auto pivot_pos = first;
    auto pivot = *first;
    do {
        ++first;
        assert(first <= last);
    }
    while (fun(*first, pivot));
    for (auto read = first + 1; read < last; ++read) {
        auto x = *read;
        auto smaller = -int(fun(x, pivot));
        auto delta = smaller & (read - first);
        first[delta] = *first;
        read[-delta] = x;
        first -= smaller;
    }
    assert(!fun(*first, pivot));
    --first;
    *pivot_pos = *first;
    *first = pivot;
    return first;
}

unittest {
    int[] array = [4, 3, 2, 1];

    // sort in ascending order
    array.quicksort();
    assert(array == [1, 2, 3, 4]);

    // sort in descending order
    array.quicksort!((a, b) => a > b);
    assert(array == [4, 3, 2, 1]);

    // sort in ascending order
    array.quicksort!("a < b");
    assert(array == [1, 2, 3, 4]);

    // sort with reusable comparator and chain
    alias myComp = (x, y) => x > y;
    assert(array.quicksort!(myComp) == [4, 3, 2, 1]);
}

// Tests adapted from what claude.ai gave.
unittest {
    import std.algorithm : sort;
    import std.random;

    // Test case 1: Already sorted array
    {
        int[] array = [1, 2, 3, 4, 5];
        int[] expected = array.dup;

        array.quicksort();
        assert(array == expected, "Test case 1 failed: Already sorted array");
    }

    // Test case 2: Reverse sorted array
    {
        int[] array = [5, 4, 3, 2, 1];
        int[] expected = [1, 2, 3, 4, 5];

        array.quicksort();
        assert(array == expected, "Test case 2 failed: Reverse sorted array");
    }

    // Test case 3: Array with duplicate elements
    {
        int[] array = [3, 1, 4, 1, 5, 9, 2, 6, 5];
        int[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 3 failed: Array with duplicate elements");
    }

    // Test case 4: Empty array
    {
        int[] array = [];

        array.quicksort();
        assert(array == [], "Test case 4 failed: Empty array");
    }

    // Test case 5: Single element array
    {
        int[] array = [42];

        array.quicksort();
        assert(array == [42], "Test case 5 failed: Single element array");
    }

    // Test case 6: Array with negative numbers
    {
        int[] array = [5, -3, 0, 8, -10, 7];
        int[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 6 failed: Array with negative numbers");
    }

    // Test case 7: Large array
    {
        // Generate a large random array
        auto rnd = Mt19937(1337);
        int[] array;
        foreach (i; 0 .. 1000) {
            array ~= uniform(-1000, 1000, rnd);
        }
        int[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 7 failed: Large random array");
    }

    // Test case 8: Array with all identical elements
    {
        int[] array = [7, 7, 7, 7, 7];

        array.quicksort();
        assert(array == [7, 7, 7, 7, 7], "Test case 8 failed: Array with identical elements");
    }

    // Test case 9: Testing with different types (float)
    {
        float[] array = [3.14, 1.41, 2.71, 0.577];
        float[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 9 failed: Float array");
    }

    // Test case 10: Testing with different types (string)
    {
        string[] array = ["banana", "apple", "cherry", "date"];
        string[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 10 failed: String array");
    }

    // Test case 11: Nearly sorted array
    {
        int[] array = [1, 2, 4, 3, 5, 6];
        int[] expected = array.dup;
        expected.sort();

        array.quicksort();
        assert(array == expected, "Test case 11 failed: Nearly sorted array");
    }
}
