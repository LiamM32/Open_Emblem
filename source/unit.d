module unit;

import std.stdio;
import std.conv;
import std.json;

import map;
import item;

class Unit {
    private Map map;
    private int xlocation;
    private int ylocation;
    public string faction;
    public uint spriteID;
    
    static ubyte lookahead = 1;
    
    private string name;
    private uint Mv;
    private bool isFlyer = false;
    public uint MHP;
    public uint Str;
    public uint Def;
    public uint Exp;
    
    /*public Item[5] inventory;
    public ubyte currentWeapon;*/
    public Weapon currentWeapon;
    private TileAccess[int][int] distances;
    public int HP;

    this(string name, Map map, short Mv) {
        this.map = map;
        //this.distances.length = map.getWidth;
        foreach(ref row; this.distances) {
            //row.length = map.getLength;
        }
        
        this.name = name;
        this.Mv = Mv;

        this.HP = this.MHP;
    }

    this(string name, Map map, unitStats stats) {
        this.map = map;
        this.name = name;
        this.Mv = stats.Mv;
        this.MHP = this.MHP;
        this.isFlyer = stats.isFlyer;
        this.Str = stats.Str;
        this.Def = stats.Def;
    }

    this(Map map, JSONValue unitData) {
        this.map = map;
        this(unitData);
    }

    this(Map map, JSONValue unitData, int textureID) {
        this.map = map;
        this(unitData);
    }

    this(JSONValue unitData) {
        import std.algorithm.searching;
        this.name = unitData.object["Name"].get!string;
        this.isFlyer = unitData.object["Movement type"].get!string.canFind("fly");
        this.Mv = unitData.object["Mv"].get!uint;
        this.MHP = unitData.object["MHP"].get!uint;
        this.Str = unitData.object["Str"].get!uint;
        this.Def = unitData.object["Def"].get!uint;
    }
    
    void setLocation(int x, int y) {
        this.xlocation = x;
        this.ylocation = y;
        
        writeln(this.name ~ " location: " ~ to!string(x) ~ ", " ~ to!string(y));
        
        this.map.getTile(x, y).occupant = this;
        
        foreach(ref row; this.distances) {
            foreach(ref tile; row) {
                tile.distance = 0;
                tile.reachable = false;
                tile.measured = false;
            }
        }
        
        this.updateDistances(0, x, y);
        
        writeln(this.distances);
    }

    bool attack (uint x, uint y) {
        if (distances[x][y].distance > this.currentWeapon.range) return false;

        Unit opponent = this.map.getTile(x, y).occupant;
        opponent.HP -= (this.Str * this.Str)/(this.Str + opponent.Def);

        return true;
    }
    
    private void updateDistances(uint distancePassed, int x, int y) {
        if ((x < 0) || (y < 0) || (x > this.map.getWidth) || (y > this.map.getLength)) return;
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer)) return;
        if (this.distances[x][y].measured && this.distances[x][y].distance <= distancePassed) return;
        else if (this.distances[x][y].distance <= this.Mv) this.distances[x][y].reachable = true;
        
        this.distances[x][y].distance = distancePassed;
        this.distances[x][y].measured = true;
        
        distancePassed += this.map.getTile(x, y).stickyness;
        
        if (distancePassed <= this.Mv * this.lookahead -2) {
            this.updateDistances(distancePassed +2, x-1, y);
            this.updateDistances(distancePassed +2, x, y+1);
            this.updateDistances(distancePassed +2, x+1, y);
            this.updateDistances(distancePassed +2, x, y-1);
            
            if (distancePassed <= this.Mv * this.lookahead -3) {
                this.updateDistances(distancePassed +3, x-1, y-1);
                this.updateDistances(distancePassed +3, x-1, y+1);
                this.updateDistances(distancePassed +3, x+1, y+1);
                this.updateDistances(distancePassed +3, x+1, y-1);
            }
        }
    }

    unitStats getStats() {
        unitStats stats;
        stats.Mv = this.Mv;
        stats.isFlyer = this.isFlyer;
        stats.MHP = this.MHP;
        stats.Str = this.Str;
        stats.Def = this.Def;

        return stats;
    }

    /*struct unitStats {
        uint Mv;
        bool isFlyer = false;
        uint MHP;
        uint Str;
        uint Def;
    }*/
}

struct TileAccess
{
    uint distance;
    bool reachable = false;
    bool measured = false;
}

struct unitStats {
    uint Mv;
    bool isFlyer = false;
    uint MHP;
    uint Str;
    uint Def;
}

unittest //Currently incomplete
{
    Map map = new Map(cast(ushort)8, cast(ushort)8);
    unitStats stats;
    stats.Str = 24;
    stats.Def = 12;
    
    Unit ally = new Unit("Ally", map, stats);
    Unit enemy = new Unit("Enemy", map, stats);

}
