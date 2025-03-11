module snapper.agent;

import core.atomic;
import core.thread;
import core.time;
import std.algorithm;
import std.datetime;
import std.exception;
import std.logger;
import std.random;
import std.string : strip;

import snapper.opening_table;
import snapper.repr;
import snapper.search;

const static string START_POSITION = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

GameState readUCIPosition(string uciCommand) {
    string moveComponents;
    enforce(uciCommand.startsWith("position"));
    auto commandInner = uciCommand.findSplitAfter(" ")[1];
    if (commandInner.find("moves")) {
        auto parts = commandInner.findSplit("moves");
        commandInner = parts[0].strip;
        moveComponents = parts[2].strip;
    }
    string positionFen;
    if (commandInner == "startpos") {
        positionFen = START_POSITION;
    } else {
        enforce(commandInner.startsWith("fen "));
        positionFen = commandInner.findSplitAfter(" ")[1];
    }
    GameState position = positionFen.parseFen;
    if (moveComponents.length > 0) {
        foreach (moveString; moveComponents.splitter(" ")) {
            auto move = moveString.parseMove();
            position = position.performMove(move.source, move.dest).state;
        }
    }
    return position;
}

unittest {
    auto command = "position startpos";
    auto position = command.readUCIPosition;
    assert(position.toFen == START_POSITION);
    command = "position startpos moves";
    position = command.readUCIPosition;
    assert(position.toFen == START_POSITION);
    command = "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 moves";
    position = command.readUCIPosition;
    assert(position.toFen == START_POSITION);
    command = "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    position = command.readUCIPosition;
    assert(position.toFen == START_POSITION);
    command = "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 moves e2e4";
    position = command.readUCIPosition;
    assert(position.toFen == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1");
    command = "position startpos moves e2e4 b8c6 g1f3 d7d5 e4d5 d8d5 b1c3 d5e6 f1e2"
        ~ " a7a5 e1g1 h7h6 c3b5 e8d8 f3d4 c6d4 b5d4 e6e4 d4b5 g8f6 e2f3 e4e5"
        ~ " d2d4 e5b5 c1f4 b5b2 d1c1 b2c3 c1e1 c3c2 f3d1 c2b2 f4c1 b2a1 d1f3"
        ~ " a1a2 e1c3 h8g8 c1f4 a2b1 f1b1 c7c6 c3c5 g7g5 c5b6 d8d7 d4d5 f6d5"
        ~ " f3g4 e7e6 b6c5 f8c5 b1d1";
    position = command.readUCIPosition;
    assert(position.toFen.startsWith("r1b3r1/1p1k1p2/2p1p2p/p1bn2p1/5BB1/8/5PPP/3R2K1 b - -"));
}

class ChessAgent {
    GameState currentBoard;
    OpeningTable openingTable;
    Mt19937 rnd;

    this(string openingTableData = null, uint seed = unpredictableSeed) {
        this.rnd = Mt19937(seed);
        if (openingTableData) {
            this.openingTable = makeOpeningTable(openingTableData);
        }
    }

    void handleUciPositionCommand(string uciCommand) {
        currentBoard = uciCommand.readUCIPosition;
        info("Parsed position:");
        info("\n" ~ currentBoard.board.getAsciiArtRepr);
    }

    private string tryTableMove() {
        auto tableMoves = openingTable.lookupPosition(currentBoard);
        if (tableMoves.length == 0) {
            return null;
        }
        auto rouletteTotal = sum(tableMoves[].map!(a => a[1]));
        auto roulette = uniform(0, rouletteTotal, rnd);
        size_t sum = 0;
        foreach (move; tableMoves) {
            sum += move[1];
            if (sum < roulette) {
                continue;
            }
            auto chosen = move[0];
            info("Chose table move ", chosen.toString);
            return chosen.toString;
        }
        enforce(false, "Unreachable code");
        return null;
    }

    string bestMove(string opts, Duration thinkTime = 3.seconds) {
        auto tableMove = tryTableMove();
        if (tableMove != null) {
            return tableMove;
        }
        auto context = new SearchContext;
        context.endTime = Clock.currTime + thinkTime;
        return currentBoard.pickBestMoveIterativeDeepening(context).move.toString;
    }
}
