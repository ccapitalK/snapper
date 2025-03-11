module snapper.tools;
import std.stdio;

import snapper.agent;
import snapper.puzzle;
import snapper.repr;
import snapper.search;

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
    writeln("Unknown subcommand ", args);
}

