module map;

import std.stdio;

import tile;

class Map {
    private Tile[][] grid;
    private ushort gridWidth;
    private ushort gridLength;

    this(ushort width, ushort length) {
        this.grid.length = width;
        foreach (x; 0 .. width-1) {
            this.grid[x].length = length;
            foreach (y; 0 .. length-1) {
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
