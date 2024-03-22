import std.json;

class Item
{
	string name;
	ushort volume;
}

class Weapon : Item
{
	bool projectile;
	ushort range = 2;
	uint atk;
	uint mass;
	uint RH;
	WeaponType type;

	this(JSONValue data) {
		this.name = data.object["name"].get!string;
		this.volume = data.object["volume"].get!ushort;
		this.atk = data.object["atk"].get!int;
		this.mass = data.object["mass"].get!int;
		this.RH = data.object["RH"].get!int;
		this.range = data.object["range"].get!ushort;

		switch (data.object["type"].get!string) {
			case "knife", "blade", "sword":
				this.type = WeaponType.blade;
				break;
			case "spear", "lance", "pike":
				this.type = WeaponType.spear;
				break;
			case "axe":
				this.type = WeaponType.axe;
				break;
			case "blunt", "hammer", "mace", "club":
				this.type = WeaponType.blunt;
				break;
			case "bow":
				this.type = WeaponType.bow;
				break;
			default:
				throw new Exception("Weapon from JSON has no type");
		}
	}
}

enum WeaponType : ubyte
{
	blade,
	spear,
	axe,
	blunt,
	bow
}

enum WeaponSubType : ushort
{
	dagger,
	sword,
	rapier,
	axe,
	hammer,
	mace,
	morningStar,
	lance,
	spear,
	bow
}

import common;
import map;
import tile;

Vector2i[] projectileScan(Vector2i origin, Direction direction, int range, Map map){
    Vector2i[] attackable;
    Vector2i offset = offsetByDirection(direction);
    Vector2i trunkCurrent;
    Vector2i mapSize = map.getSize;
    if (!direction.diagonal) for(ubyte stTr=1; stTr<=range>>1; stTr++) { // Scanning in one straight direction from origin.
        trunkCurrent = origin + offset*stTr;
        version (gridBoundsCheck) if (trunkCurrent.x < 0 || trunkCurrent.y < 0 || trunkCurrent.x >= mapSize.x || trunkCurrent.y >= mapSize.y) break;
        if (!map.getTile(trunkCurrent).allowShoot) break; // Break if an obstructing tile is reached.
        attackable ~= trunkCurrent;
        if (stTr <= range>>2){
            Vector2i current = trunkCurrent;
            ubyte stBr;
            for(ubyte skews=1; (stTr+skews*stBr)*2+skews*3<=range; skews++) { // Start scanning at a slightly different angle.
                current = offsetByDirection(direction-1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(stBr=0; stBr<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(stBr=0; stBr+1<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
            current = trunkCurrent;
            for(ubyte skews=1; stTr*2+skews*3<=range; skews++) { // Start scanning at another slightly different angle.
                current = offsetByDirection(direction+1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(stBr=0; stBr<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(stBr=0; stBr+1<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
        }
    } else for(ubyte stTr=1; stTr<=range/3; stTr++) { // Scanning in one straight direction from origin.
        trunkCurrent = origin + offset*stTr;
        version (gridBoundsCheck) if (trunkCurrent.x < 0 || trunkCurrent.y < 0 || trunkCurrent.x >= mapSize.x || trunkCurrent.y >= mapSize.y) break;
        if (!map.getTile(trunkCurrent).allowShoot) break; // Break if an obstructing tile is reached.
        attackable ~= trunkCurrent;
        {
            Vector2i current = trunkCurrent;
            ubyte stBr;
            for(ubyte skews=1; stTr*3+skews*2<=range; skews++) { // Start scanning at a slightly different angle.
                current = offsetByDirection(direction-1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(stBr=0; stBr<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(stBr=0; stBr+1<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
            current = trunkCurrent;
            for(ubyte skews=1; stTr*3+skews*2<=range; skews++) { // Start scanning at another slightly different angle.
                current = offsetByDirection(direction+1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(stBr=0; stBr<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(stBr=0; stBr+1<stTr>>1; stBr++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
        }
    }
    return attackable;
}

bool canShoot (Vector2i a, Vector2i b, Map map) {
    import std.algorithm;
    import std.math;
    import std.bigint;
    debug import std.conv;
    debug import std.stdio;

    debug writeln("Doing `canShoot from ",a.x,", ",a.y," to ",b.x,", ",b.y);

    Vector2i trans = b - a;
    ushort diagSteps = cast(ushort) min(abs(trans.x), abs(trans.y));
    ushort orthSteps = cast(ushort)( max(abs(trans.x), abs(trans.y)) - diagSteps );
    Vector2i current = a;

    Vector2i stepDiag = Vector2i(sgn(trans.x), sgn(trans.y));
    Vector2i stepOrtho = {0, 0};
    if (abs(trans.x) > abs(trans.y)) stepOrtho.x = stepDiag.x;
    else if (abs(trans.y) > (trans.x)) stepOrtho.y = stepDiag.y;

    bool pathFound = false;

    void tracePath(ushort straightSteps, ushort skews, Vector2i stepStraight, Vector2i stepSkew) {
        debug writeln("Going to orthoFirst");
        
        current = a;
        uint steplength1 = 1;
        uint remainder;
        if (skews > 0) {
            steplength1 = straightSteps / skews;
            remainder = straightSteps % skews;
        }
        uint steplength2 = (straightSteps - 1) >> 1;
        steplength1 = straightSteps >> 1;
        bool sym = steplength1 == steplength2;
        debug writeln("skews = ", skews);
        debug writeln("straightSteps = ", straightSteps);
        debug writeln("steplength1 = ", steplength1);
        debug writeln("steplength2 = ", steplength2);
        debug writeln("Starting orthoFirst, current = ", current);
        orthogonalFirst:
        for (ushort cycle=0; cycle<max(1, skews); cycle++) {
            debug writeln("Doing orthoFirst cycle ", cycle);
            for (ushort stp=0; stp<(steplength1); stp++) {
                current += stepStraight;
                if (!map.getTile(current).allowShoot) goto Exit;
            }
            debug writeln("Did steplength1, current = ", current);
            if (sym && cycle < remainder) {
                current += stepStraight;
                if (!map.getTile(current).allowShoot) goto Exit;
                debug writeln("Did steplength1 again, current = ", current);
            }
            current += stepSkew;
            debug writeln("Did stepSkew, current = ", current);
            if (!sym && cycle < remainder) {
                current += stepStraight;
                if (!map.getTile(current).allowShoot) goto Exit;
                debug writeln("Did steplength1 again, current = ", current);
            }
            if (!map.getTile(current).allowShoot) goto Exit;
            for (ushort stp=0; stp<steplength2; stp++) {
                current += stepStraight;
                if (!map.getTile(current).allowShoot) goto Exit;
            }
            debug writeln("Did steplength2, current = ", current);
        }
        //assert (current == b, "`current` = "~to!string(current.x)~", "~to!string(current.y)~". It should be "~to!string(b.x)~", "~to!string(b.y));
        if (current == b) pathFound = true;
        Exit:
    }

    if (!pathFound && diagSteps >= orthSteps) tracePath(diagSteps, orthSteps, stepDiag, stepOrtho);
    if (!pathFound && orthSteps >= diagSteps) tracePath(orthSteps, diagSteps, stepOrtho, stepDiag);

    return pathFound;
}


unittest
{
    import std.stdio;
	import std.conv;
    import std.algorithm.searching;
    import std.traits;
    import unit;
    //import tile;
    debug writeln("Starting projectileScan unittest");
    const Vector2i origin = Vector2i(12, 12);
    const int range = 10;

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
    
    Vector2i[] attackable;
    attackable ~= projectileScan(Vector2i(12,12), Direction.N, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.NE, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.E, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.SE, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.S, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.SW, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.W, range, map);
    attackable ~= projectileScan(Vector2i(12,12), Direction.NW, range, map);

    foreach(int x, row; map.getGrid) foreach(int y, tile; row) {
        Vector2i location = {x, y};
        if (measureDistance(origin, Vector2i(x,y)) <= range && Vector2i(x,y) != origin) {
            if ((x<12 && y<12 && (12-x)%3==0 && (12-x)/3==(12-y))||(x==8&&y==11)||(x==y&&y==10)) {
                assert(!canShoot(Vector2i(12,12), Vector2i(x,y), map), "Tile "~to!string(x)~", "~to!string(y)~" should be blocked.");
                //assert(!canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should be blocked.");
            }
            else {
                assert(canShoot(Vector2i(12,12), Vector2i(x,y), map), "Tile "~to!string(x)~", "~to!string(y)~" should not be blocked.");
                assert(canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" not found in returned coordinates.");
            }
        } else assert(!canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should not be in returned coordinates.");
    }
    writeln("`projectileScan` unittest passed! Yay!");
}