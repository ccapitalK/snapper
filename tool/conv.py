#!/usr/bin/env python3

import chess
import chess.pgn
import typing

def uci_to_pgn (uci_moves, starting_fen=None):
    board = chess.Board(fen=starting_fen) if starting_fen else chess.Board()
    game = chess.pgn.Game()
    node = game

    for move_uci in uci_moves:
        move = board.parse_uci(move_uci)
        board.push(move)
        node = node.add_variation(move)

    game.headers["Result"] = board.result()
    return str(game)

# Example usage:
moves: typing.List[str] = input().split(' ')
if moves[:3] == ["position", "startpos", "moves"]:
    moves = moves[3:]

pgn_output = uci_to_pgn(moves)
print(pgn_output)
