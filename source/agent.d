module chess_engine.agent;

import core.atomic;
import core.thread;
import core.time;
import std.algorithm;
import std.exception;
import std.logger;
import std.parallelism;
import std.random;
import std.string : strip;

import chess_engine.repr;
import chess_engine.search;

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
}

class ChessAgent {
    Mt19937 rnd;
    GameState currentBoard;

    this() {
        rnd.seed(1337);
    }

    void handleUciPositionCommand(string uciCommand) {
        currentBoard = uciCommand.readUCIPosition;
        info("Parsed position:");
        info("\n" ~ currentBoard.board.getAsciiArtRepr);
    }

    string bestMove(string opts) {
        string encoded = currentBoard.toFen();
        auto context = new SearchContext;
        auto searchTask = task(&getBestMove, context, encoded);
        searchTask.executeInNewThread();
        // FIXME: Weird bug I'm seeing where sleep overshoots by exactly 400msecs
        Thread.sleep(2.seconds + 600.msecs);
        context.isStopped.atomicStore(true);
        return searchTask.yieldForce;
    }
}

string getBestMove(SearchContext* context, immutable string fenBoard) {
    auto board = fenBoard.parseFen;
    return board.pickBestMoveIterativeDeepening(context).move.toString;
}
