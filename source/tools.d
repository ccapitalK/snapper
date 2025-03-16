module snapper.tools;
import core.time;
import std.algorithm;
import std.array;
import std.exception;
import std.format;
import std.getopt;
import std.range;
import std.stdio;

static import std.file;

import snapper.agent;
import snapper.puzzle;
import snapper.repr;
import snapper.search;

const string PUZZLES_FROM_CSV = "puzzlesFromCsv";

void runTool(string[] args) {
    if (args[1 .. $] == ["bench"]) {
        writeln("Running benchmark");
        auto initial = "4kb1r/p4ppp/4q3/8/8/1B6/PPP2PPP/2KR4 w - - 0 1".parseFen;
        writeln(initial.board.getAsciiArtRepr);
        writeln(initial.pickBestMove(8));
        return;
    }
    if (args[1 .. $] == ["benchDeepen"]) {
        writeln("Running deepening benchmark");
        auto initialState = "4kb1r/p4ppp/4q3/8/8/1B6/PPP2PPP/2KR4 w - - 0 1";
        auto agent = new ChessAgent;
        agent.handleUciPositionCommand("position fen " ~ initialState);
        writeln("Best move: ", agent.bestMove(""));
        return;
    }
    if (args[1 .. $] == ["heavyTest"]) {
        runHeavyTests();
        return;
    }
    if (args[1 .. $]
        .filter!(a => !a.startsWith('-'))
        .startsWith([PUZZLES_FROM_CSV])) {
        return puzzlesFromCsv(args);
    }
    writeln("Unknown subcommand ", args);
}

struct Puzzle {
    string fen;
    string rawMoves;
    int rating;
}

void puzzlesFromCsv(string[] args) {
    import std.random;
    import std.parallelism;
    int low = 600;
    int high = 1200;
    int seed = 1337;
    int numSamples = 10;
    int timeMillis = 300;
    bool parallel = false;
    auto result = getopt(args,
        "s|seed", "RNG Seed", &seed,
        "l|low", "Lowest rating we allow", &low,
        "h|high", "Highest rating we allow", &high,
        "n|num-samples", "Number of samples to take", &numSamples,
        "t|time-millis", "Number of milliseconds allowed per turn", &timeMillis,
        "p|parallel", "Run tests in parallel", &parallel,
    );
    bool helpWanted = result.helpWanted;
    if (args.length != 3 || args[1] != PUZZLES_FROM_CSV) {
        helpWanted = true;
    }
    if (helpWanted) {
        writefln("usage: %s [options] %s csv_path", args[0], PUZZLES_FROM_CSV);
        defaultGetoptPrinter("Run some puzzles sampled from a csv file", result.options);
        return;
    }
    auto puzzles = args[2].readPuzzles(low, high);
    auto chosen = puzzles.randomSample(numSamples, Mt19937(seed));
    writefln("Chose %d puzzles", chosen.length);
    const auto duration = timeMillis.msecs;
    auto runTest = (Puzzle puzzle) {
        try {
            puzzle.run(duration);
            writeln("Passed test ", puzzle);
        } catch (Exception e) {
            writefln("Failed test %s: %s", puzzle, e.msg);
        }
    };
    if (parallel) {
        foreach (puzzle; chosen.parallel) {
            runTest(puzzle);
        }
    } else {
        foreach (puzzle; chosen) {
            runTest(puzzle);
        }
    }
}

void run(const ref Puzzle puzzle, const Duration duration) {
    ChessAgent agent = new ChessAgent;
    auto state = puzzle.fen.parseFen;
    void applyMove(string moveString) {
        auto move = moveString.parseMove;
        state = state.performMove(move).state;
    }
    auto expectedMoves = puzzle.rawMoves.split(' ');
    enforce(expectedMoves.length > 1);
    applyMove(expectedMoves[0]);
    agent.handleUciPositionCommand("position fen " ~ state.toFen);

    foreach (pair; expectedMoves[1 .. $].chunks(2)) {
        auto expectedMove = pair[0];
        auto agentMove = agent.bestMove("", duration);
        enforce(expectedMove == agentMove, "Expected %s, got %s".format(expectedMove, agentMove));
        if (pair.length > 1) {
            applyMove(agentMove);
            applyMove(pair[1]);
            agent.handleUciPositionCommand("position fen " ~ state.toFen);
        }
    }
}

// There is absolutely no way this doesn't already exist
auto next(Range)(ref Range range) {
    auto v = range.front;
    range.popFront();
    return v;
}

Puzzle[] readPuzzles(string puzzleCsvPath, int minRating, int maxRating) {
    import std.conv;
    Appender!(Puzzle[]) builder;
    auto data = cast(string) std.file.read(puzzleCsvPath);
    // Lichess puzzle database file
    // PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
    foreach (line; data.splitter('\n').drop(1)) {
        if (line.length < 5) {
            continue;
        }
        auto parts = line.splitter(',');
        parts = parts.drop(1);
        string fen = parts.next;
        string moves = parts.next;
        string rating = parts.next;
        auto puzzle = Puzzle(fen, moves, rating.to!int);
        if (minRating <= puzzle.rating && puzzle.rating <= maxRating) {
            builder.put(puzzle);
        }
    }
    return builder.data();
}
