module map;

import std.stdio;

import tile;

class Map {
    private Tile[uint][uint] grid;
    private ushort gridWidth;
    private ushort gridLength;

    this(ushort width, ushort length) {
        foreach (x; 0 .. width) {
            foreach (y; 0 .. length) {
                this.grid[x][y] = new Tile();
            }
        }
    this.gridWidth = width;
    this.gridLength = length;
    }
    
    Tile* getTile(int x, int y) {
        return &this.grid[x][y];
    }
    
    ushort getWidth() {
        return this.gridWidth;
    }
    ushort getLength() {
        return this.gridLength;
    }
}
