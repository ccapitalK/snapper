# Roadmap

## Getting started

- [X] Read a move, pick a random (simple) move, write a move
- [X] Enumerate legal moves
- [X] Basic board repr
- [X] Pick best move that is legal from 2-deep search
- [X] Tune tree search, set stopping time
- [X] Random deep tree search

## Interface

- [X] Run in specified time limit
- [ ] Respect time limit from uci
- [ ] Read in config options from uci

## General Optimization

- [ ] (Un)Marshal abstract board state to a specific optimized representation
- [ ] Learn how to perform castles
- [X] StackAllocator for move list generation
- [X] Switch to UTHash (Abandoned, seems slower than gc / using table)
- [X] Rewrite search to use custom allocators, avoid GC
- [X] Bitboard
- [ ] Magic Bitboard
- [ ] Optimize move generation
- [ ] Properly handle detecting check and not moving into mate
- [ ] Stalemate detection
  - [ ] No moves detection
  - [ ] Loop detection
- [ ] Optimize castling handling

## Algos

- [X] Alpha-Beta pruning
- [X] Iterative Deepening
- [X] Transposition tables
- [X] Reuse the principle variation when deepening
- [?] Quiescence - Tried, not sure if it's worth keeping
- [ ] Better position evaluation
- [X] Opening table database
- [ ] Cuda tree search?
