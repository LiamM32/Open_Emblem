module map;

import std.stdio;
import std.json;
debug import std.conv;

import tile;
import unit;
import common;
import faction;

alias PlainMap = MapTemp!(Tile, Unit);

class MapTemp (TileType:Tile, UnitType:Unit) : Map {
    public string name;
    
    protected TileType[][] grid;
    protected ushort gridWidth;
    protected ushort gridLength;
    protected string[] textureIndex;
    public bool fullyLoaded = false;
    protected GamePhase phase = GamePhase.Loading;
    public int turn;

    public Faction[] factions;
    public Faction[string] factionsByName;
    public UnitType[] allUnits;

    this(string name) {
        this.name = name;
    }
    
    static if (is(TileType==Tile)) this(ushort width, ushort length) {
        this.grid.length = width;
        foreach (x; 0 .. width) {
            this.grid[x].length = length;
            foreach (y; 0 .. length) {
                this.grid[x][y] = new Tile(x, y);
            }
        }
        this.gridWidth = width;
        this.gridLength = length;
        this.fullyLoaded = true;
    }

    this(string name, TileType[][] grid) {
        this.name = name;
        this.grid = grid;
        this.gridWidth = cast(ushort)grid.length;
        foreach (row; grid) {
            assert(row.length == grid[0].length);
        }
        this.gridLength = cast(ushort)grid[0].length;
        this.fullyLoaded = true;
    }

    /*this(JSONValue mapData) {
        import std.algorithm;
        
        if ("factions" in mapData) this.loadFactionsFromJSON(mapData.object["factions"]);
        
        this.grid.length = mapData.object["tiles"].array.length;
        JSONValue[][] tileData;
        tileData.length = mapData.object["tiles"].array.length;
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
                this.grid[x][y] = new TileType(x, y, tileName, allowStand, allowFly, stickiness, textureID, textureName);
            }
        }
        this.fullyLoaded = true;
    }*/

    protected bool loadFactionsFromJSON (JSONValue mapData) {
        import std.uni: toLower;
        
        this.factions ~= new Faction(name:"Player");
        this.factionsByName["player"] = this.factions[$-1];
        if ("factions" in mapData) {
            foreach (factionData; mapData.object["factions"].array) {
                Faction faction;
                if (factionData.type == JSONType.string) faction = new Faction(factionData.get!string, isPlayer:false);
                else if (factionData.type == JSONType.object) { 
                    faction = new Faction(factionData.object["name"].get!string);
                    if ("allies" in factionData) foreach (ally; factionData.object["allies"].array) {
                        faction.allyNames ~= ally.get!string;
                    }
                    if ("enemies" in factionData) foreach (enemy; factionData.object["enemies"].array) {
                        faction.enemyNames ~= enemy.get!string;
                    }
                    faction.isPlayer = false;
                }
                this.factions ~= faction;
                this.factionsByName[faction.name] = faction;
            }
            foreach(faction; this.factions) writeln("There is a faction called "~faction.name);
            return true;
        } else {
            this.factions ~= new Faction(name:"Player");
            this.factionsByName["player"] = this.factions[$-1];
            this.factions ~= new Faction(name: "Enemy");
            this.factionsByName["enemy"] = this.factions[$-1];
            return false;
        }

        foreach (faction; this.factions) faction.setAlliesEnemies(factionsByName);
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

    debug bool verifyEverything() {
        import std.conv;
        import std.uni:toLower;
        import std.algorithm.searching;
        foreach (int x, row; this.grid) foreach (int y, tile; row) {
            assert(tile.x == x, "Tile at position "~to!string(x)~", "~to!string(y)~" does not match it's internal reading of "~tile.x.to!string~", "~tile.y.to!string~".");
            if (tile.occupant !is null) {
                assert(tile.occupant.currentTile == tile, "Tile "~to!string(x)~", "~to!string(y)~" occupant set to unit "~tile.occupant.name~", but "~tile.occupant.name~"'s currentTile is not set to this tile.");
                //TODO: Add line here to check if unit should be allowed on this tile.
            }
        }
        foreach (faction; this.factions) {
            assert(faction == factionsByName[faction.name.toLower]||faction == factionsByName[faction.name], "Faction "~faction.name~" is not in Map.factionsByName");
            foreach (unit; faction.units) {
                assert(unit.map == this, "Unit "~unit.name~" is missing reference to map.");
                assert(canFind(this.allUnits, unit), "Unit "~unit.name~" not found in `allUnits`.");
                assert(unit.faction == faction, "Unit "~unit.name~" is listed under faction "~faction.name~", but is missing reference to this faction.");
                assert(unit == unit.currentTile.occupant, "Unit "~unit.name~"'s tile is set to "~to!string(unit.currentTile.x)~", "~to!string(unit.currentTile.y)~", but it's not mutual.");
                assert(unit.xlocation == unit.currentTile.x, "Unit "~unit.name~"'s `xlocation` does not match it's `currentTile.x`.");
                assert(unit.ylocation == unit.currentTile.y, "Unit "~unit.name~"'s `ylocation` does not match it's `currentTile.y`.");
            }
        }
        foreach (unit; this.allUnits) {
            assert(unit.map == this, "Unit "~unit.name~" is missing reference to map.");
            assert(unit == unit.currentTile.occupant, "Unit "~unit.name~"'s tile is set to "~to!string(unit.currentTile.x)~", "~to!string(unit.currentTile.y)~", but it's not mutual.");
            assert(unit.xlocation == unit.currentTile.x, "Unit "~unit.name~"'s `xlocation` does not match it's `currentTile.x`.");
            assert(unit.ylocation == unit.currentTile.y, "Unit "~unit.name~"'s `ylocation` does not match it's `currentTile.y`.");
        }
        return true;
    }

    void nextTurn() {
        if (this.phase == GamePhase.Preparation) this.turn = 0; //Change this later so that the faction with the first turn is determined by the map file.
        else if (this.turn >= this.factions.length-1) turn = 0;
        else turn++;

        if (this.factions[this.turn].isPlayer) this.phase = GamePhase.PlayerTurn;
        else this.phase = GamePhase.NonPlayerTurn;
    }

    void turnReset() {
        import std.conv;
        
        foreach(unit; this.allUnits) {
            if (unit !is null) unit.turnReset;
            else writeln("allUnits contains an empty member");
        }
    }

    void turnReset(string faction) {
        foreach(unit; this.factionsByName[faction].units) {
            unit.turnReset;
        }
    }
    
    Tile getTile(Vector2i location) {
        if (location.x >= 0 && location.x < this.gridWidth && location.y >= 0 && location.y < this.gridLength) return this.grid[location.x][location.y];
        else {
            writeln("Map size is "~to!string(gridWidth)~"×"~to!string(gridLength));
            throw new Exception("Tried to get non-existent tile for position "~to!string(location.x)~", "~to!string(location.y));
        }
    }
    
    Tile getTile(int x, int y) {
        return this.grid[x][y];
    }

    Tile[][] getGrid() {
        Tile[][] tileGrid;
        tileGrid.length = this.grid.length;
        foreach(int x, row; this.grid) {
            foreach(tile; row) {
                tileGrid[x] ~= tile;
            }
        }
        
        return tileGrid;
    }

    bool allTilesLoaded() {
        return this.fullyLoaded;
    }

    Unit getOccupant(int x, int y) {
        return this.grid[x][y].occupant;
    }
    
    uint getWidth() {
        if (this.gridWidth == 0) {
            this.gridWidth = cast(ushort)this.grid.length;
        }
        return cast(uint)this.gridWidth;
    }
    uint getLength() {
        return cast(uint)this.grid[0].length;
    }

    Vector2i getSize() {
        return Vector2i(this.gridWidth, this.gridLength);
    }

    bool deleteUnit(Unit unit, bool destroy=false) { //Always set `destroy` to false when calling from the Unit destructor, to avoid an infinite loop.
        import std.algorithm.searching;
        UnitType[] shiftedUnits = allUnits.find(unit);
        ushort unitKey = cast(ushort)(allUnits.length - shiftedUnits.length);
        if (shiftedUnits.length > 0) {
            this.allUnits[$-shiftedUnits.length] = null;
            for (ushort i=0; i<shiftedUnits.length-1; i++) {
                this.allUnits[unitKey+i] = this.allUnits[unitKey+i+1];
            }
            this.allUnits.length--;
            return true;
        } else return false;
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
}

interface Map {
    Tile getTile(Vector2i);
    Tile getTile(int x, int y);
    Tile[][] getGrid();
    uint getWidth();
    uint getLength();
    Vector2i getSize();
    Unit getOccupant(int x, int y);
    bool allTilesLoaded();
    bool deleteUnit(Unit unit, bool destroy);
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

enum GamePhase : ubyte {
    Loading,
    Preparation,
    PlayerTurn,
    NonPlayerTurn,
}


unittest
{
    import std.algorithm.searching;
    debug writeln("Starting Map unittest 1.");

    MapTemp!(Tile,Unit) map = new MapTemp!(Tile,Unit)(cast(ushort)16, cast(ushort)16);
    UnitStats stats = {Mv:7, isFlyer:false, MHP:60, Str:22, Def:15};
    Unit unitA = new Unit("Unit A", map, stats);
    Unit unitB = new Unit("Unit B", map, stats);
    Unit unitC = new Unit("Unit C", map, stats);
    map.allUnits ~= unitA;
    map.allUnits ~= unitB;
    map.allUnits ~= unitC;
    map.deleteUnit(unitB, true);
    assert(map.allUnits == [unitA, unitC], "Map.deleteUnit function did not work as expected.");
    writeln("Map unittest 1 passed.");
}