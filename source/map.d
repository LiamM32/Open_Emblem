//module map;

import std.stdio;
import std.json;

import tile;
import unit;

class Map {
    public string name;
    protected Tile[][] grid;
    protected ushort gridWidth;
    protected ushort gridLength;
    protected string[] textureIndex;
    public bool fullyLoaded = false;

    public Unit[] allUnits;

    this(string name) {
        this.name = name;
    }
    
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
    this.fullyLoaded = true;
    }

    this(JSONValue mapData) {
        import std.algorithm;
        
        JSONValue[][] tileData;
        tileData.length = mapData.object["tiles"].array.length;
        this.grid.length = mapData.object["tiles"].array.length;
        foreach (x, tileRow; mapData.object["tiles"].array) {
            tileData[x] = tileRow.arrayNoRef;
            this.grid[x].length = tileRow.array.length;

            foreach (y, tile; tileRow.arrayNoRef) {
                string tileName = "";
                if ("name" in tile) tileName = tile["name"].get!string;
                bool allowStand = tile["canWalk"].get!bool;
                bool allowFly = true;// tile["canFly"].get!bool;
                int stickiness = tile["stickiness"].get!int;
                string textureName = tile["tile_sprite"].get!string;
                ushort textureID = this.findAssignTextureID(textureName);
                this.grid[x][y] = new Tile(tileName, allowStand, allowFly, stickiness, textureID, textureName);
            }
        }
        this.fullyLoaded = true;
    }

    ~this() {
        foreach (unit; this.allUnits) {
            destroy(unit);
        }
        foreach (tileRow; this.grid) {
            foreach (tile; tileRow) {
                destroy(tile);
            }
        }
    }
    
    Tile* getTile(int x, int y) {
        return &this.grid[x][y];
    }

    Tile[][] getGrid() {
        return this.grid;
    }
    
    ushort getWidth() {
        return cast(ushort)this.grid.length;
    }
    ushort getLength() {
        return cast(ushort)this.grid[0].length;
    }

    string[] getTextureIndex() {
        return this.textureIndex;
    }

    ushort findAssignTextureID (string textureName) {
        import std.conv;
        ushort i;
        for (i=0; i<this.textureIndex.length; i++) {
            if (textureIndex[i] == textureName) return i;
        }
        this.textureIndex ~= textureName;
        return cast(ushort)(this.textureIndex.length - 1);
    }

    /*Unit*///void loadUnitFromJSON (JSONValue UnitData);
    //void loadJSONTileData (JSONValue TileData);
}

ushort findAssignTextureID (string[] textureIndex, string textureName) {
    import std.conv;
    ushort i;
    for (i=0; i<textureIndex.length; i++) {
        if (textureIndex[i] == textureName) return i;
    }
    textureIndex ~= textureName;
    writeln("i = " ~ to!string(i));
    writeln("textureIndex.length = " ~ to!string(textureIndex.length-1));
    writeln(textureIndex);
    return cast(ushort)(textureIndex.length - 1);
}

unittest
{
    Map map = new Map(cast(ushort)8, cast(ushort)8);
    assert(map.findAssignTextureID("grass") == 0);
    assert(map.findAssignTextureID("water") == 1);
    assert(map.findAssignTextureID("sand") == 2);
    assert(map.findAssignTextureID("grass") == 0);
    assert(findAssignTextureID(map.textureIndex, "stone") == 3);
}

unittest
{
    import std.algorithm.searching;
    Map map = new Map(cast(ushort)16, cast(ushort)16);
    UnitStats unitStats = {Mv:6, Str:24, Def:16, MHP:90};
    Unit unit = new Unit("Soldier", map, unitStats);
    assert (canFind(map.allUnits, unit));
}