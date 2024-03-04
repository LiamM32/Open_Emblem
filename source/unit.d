module unit;

import std.stdio;
import std.conv;
import std.json;

import map;
import item;

class Unit {
    public Map map;
    private int xlocation;
    private int ylocation;
    public string faction;
    public uint spriteID;
    
    static ubyte lookahead = 1;
    
    public string name;
    private uint Mv;
    private bool isFlyer = false;
    public uint MHP;
    public uint Str;
    public uint Def;
    public uint Exp;
    
    public Item[5]* inventory;
    public Weapon* currentWeapon;
    private TileAccess[][] distances;
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
        this.map.allUnits ~= this;
        this(name, stats);
    }

    this(string name, UnitStats stats) {
        this.setDistanceArraySize;
        this.name = name;
        this.Mv = stats.Mv;
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
        this.map.allUnits ~= this;
        this.setDistanceArraySize;
        this(unitData);
    }

    this(Map map, JSONValue unitData, int textureID) {
        this.map = map;
        this.map.allUnits ~= this;
        this.setDistanceArraySize;
        this(unitData);
    }

    this(JSONValue unitData) {
        import std.algorithm.searching;
        this.name = unitData.object["Name"].get!string;
        if ("Movement type" in unitData.object) this.isFlyer = unitData.object["Movement type"].get!string.canFind("fly");
        else this.isFlyer = false;
        this.Mv = unitData.object["Mv"].get!uint;
        this.MHP = unitData.object["MHP"].get!uint;
        this.Str = unitData.object["Str"].get!uint;
        this.Def = unitData.object["Def"].get!uint;
    }

    /*~this() {
        if (this in map.allUnits) {

        }
    }*/
    
    void setLocation(int x, int y, bool runUpdateDistances = true) { //runUpdateDistances should be false if the map isn't fully loaded.
        this.xlocation = x;
        this.ylocation = y;
        
        writeln(this.name ~ " location is now " ~ to!string(x) ~ ", " ~ to!string(y));
        
        writeln(this.map.getTile(x,y));
        this.map.getTile(x, y).setOccupant(this);
        
        if (this.map.fullyLoaded) this.updateDistances(0);
        write("Finished Unit.setLocation.");
    }

    bool attack (uint x, uint y) {
        if (distances[x][y].distance > this.currentWeapon.range) return false;
        if (this.map.getTile(x, y).occupant is null) return false;

        Unit opponent = *this.map.getTile(x, y).occupant;
        opponent.HP -= (this.Str * this.Str)/(this.Str + opponent.Def);

        return true;
    }

    public void updateDistances(uint distancePassed) {
        
        foreach(int x, row; this.map.getGrid()) {
            foreach(int y, mapTile; row) {
                this.distances[x][y].distance = 0;
                this.distances[x][y].reachable = false;
                this.distances[x][y].measured = false;
            }
        }

        updateDistances(distancePassed, this.xlocation, this.ylocation);
    }
    
    private bool updateDistances(uint distancePassed, int x, int y) {
        import tile;
        write("Doing Unit.updateDistances. Now at tile "~to!string(x)~", "~to!string(y)~". ");
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer)) return false;
        if (this.distances[x][y].measured && this.distances[x][y].distance <= distancePassed) return false;
        else if (this.distances[x][y].distance <= this.Mv) this.distances[x][y].reachable = true;
        writeln("distancePassed = "~to!string(distancePassed));
        
        this.distances[x][y].distance = distancePassed;
        this.distances[x][y].measured = true;
        
        distancePassed += this.map.getTile(x, y).stickyness;
        
        if (distancePassed <= this.Mv * this.lookahead -2) {
            bool canWest = false;
            bool canNorth = false;
            bool canEast = false;
            bool canSouth = false;
            if (x > 0) canWest = this.updateDistances(distancePassed +2, x-1, y);
            if (y+1 < this.map.getLength()) canNorth = this.updateDistances(distancePassed +2, x, y+1);
            if (x+1 < this.map.getWidth()) canEast = this.updateDistances(distancePassed +2, x+1, y);
            if (y > 0) canSouth = this.updateDistances(distancePassed +2, x, y-1);
            
            if (distancePassed <= this.Mv * this.lookahead -3) {
                if (canWest && canSouth) this.updateDistances(distancePassed +3, x-1, y-1);
                if (canWest && canNorth) this.updateDistances(distancePassed +3, x-1, y+1);
                if (canEast && canNorth) this.updateDistances(distancePassed +3, x+1, y+1);
                if (canEast && canSouth) this.updateDistances(distancePassed +3, x+1, y-1);
            }
        }
        return true;
    }

    void setDistanceArraySize() {
        this.distances.length = this.map.getWidth;
        foreach(ref row; this.distances) row.length = this.map.getLength;
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
}

struct TileAccess
{
    uint distance;
    bool reachable = false;
    bool measured = false;
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
    Map map = new Map(cast(ushort)8, cast(ushort)8);
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
}