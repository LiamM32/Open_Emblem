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
    
    //static ubyte lookahead = 1;
    
    public string name;
    public uint Mv;
    private bool isFlyer = false;
    public uint MHP;
    public uint Str;
    public uint Def;
    public uint Exp;
    
    public Item[5] inventory;
    public Weapon currentWeapon;
    protected TileAccess[][] tileReach;
    public int MvRemaining;
    alias moveRemaining = MvRemaining;
    public bool hasActed;
    public bool finishedTurn;
    public int HP;

    version (moreCaching) {
        protected TileAccess*[] reachableTiles; //Cache of reachable members of `tileReach`
        protected TileAccess*[] attackableTiles;; //Cache of members of `tileReach` attackable this or next turn
    }

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

        if (map.allTilesLoaded) this.setTileReachArraySize;
    }

    this(string name, Map map, UnitStats stats) {
        this.map = map;
        this(name, stats);
        if (map.allTilesLoaded) this.setTileReachArraySize;
    }

    this(string name, UnitStats stats) {
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
        if (map.allTilesLoaded) this.setTileReachArraySize;
        this(unitData);
    }

    this(Map map, JSONValue unitData, int textureID) {
        this.map = map;
        if (map.allTilesLoaded) this.setTileReachArraySize;
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

        if ("faction" in unitData.object || "Faction" in unitData.object) {
            this.faction = map.getFaction(unitData.object["faction"].get!string);
        }
    }

    bool alive = true;

    ~this() {
        this.alive = false;
        if (this.map !is null) {
            this.map.removeUnit(this);
        }
        if (this.faction !is null) this.faction.removeUnit(this);
        //writeln("Unit "~this.name~"has been deleted.");
        if (this.currentTile !is null) this.currentTile.occupant = null;
    }

    void turnReset() {
        this.hasActed = false;
        this.finishedTurn = false;
        this.MvRemaining = this.Mv;
        debug assert (this.currentTile.occupant == this, "Unit "~this.name~": `this.currentTile.occupant != this`");
        updateReach();
    }
    
    void setLocation(Tile destination, const bool runUpdateReach) {
        destination.setOccupant(this);
        foreach (int x, row; this.map.getGrid) {
            foreach (int y, someTile; row) if (someTile == destination) {
                this.xlocation = x;
                this.ylocation = y;
                break;
            }
        }
        if (map.allTilesLoaded() && runUpdateReach) updateReach();
    }
    
    void setLocation(int x, int y, const bool runUpdateReach = true) { //runUpdateReach should be removed due to map.fullyLoaded being used instead. However, removing it causes a segfault.
        this.xlocation = x;
        this.ylocation = y;
        this.currentTile = this.map.getTile(x,y);
        
        writeln(this.name ~" location is now "~to!string(x)~", "~to!string(y));
        this.map.getTile(x, y).setOccupant(this);
        
        if (map.allTilesLoaded()) updateReach();
    }

    Vector2i getLocation() {
        return Vector2i(x:this.xlocation, y:this.ylocation);
    }

    bool move (int x, int y) {
        if (this.tileReach[x][y].reachable && map.getTile(x,y).occupant is null) {
            this.moveRemaining -= this.tileReach[x][y].distance;
            this.currentTile.occupant = null;
            this.setLocation(x, y, true);
            writeln(this.name~" has "~to!string(MvRemaining)~" Mv remaining.");
            return true;
        } else return false;
    }

    bool attack (uint x, uint y) {
        if ((map.getTile(x, y).occupant !is null) &&
            (measureDistance(this.getLocation, Vector2i(x,y)) <= attackRange) &&
            map.checkObstruction(this.getLocation, Vector2i(x,y))
            ) {
            Unit opponent = this.map.getTile(x, y).occupant;
            opponent.receiveDamage((this.Str * this.Str)/(this.Str + opponent.Def));

            this.hasActed = true;

            return true;
        } else return false;
    }

    bool canAttack (uint x, uint y) {
        if ((map.getTile(x, y).occupant !is null) &&
            (measureDistance(this.getLocation, Vector2i(x,y)) <= attackRange) &&
            map.checkObstruction(this.getLocation, Vector2i(x,y))
            ) return true;
        else return false;
    }

    AttackPotential getAttackPotential (Unit opponent, uint distance=2) {
        short damage = cast(short)((this.Str * this.Str)/(this.Str + opponent.Def));
        return AttackPotential(damage:damage);
    }

    void receiveDamage(int damage) {
        this.HP -= damage;
        debug writeln(this.name~" has received ", damage, " damage. HP now at ", this.HP);
        if (this.HP < 0) {
            writeln(this.name~" has fallen.");
            destroy(this);
        }
    }

    ushort attackRange() {
        if (currentWeapon !is null) {
            return currentWeapon.range;
        } else {
            return 2;
        }
    }

    public void updateReach(ubyte lookahead=1) {
        debug writeln("Updating tileReach for "~this.name);
        if (tileReach.length==0) setTileReachArraySize();
        foreach(int x, ref row; map.getGrid()) {
            foreach(int y, ref mapTile; row) {
                this.tileReach[x][y].reset;
                this.tileReach[x][y].tile = mapTile;
            }
        }
        version (moreCaching) {
            this.reachableTiles.length = 0;
            this.attackableTiles.length = 0;
        }

        updateReach(0, this.xlocation, this.ylocation, this.facing, lookahead);
        setAttackable(Vector2i(xlocation, ylocation), true);
    }
    
    private bool updateReach(uint distancePassed, int x, int y, Direction wentIn, ubyte lookahead=1) {
        import tile;
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer) && distancePassed > 0) return false;
        if (this.tileReach[x][y].measured && this.tileReach[x][y].distance <= distancePassed) return true;
        
        this.tileReach[x][y].distance = distancePassed;
        this.tileReach[x][y].measured = true;
        this.tileReach[x][y].directionTo = wentIn;
        if (distancePassed <= this.MvRemaining) {
            version (moreCaching) if (!tileReach[x][y].reachable) this.reachableTiles ~= &tileReach[x][y];
            this.tileReach[x][y].reachable = true;
        }
        
        auto stickyness = this.map.getTile(x, y).stickyness;
        distancePassed += stickyness;
        
        if (distancePassed <= this.MvRemaining*lookahead -2) {
            bool canWest = false;
            bool canNorth = false;
            bool canEast = false;
            bool canSouth = false;
            if (x > 0) canWest = this.updateReach(distancePassed +2, x-1, y, Direction.W, lookahead);
            if (y > 0) canNorth = this.updateReach(distancePassed +2, x, y-1, Direction.N, lookahead);
            if (x+1 < this.map.getWidth()) canEast = this.updateReach(distancePassed +2, x+1, y, Direction.E, lookahead);
            if (y+1 < this.map.getLength()) canSouth = this.updateReach(distancePassed +2, x, y+1, Direction.S, lookahead);

            distancePassed += stickyness>>1;
            if (distancePassed <= this.MvRemaining*lookahead -3) {
                if (canWest && canNorth) this.updateReach(distancePassed +3, x-1, y-1, Direction.NW, lookahead);
                if (canWest && canSouth) this.updateReach(distancePassed +3, x-1, y+1, Direction.SW, lookahead);
                if (canEast && canSouth) this.updateReach(distancePassed +3, x+1, y+1, Direction.SE, lookahead);
                if (canEast && canNorth) this.updateReach(distancePassed +3, x+1, y-1, Direction.NE, lookahead);
            }
        }
        return true;
    }

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
            if (!tileReach[tileLoc.x][tileLoc.y].attackableAfter) {
                tileReach[tileLoc.x][tileLoc.y].attackableAfter = true;
                attackableTiles ~= &tileReach[tileLoc.x][tileLoc.y];
            }
            if (forNow) this.tileReach[tileLoc.x][tileLoc.y].attackableNow = true;
        }
    }

    void setTileReachArraySize() {
        this.tileReach.length = this.map.getWidth;
        foreach(uint x, ref row; this.tileReach) {
            row.length = this.map.getLength;
            foreach (uint y, ref tileAccess; row) tileAccess.tile = map.getTile(x,y);
        }
    }

    TileAccess getTileAccess(Vector2i location) {
        if (location.x <= 0 && location.y <= 0 && location.x >= map.getWidth && location.y >= map.getLength) {
            return this.tileReach[location.x][location.y];
        } else return TileAccess(tile:null, measured:true, reachable:false, attackableNow:false, attackableAfter:false);
    }
    
    TileAccess getTileAccess(int x, int y) {
        debug if (x<0 || x>=tileReach.length || y<0 || y>=tileReach[x].length) throw new Exception("Called `getTileAccess` for non-existent location "~to!string(x)~", "~to!string(y));
        return this.tileReach[x][y];
    }

    version (noCache) T[] getReachable(T)() {
        T[] reachableTiles;
        foreach (int x, row; this.tileReach) {
            foreach (int y, tileAccess; row) {
                static if (is(T==Tile)) reachableTiles ~= tileAccess.tile;
                static if (is(T==Vector2i)) reachableTiles ~= Vector2i(x, y);
                static if (is(T==TileAccess)) reachableTiles ~= tileAccess;
            }
        }
        return reachableTiles;
    }

    version (moreCaching) {
        T[] getReachable(T)() {
            T[] tiles;
            foreach (tileAccess; this.reachableTiles) {
                static if (is(T==TileAccess)) tiles ~= *tileAccess;
                static if (is(T==Tile)) tiles ~= tileAccess.tile;
                static if (is(T==Vector2i)) tiles ~= tileAccess.tile.location;
            }
            return tiles;
        }
        
        T[] getAttackable(T)() {
            T[] tiles;
            foreach (tileAccess; this.attackableTiles) {
                static if (is(T==TileAccess)) tiles ~= *tileAccess;
                static if (is(T==Tile)) tiles ~= tileAccess.tile;
                static if (is(T==Vector2i)) tiles ~= tileAccess.tile.location;
            }
            return tiles;
        }
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

    Tile[] getPath(Vector2i dest) {
        assert (tileReach[dest.x][dest.y].reachable);
        Tile[] path;
        debug writeln(dest);
        Tile thisTile = tileReach[dest.x][dest.y].tile;
        debug assert (thisTile.location == dest);
        Direction directionTo = tileReach[dest.x][dest.y].directionTo;
        if (map.getTile(dest)==this.currentTile) return [];
        else path = getPath(offsetByDirection(directionTo+4, dest));
        path ~= thisTile;
        return path;
    }

    Tile[] getPath(int x, int y) {
        return this.getPath(Vector2i(x,y));
    }
}

struct TileAccess
{
    Tile tile;
    Direction directionTo; //The tile that the unit would be moving in when reaching this tile in the optimal path.
    uint distance = 65535;
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

struct AttackPotential {
    short damage;
}

template UnitArrayManagement(alias Unit[] unitsArray) {
    bool removeUnit(Unit unit) {
        import std.algorithm.searching;
        writeln("Doing `removeUnit`");
        Unit[] shiftedUnits = unitsArray.find(unit);
        ushort unitKey = cast(ushort)(unitsArray.length - shiftedUnits.length);
        debug {
            writeln("unitsArray: ");
            foreach (listedUnit; unitsArray) writeln(listedUnit.name~", ");
            writeln("shiftedUnits: ");
            foreach (listedUnit; shiftedUnits) writeln(listedUnit.name~", ");
        }
        if (shiftedUnits.length > 0) {
            debug writeln("shiftedUnits.length > 0");
            unitsArray[$-shiftedUnits.length] = null;
            for (ushort i=0; i<shiftedUnits.length-1; i++) {
                debug writeln("In loop. unitKey = ", unitKey, ", i = ", i);
                unitsArray[unitKey+i] = unitsArray[unitKey+i+1];
            }
            unitsArray.length--;
            return true;
        } else return false;
    }
}


/*unittest //Currently incomplete test of attack damage
{
    //debug writeln("Starting Unit attack unittest.");
    Map map = new Map(cast(ushort)8, cast(ushort)8);
    UnitStats stats;
    stats.Str = 24;
    stats.Def = 12;
    
    Unit ally = new Unit("Ally", map, stats);
    Unit enemy = new Unit("Enemy", map, stats);
    ally.setLocation(3, 3);
    enemy.setLocation(3, 4);
}*/

unittest
{
    import std.algorithm.searching;
    Unit unitA;
    {
        debug writeln("Starting UnitStats unittest.");
        JSONValue unitJSON;
        unitJSON["Name"] = "Soldier";
        unitJSON["Mv"] = 7;
        unitJSON["Str"] = 24;
        unitJSON["Def"] = 18;
        unitJSON["MHP"] = 120;
        unitA = new Unit(unitJSON);
        UnitStats stats = unitA.getStats();
        assert(stats.Mv == 7);
        assert(stats.isFlyer == false);
        assert(stats.MHP == 120);
        assert(stats.Str == 24);
        assert(stats.Def == 18);
        writeln("UnitStats unittest passed.");
    }
    Map map = new Map(cast(ushort)12, cast(ushort)12);
    unitA.map = map;
    version (moreCaching) {
        debug writeln("Starting Unit caching unittest.");
        unitA.setLocation(5, 5, true);

        TileAccess[] reachableTiles = unitA.getReachable!TileAccess;
        Vector2i[] reachableCoords;
        foreach (tileAccess; reachableTiles) {
            reachableCoords ~= Vector2i(tileAccess.tile.x, tileAccess.tile.y);
        }
        for (uint x=0; x<12; x++) for (uint y=0; y<12; y++) {
            if (measureDistance(Vector2i(5,5),Vector2i(x,y)) <= unitA.Mv) {
                assert(canFind(reachableCoords, Vector2i(x,y)), "Did not find tile "~to!string(x)~", "~to!string(y)~" in returned tiles.");
            } else assert(!canFind(reachableCoords, Vector2i(x,y)), "Unexpectedly found tile "~to!string(x)~", "~to!string(y)~" in returned tiles.");
        }
        writeln("Passed Unit caching unittest.");
    }
    destroy(unitA);
    destroy(map);
    debug writeln("Destroyed objects from Unit unittests.");
}