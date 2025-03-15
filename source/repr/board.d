module snapper.repr.board;

import std.algorithm;
import std.ascii;
import std.array;
import std.conv;
import std.format;
import std.math;
import std.exception;
import std.logger;
import std.range;
import std.stdio;
import std.traits;
import std.typecons;

import snapper.bit;
import snapper.repr;

alias Board = BitBoard;

static assert(Board.sizeof == BitBoard.sizeof);

string getAsciiArtRepr(const ref Board board) {
    auto builder = appender(cast(string)[]);
    foreach (y; 0 .. 8) {
        auto rank = 7 - y;
        builder.put(format("%d  ", rank + 1));
        foreach (x; 0 .. 8) {
            auto file = x;
            auto square = board.getSquare(MCoord(file, rank));
            char c;
        pSwitch:
            final switch (square.getPiece()) {
            case Piece.empty:
                c = ' ';
                break;
                static foreach (v; pieceByFenName) {
            case v[1]:
                    c = v[0];
                    break pSwitch;
                }
            }
            builder.put(square.getPlayer == Player.white ? std.ascii.toUpper(c) : c);
        }
        builder.put('\n');
    }
    builder.put("\n   ABCDEFGH");
    return builder.data;
}

bool isEmpty(const ref Board board, MCoord coord) => board.getSquare(coord).isEmpty;

struct Castling {
    bool[numMembers!Player] king;
    bool[numMembers!Player] queen;

    static const Castling none = Castling([false, false], [false, false]);
    static const Castling all = Castling([true, true], [true, true]);
}
