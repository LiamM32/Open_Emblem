# Open Emblem (name subject to change)

This is a project to make a tactical RPG game written in D. It is heavily inspired by Fire Emblem, but will be set apart by some of it's rules.

The main DUB project (including the files in `source/`) is written as a source library that can be used by a graphical front-end. This decision was made so that I can experiment with different graphics libraries. When in a more mature state, this code should be reusable for other Tactical RPG games.

The only front-end currently available is the Raylib front-end located in `oe-raylib`. To build and run, go to this directory and enter `dub` in the terminal.