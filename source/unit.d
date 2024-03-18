module unit;

import std.stdio;
import std.conv;
import std.json;

import common;
import map;
import tile;
import item;
import faction;

class Unit {
    public Map map;
    public int xlocation;
    public int ylocation;
    public Direction facing;
    public Tile currentTile;
    public Faction faction;
    public uint spriteID;
    
    static ubyte lookahead = 1;
    
    public string name;
    private uint Mv;
    private bool isFlyer = false;
    public uint MHP;
    public uint Str;
    public uint Def;
    public uint Exp;
    
    public Item[5] inventory;
    public Weapon currentWeapon;
    protected TileAccess[][] distances;
    public int MvRemaining;
    alias moveRemaining = MvRemaining;
    public bool hasActed;
    public bool finishedTurn;
    public int HP;

    this(string name, Map map, UnitStats stats, uint xlocation, uint ylocation) {
        this(name, map, stats);
        try {
            map.getTile(xlocation, ylocation).setOccupant(this);
        } catch (Exception excep) {
            writeln(excep);
            writeln("Tried to set Unit "~this.name~"to a non-existent tile.");
        }
        this.xlocation = xlocation;
        this.ylocation = ylocation;
    }

    this(string name, Map map, UnitStats stats) {
        this.map = map;
        this(name, stats);
    }

    this(string name, UnitStats stats) {
        this.setDistanceArraySize;
        this.name = name;
        this.Mv = stats.Mv;
        this.MvRemaining = this.Mv;
        this.MHP = this.MHP;
        this.isFlyer = stats.isFlyer;
        this.Str = stats.Str;
        this.Def = stats.Def;
    }

    this(Map map, JSONValue unitData, int xlocation, int ylocation) {
        this(map, unitData);
        try {
            map.getTile(xlocation, ylocation).setOccupant(this);
        } catch (Exception excep) {
            writeln(excep);
            writeln("Tried to set Unit "~this.name~"to a non-existent tile.");
        }
        this.xlocation = xlocation;
        this.ylocation = ylocation;
    }
    
    this(Map map, JSONValue unitData) {
        this.map = map;
        this.setDistanceArraySize;
        this(unitData);
    }

    this(Map map, JSONValue unitData, int textureID) {
        this.map = map;
        this.setDistanceArraySize;
        this(unitData);
    }

    this(JSONValue unitData) {
        import std.algorithm.searching;
        this.name = unitData.object["Name"].get!string;
        if ("Movement type" in unitData.object) this.isFlyer = unitData.object["Movement type"].get!string.canFind("fly");
        else this.isFlyer = false;
        this.Mv = unitData.object["Mv"].get!uint;
        this.MvRemaining = this.Mv;
        this.MHP = unitData.object["MHP"].get!uint;
        this.Str = unitData.object["Str"].get!uint;
        this.Def = unitData.object["Def"].get!uint;

        if ("Weapon" in unitData.object) {
            Weapon weapon = new Weapon(unitData.object["Weapon"]); //Come back here later to uncomment when the memory error is resolved.
            this.currentWeapon = weapon;
            this.inventory[0] = weapon;
        }
    }

    ~this() {
        this.map.deleteUnit(this, false);
        //writeln("Unit "~this.name~"has been deleted.");
    }

    void turnReset() {
        this.hasActed = false;
        this.finishedTurn = false;
        this.MvRemaining = this.Mv;
        updateDistances();
    }
    
    void setLocation(Tile destination, bool runUpdateDistances) {
        destination.setOccupant(this);
        foreach (int x, row; this.map.getGrid) {
            foreach (int y, someTile; row) if (someTile == destination) {
                this.xlocation = x;
                this.ylocation = y;
                break;
            }
        }
        if (runUpdateDistances) this.updateDistances();
    }
    
    void setLocation(int x, int y, bool runUpdateDistances = true) { //runUpdateDistances should be removed due to map.fullyLoaded being used instead. However, removing it causes a segfault.
        this.xlocation = x;
        this.ylocation = y;
        this.currentTile = this.map.getTile(x,y);
        
        writeln(this.name ~ " location is now " ~ to!string(x) ~ ", " ~ to!string(y));
        
        writeln(this.map.getTile(x,y));
        this.map.getTile(x, y).setOccupant(this);
        
        if (runUpdateDistances && this.map.allTilesLoaded()) this.updateDistances();
    }

    bool move (int x, int y) {
        if (this.distances[x][y].reachable && map.getTile(x,y).occupant is null) {
            this.moveRemaining -= this.distances[x][y].distance;
            this.currentTile.occupant = null;
            this.setLocation(x, y, true);
            writeln(this.name~" has "~to!string(MvRemaining)~" Mv remaining.");
            return true;
        } else return false;
    }

    bool attack (uint x, uint y) {
        if (currentWeapon !is null || !distances[x][y].attackableNow /*> this.currentWeapon.range*/) return false;
        if (this.map.getTile(x, y).occupant is null) return false;

        Unit opponent = this.map.getTile(x, y).occupant;
        opponent.HP -= (this.Str * this.Str)/(this.Str + opponent.Def);

        this.hasActed = true;

        return true;
    }

    short getAttackDamage (Unit opponent, ushort distance=2) {
        return cast(short)((this.Str * this.Str)/(this.Str + opponent.Def));
    }

    public void updateDistances() {
        writeln("Unit "~this.name~" is on map "~to!string(this.map)~". Updating distances");
        foreach(int x, row; this.map.getGrid()) {
            foreach(int y, mapTile; row) {
                this.distances[x][y].reset;
                this.distances[x][y].tile = mapTile;
            }
        }

        updateDistances(0, this.xlocation, this.ylocation, this.facing);
        setAttackable(Vector2i(xlocation, ylocation), true);
        writeln("Finished updating distances for unit "~this.name);
    }
    
    private bool updateDistances(uint distancePassed, int x, int y, Direction wentIn) {
        import tile;
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer) && distancePassed > 0) return false;
        if (this.distances[x][y].measured && this.distances[x][y].distance <= distancePassed) return true;
        
        this.distances[x][y].distance = distancePassed;
        this.distances[x][y].measured = true;
        this.distances[x][y].directionTo = wentIn;
        if (distancePassed <= this.MvRemaining) this.distances[x][y].reachable = true;
        
        auto stickyness = this.map.getTile(x, y).stickyness;
        distancePassed += stickyness;
        
        if (distancePassed <= this.MvRemaining*lookahead -2) {
            bool canWest = false;
            bool canNorth = false;
            bool canEast = false;
            bool canSouth = false;
            if (x > 0) canWest = this.updateDistances(distancePassed +2, x-1, y, Direction.W);
            if (y > 0) canNorth = this.updateDistances(distancePassed +2, x, y-1, Direction.N);
            if (x+1 < this.map.getWidth()) canEast = this.updateDistances(distancePassed +2, x+1, y, Direction.E);
            if (y+1 < this.map.getLength()) canSouth = this.updateDistances(distancePassed +2, x, y+1, Direction.S);

            distancePassed += stickyness>>1;
            if (distancePassed <= this.MvRemaining*lookahead -3) {
                if (canWest && canNorth) this.updateDistances(distancePassed +3, x-1, y-1, Direction.NW);
                if (canWest && canSouth) this.updateDistances(distancePassed +3, x-1, y+1, Direction.SW);
                if (canEast && canSouth) this.updateDistances(distancePassed +3, x+1, y+1, Direction.SE);
                if (canEast && canNorth) this.updateDistances(distancePassed +3, x+1, y-1, Direction.NE);
            }
        }
        return true;
    }

    /*void setAttackableNew(int range) {
        import std.algorithm.comparison;
        byte maxStepx = min()
        byte maxStepy;
        /*foreach (xoffset; -(range>>1) .. (range>>1)) foreach (yoffset; -(range>>1) .. (range>>1)) if (measureDistance(Vector2(xoffset,yoffset))*2<range) {
            a
        }*//*
        foreach (stepSize; 1 .. (range>>1)-1);

        void scan(Vector2i origin, Direction direction, bool forNow){
            Vector2i offset = offsetByDirection(direction);
            Vector2i trunkCurrent;
            for(st=1; st<=range>>1; st++) { // Scanning in one straight direction from origin.
                trunkCurrent = origin + offset*st;
                if (!map.getTile(trunkCurrent).allowShoot) break; // Break if an obstructing tile is reached.
                this.distances[trunkCurrent.x][trunkCurrent.y].attackableAfter = true;
                if (forNow) this.distances[trunkCurrent.x][trunkCurrent.y].attackableNow = true;
                if (st <= range>>2) {
                    Vector2i current = trunkCurrent;
                    for(tb=1; st*2+tb*3<=range) { // Start scanning at a slightly different angle.
                        current = offsetByDirection(direction-1, current);
                        for(sb=0; sb<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                        this.distances[current.x][current.y].attackableAfter = true;
                        if (forNow) this.distances[current.x][current.y].attackableNow = true;
                        for(sb=0; sb+1<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                    }
                }
            }
        }
    }*/

    private void setAttackable(Vector2i loc, bool forNow) { //This function will probably get replaced eventually with weapon-specific functions.
        short range;
        if (currentWeapon !is null) range = currentWeapon.range;
        else range = 2;
        Vector2i[] attackableCoords;
        attackableCoords ~= projectileScan(loc, Direction.N, range, map);
        attackableCoords ~= projectileScan(loc, Direction.NE, range, map);
        attackableCoords ~= projectileScan(loc, Direction.E, range, map);
        attackableCoords ~= projectileScan(loc, Direction.SE, range, map);
        attackableCoords ~= projectileScan(loc, Direction.S, range, map);
        attackableCoords ~= projectileScan(loc, Direction.SW, range, map);
        attackableCoords ~= projectileScan(loc, Direction.W, range, map);
        attackableCoords ~= projectileScan(loc, Direction.NW, range, map);
        foreach(tileLoc; attackableCoords) {
            this.distances[tileLoc.x][tileLoc.y].attackableAfter = true;
            if (forNow) this.distances[tileLoc.x][tileLoc.y].attackableNow = true;
        }
    }

    void setDistanceArraySize() {
        this.distances.length = this.map.getWidth;
        foreach(ref row; this.distances) row.length = this.map.getLength;
    }

    TileAccess getDistance(Vector2i location) {
        if (location.x <= 0 && location.y <= 0 && location.x >= map.getWidth && location.y >= map.getLength) {
            return this.distances[location.x][location.y];
        } else return TileAccess(tile:null, measured:true, reachable:false, attackableNow:false, attackableAfter:false);
    }
    
    TileAccess getDistance(int x, int y) {
        debug if (x<0 || x>=distances.length || y<0 || y>=distances[x].length) throw new Exception("Called getDistance for non-existent location "~to!string(x)~", "~to!string(y));
        return this.distances[x][y];
    }

    Vector2i[] getReachable() {
        Vector2i[] reachableCoordinates;
        foreach (int x, row; this.distances) {
            foreach (int y, tileAccess; row) {
                reachableCoordinates ~= Vector2i(x, y);
            }
        }
        return reachableCoordinates;
    }

    bool canMove() {
        return this.MvRemaining >= 2;
    }

    UnitStats getStats() {
        UnitStats stats;
        stats.Mv = this.Mv;
        stats.isFlyer = this.isFlyer;
        stats.MHP = this.MHP;
        stats.Str = this.Str;
        stats.Def = this.Def;

        return stats;
    }

    TileAccess[] getPath(Vector2i destination) {
        TileAccess[] path;
        debug writeln(destination);
        TileAccess thisTileAccess = this.distances[destination.x][destination.y];
        Direction directionTo = thisTileAccess.directionTo;
        if (map.getTile(destination)==this.currentTile) return [];
        else path = getPath(offsetByDirection(directionTo+4, destination));
        path ~= getDistance(destination);
        return path;
    }

    TileAccess[] getPath(int x, int y) {
        return this.getPath(Vector2i(x,y));
    }
}

struct TileAccess
{
    Tile tile;
    Direction directionTo; //The tile that the unit would be moving in when reaching this tile in the optimal path.
    uint distance = -1;
    bool measured = false;
    bool reachable = false;
    bool attackableNow = false;
    bool attackableAfter = false;

    void reset() {
        measured = false;
        reachable = false;
        attackableNow = false;
        attackableAfter = false;
    }
}

struct UnitStats {
    uint Mv;
    bool isFlyer = false;
    uint MHP;
    uint Str;
    uint Def;
}

unittest //Currently incomplete test of attack damage
{
    //debug writeln("Starting Unit attack unittest.");
    MapTemp!(Tile,Unit) map = new MapTemp!(Tile,Unit)(cast(ushort)8, cast(ushort)8);
    UnitStats stats;
    stats.Str = 24;
    stats.Def = 12;
    
    Unit ally = new Unit("Ally", map, stats);
    Unit enemy = new Unit("Enemy", map, stats);
    ally.setLocation(3, 3);
    enemy.setLocation(3, 4);
}

unittest
{
    debug writeln("Starting UnitStats unittest.");
    JSONValue unitJSON;
    unitJSON["Name"] = "Soldier";
    unitJSON["Mv"] = 6;
    unitJSON["Str"] = 24;
    unitJSON["Def"] = 18;
    unitJSON["MHP"] = 120;
    Unit testUnit = new Unit(unitJSON);
    UnitStats stats = testUnit.getStats();
    assert(stats.Mv == 6);
    assert(stats.isFlyer == false);
    assert(stats.MHP == 120);
    assert(stats.Str == 24);
    assert(stats.Def == 18);
    writeln("UnitStats unittest passed.");
}