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
    if (!direction.diagonal) for(ubyte st=1; st<=range>>1; st++) { // Scanning in one straight direction from origin.
        trunkCurrent = origin + offset*st;
        version (gridBoundsCheck) if (trunkCurrent.x < 0 || trunkCurrent.y < 0 || trunkCurrent.x >= mapSize.x || trunkCurrent.y >= mapSize.y) break;
        if (!map.getTile(trunkCurrent).allowShoot) break; // Break if an obstructing tile is reached.
        attackable ~= trunkCurrent;
        {
            Vector2i current = trunkCurrent;
            for(ubyte tb=1; st*2+tb*3<=range; tb++) { // Start scanning at a slightly different angle.
                current = offsetByDirection(direction-1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(ubyte sb=0; sb<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(ubyte sb=0; sb+1<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
            current = trunkCurrent;
            for(ubyte tb=1; st*2+tb*3<=range; tb++) { // Start scanning at another slightly different angle.
                current = offsetByDirection(direction+1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(ubyte sb=0; sb<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(ubyte sb=0; sb+1<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
        }
    } else for(ubyte st=1; st<=range/3; st++) { // Scanning in one straight direction from origin.
        trunkCurrent = origin + offset*st;
        version (gridBoundsCheck) if (trunkCurrent.x < 0 || trunkCurrent.y < 0 || trunkCurrent.x >= mapSize.x || trunkCurrent.y >= mapSize.y) break;
        if (!map.getTile(trunkCurrent).allowShoot) break; // Break if an obstructing tile is reached.
        attackable ~= trunkCurrent;
        {
            Vector2i current = trunkCurrent;
            for(ubyte tb=1; st*3+tb*2<=range; tb++) { // Start scanning at a slightly different angle.
                current = offsetByDirection(direction-1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(ubyte sb=0; sb<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(ubyte sb=0; sb+1<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
            current = trunkCurrent;
            for(ubyte tb=1; st*3+tb*2<=range; tb++) { // Start scanning at another slightly different angle.
                current = offsetByDirection(direction+1, current);
                version (gridBoundsCheck) if (current.x < 0 || current.y < 0 || current.x >= mapSize.x || current.y >= mapSize.y) break;
                for(ubyte sb=0; sb<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
                attackable ~= current;
                for(ubyte sb=0; sb+1<st>>1; sb++) if (map.getTile(current) is null || !map.getTile(current).allowShoot) break;
            }
        }
    }
    return attackable;
}

unittest
{
    import std.stdio;
	import std.conv;
    import std.algorithm.searching;
    import std.traits;
    import unit;
    debug writeln("Starting projectileScan unittest");
    const Vector2i origin = Vector2i(12, 12);
    const int range = 10;
    Map map = new MapTemp!(Tile, Unit)(cast(ushort)25, cast(ushort)25);
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
        if (measureDistance(origin, Vector2i(x,y)) <= range && Vector2i(x,y) != origin) {
            assert(canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" not found in returned coordinates.");
        } else assert(!canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should not be in returned coordinates.");
    }
    writeln("`projectileScan` unittest passed! Yay!");
}