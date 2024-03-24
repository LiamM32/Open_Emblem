module map;

import std.stdio;
import std.json;
debug import std.conv;

import tile;
import unit;
import common;
import faction;

class Map {
    public string name;
    
    protected Tile[][] grid;
    protected ushort gridWidth;
    protected ushort gridLength;
    public bool fullyLoaded = false;
    protected GamePhase phase = GamePhase.Loading;
    public int turn;

    public Faction[] factions;
    public Faction[string] factionsByName;
    public Unit[] allUnits;

    this(string name) {
        this.name = name;
    }
    
    static if (is(Tile==Tile)) this(ushort width, ushort length) {
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

    this(string name, Tile[][] grid) {
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
                this.grid[x][y] = new Tile(x, y, tileName, allowStand, allowFly, stickiness, textureID, textureName);
            }
        }
        this.fullyLoaded = true;
    }*/

    protected bool loadFactionsFromJSON (JSONValue mapData) {
        import std.uni: toLower;
        import std.algorithm.searching;
        
        this.factions ~= new Faction(name:"Player", isPlayer:true, map:this);
        this.factionsByName["player"] = this.factions[$-1];
        if ("factions" in mapData) {
            foreach (factionData; mapData.object["factions"].array) {
                NonPlayerFaction faction;
                if (factionData.type == JSONType.string) {
                    faction = new NonPlayerFaction(factionData.get!string, this);
                    faction.enemyNames ~= "player";
                    factionsByName["player"].enemyNames ~= faction.name;
                }
                else if (factionData.type == JSONType.object) { 
                    faction = new NonPlayerFaction(factionData.object["name"].get!string, this);
                    if ("allies" in factionData) foreach (ally; factionData.object["allies"].array) {
                        faction.allyNames ~= ally.get!string;
                    }
                    if ("enemies" in factionData) foreach (enemy; factionData.object["enemies"].array) {
                        faction.enemyNames ~= enemy.get!string;
                    } else if (!canFind(faction.allyNames, "player")) faction.enemyNames ~= "player";
                    faction.isPlayer = false;
                }
                
                this.factions ~= faction;
                this.factionsByName[faction.name] = faction;
            }
            foreach(faction; this.factions) {
                writeln("There is a faction called "~faction.name);
                faction.setAlliesEnemies(factionsByName);
            }
            return true;
        } else {
            factions ~= new Faction(name: "Enemy");
            factionsByName["enemy"] = factions[$-1];
            factionsByName["enemy"].enemies ~= factionsByName["player"];
            factionsByName["player"].enemies ~= factionsByName["enemies"];
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

    void endTurn() {
        if (this.phase == GamePhase.Preparation) this.turn = 0; //Change this later so that the faction with the first turn is determined by the map file.
        else turn++;
        if (this.turn >= this.factions.length-1) turn = 0;

        if (this.factions[this.turn].isPlayer) this.phase = GamePhase.PlayerTurn;
        else this.phase = GamePhase.NonPlayerTurn;
    }

    void turnReset() { // Only call this if all factions should be reset.
        import std.conv;
        
        foreach(unit; this.allUnits) {
            if (unit !is null) unit.turnReset;
            else writeln("allUnits contains an empty member");
        }
    }

    void turnReset(string faction) { // Delete this later
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
        if (x >= 0 && x < this.grid.length && y >= 0 && y < this.grid[0].length) return this.grid[x][y];
        else throw new Exception("Tile "~to!string(x)~", "~to!string(y)~" does not exist.");
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

    Faction getFaction(string name) {
        import std.string:toLower;
        if (name in factionsByName) return factionsByName[name];
        else if (name.toLower in factionsByName) return factionsByName[name.toLower];
        else throw new Exception("Faction "~name~" not found.");
    }

    bool removeUnit(Unit unit) { //Should later be replaced with the one in the `UnitArrayManagement` template
        import std.algorithm.searching;
        Unit[] shiftedUnits = allUnits.find(unit);
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

    bool checkObstruction (Vector2i a, Vector2i b) { // Returns true if the tightest path between two points is unobstructed.
        import std.algorithm;
        import std.math;
        debug import std.conv;
        debug import std.stdio;

        Vector2i trans = b - a;
        ushort diagSteps = cast(ushort) min(abs(trans.x), abs(trans.y));
        ushort orthSteps = cast(ushort)(max(abs(trans.x), abs(trans.y)) - diagSteps);
        Vector2i current = a;

        if (a.x < 0 || a.y < 0 || a.x >= this.gridWidth || a.y >= this.gridLength) return false;
        else if (abs(trans.x)<=1 && abs(trans.y)<=1) return true;

        Vector2i stepDiag = Vector2i(sgn(trans.x), sgn(trans.y));
        Vector2i stepOrtho = {0, 0};
        if (abs(trans.x) > abs(trans.y)) stepOrtho.x = stepDiag.x;
        else if (abs(trans.y) > (trans.x)) stepOrtho.y = stepDiag.y;

        bool pathFound = false;

        void tracePath(ushort straightSteps, ushort skews, Vector2i stepStraight, Vector2i stepSkew) {
            current = a;
            uint steplength1 = 1;
            uint remainder = 0;
            {
                uint div = max(1, skews);
                steplength1 = straightSteps / div;
                remainder = straightSteps % div;
            }
            uint steplength2 = steplength1 >> 1;
            steplength1 -= steplength2;
            bool sym = steplength1 == steplength2;

            orthogonalFirst:
            for (ushort cycle=0; cycle<max(1, skews); cycle++) {
                for (ushort stp=0; stp<(steplength1); stp++) {
                    current += stepStraight;
                    if (!grid[current.x][current.y].allowShoot) goto Exit;
                }
                if (sym && cycle < remainder) {
                    current += stepStraight;
                    if (!grid[current.x][current.y].allowShoot) goto Exit;
                }
                if (skews>0) current += stepSkew;
                if (!sym && cycle < remainder) {
                    current += stepStraight;
                    if (!grid[current.x][current.y].allowShoot) goto Exit;
                }
                if (!getTile(current).allowShoot) goto Exit;
                for (ushort stp=0; stp<steplength2; stp++) {
                    current += stepStraight;
                    if (!grid[current.x][current.y].allowShoot) goto Exit;
                }
            }
            debug assert (current == b, "`current` = "~to!string(current.x)~", "~to!string(current.y)~". It should be "~to!string(b.x)~", "~to!string(b.y));
            if (current == b) pathFound = true;
            Exit:
        }

        if (!pathFound && diagSteps >= orthSteps) tracePath(diagSteps, orthSteps, stepDiag, stepOrtho);
        if (!pathFound && orthSteps >= diagSteps) tracePath(orthSteps, diagSteps, stepOrtho, stepDiag);

        return pathFound;
    }
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
    destroy(unitB);
    assert(map.allUnits == [unitA, unitC], "Map.deleteUnit function did not work as expected.");
    writeln("Map unittest 1 passed.");
}

unittest
{
    import std.algorithm.searching;
    import std.traits;
    debug writeln("Starting Map.checkObstruction unittest");
    const Vector2i origin = Vector2i(12, 12);
    const int range = 12;

    Map map;
    {
        Tile[][] grid;
        grid.length = 25;
        for (uint x=0; x<25; x++) for (uint y=0; y<25; y++) {
            if (x==9 && y==11) grid[x] ~= new Tile(x, y, false, false, false, 0);
            else grid[x] ~= new Tile(true, true, true, 0);
        }
        map = new MapTemp!(Tile, Unit)("test", grid);
    }
    
    const Vector2i[] shouldAttackable = [Vector2i(10,11), Vector2i(9,10), Vector2i(9,9), Vector2i(8,8)];
    
    const Vector2i[] shouldBlocked = [Vector2i(9,11), Vector2i(7,10), Vector2i(6,10)];

    foreach(int x, row; map.getGrid) foreach(int y, tile; row) {
        Vector2i location = {x, y};
        if (measureDistance(origin, Vector2i(x,y)) <= range && Vector2i(x,y) != origin) {
            if (canFind(shouldBlocked, location)) {
                assert(!map.checkObstruction(Vector2i(12,12), Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should be blocked.");
            }
            else if (x >= 12 || y >= 12 || x >= y || canFind(shouldAttackable, location)) {
                assert(map.checkObstruction(Vector2i(12,12), Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should not be blocked.");
            }
        } else assert(!canFind(shouldAttackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should not be in returned coordinates.");
    }
    writeln("`Map.checkObstruction` unittest passed.");
}