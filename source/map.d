//module map;

import std.stdio;
import std.json;

import tile;

class Map {
    private Tile[][] grid;
    private ushort gridWidth;
    private ushort gridLength;
    private string[ushort] textureIndex;

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

    this(JSONValue mapData) {
        
        JSONValue[][] tileData;
        tileData.length = mapData.object["tiles"].array.length;
        this.grid.length = mapData.object["tiles"].array.length;
        foreach (x, tileRow; mapData.object["tiles"].array) {
            tileData[x] = tileRow.arrayNoRef;
            this.grid[x].length = tileRow.array.length;

            foreach (y, tile; tileRow.arrayNoRef) {
                bool allowStand = tile["canWalk"].get!bool;
                bool allowFly = true;// tile["canFly"].get!bool;
                int stickiness = tile["stickiness"].get!int;
                string textureName = tile["tile_sprite"].get!string;
                this.grid[x][y] = new Tile(allowStand, allowFly, stickiness, textureName);
            }
        }
        //writeln(mapData);
    }
    
    Tile* getTile(int x, int y) {
        return &this.grid[x][y];
    }
    
    ushort getWidth() {
        return cast(ushort)this.grid.length;
    }
    ushort getLength() {
        return cast(ushort)this.grid[0].length;
    }

    string[ushort] getTextureIndex() {
        return this.textureIndex;
    }
}
