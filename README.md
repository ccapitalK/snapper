# Chess Engine

This is a chess engine written in D. It's called "Chess Engine" because I haven't
come up with a proper name yet. It uses the UCI protocol, and should be
compatible with any UCI chess runner (though it's only been tested against KDE
Knights and pychess). Any incompatibility should be reported as a bug.

## Building

Get a copy of the D toolchain following the instructions on `https://dlang.org/`.
This engine runs best when compiled with ldc in release mode.

```
dub build -b release --compiler=ldc
./chess_engine heavyTest
```

The chess engine should now be built as `./chess_engine`.
