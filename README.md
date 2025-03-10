# Piranha Chess Engine

This is a chess engine written in D. It uses the UCI protocol, and should be
compatible with any UCI chess runner (though it's only been tested against KDE
Knights and pychess). Any incompatibility should be reported as a bug.

## Building

Get a copy of the D toolchain following the instructions on `https://dlang.org/`.
This engine runs best when compiled with ldc in release mode.

```
dub build -b release --compiler=ldc
./piranha heavyTest
```

The chess engine should now be built as `./piranha`. You can use it using the uci protocol, no command line arguments
are necessary.
