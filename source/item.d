import std.json;
import unit;
import std.algorithm.searching:canFind;

@safe class Item
{
	string name;
	ushort volume;
    
    protected ItemOption[] options;

    @safe ItemOption[] getOptions(Unit unit) {
        return options;
    }

    @safe struct ItemOption
    {
        string name;
        @safe void delegate(Unit user) action;
    }
}

class Weapon : Item
{
	bool projectile;
	ushort range = 2;
	uint Atk;
	uint mass;
	uint RH;
    uint crossSection; //The size of the cross-section that would hit the target. Will later become specific to the attack method.
	WeaponType type;
    WeaponSubtype subtype;

	this(JSONValue data) {
        import std.conv;
        import std.string;
        import std.traits;
		this.name = data.object["name"].get!string;
		this.volume = data.object["volume"].get!ushort;
		this.Atk = data.object["atk"].get!int;
		this.mass = data.object["mass"].get!int;
		this.RH = data.object["RH"].get!int;
		this.range = data.object["range"].get!ushort;
        if ("cross section" in data.object) this.crossSection = data.object["cross section"].get!uint;
        else this.crossSection = 2;
        if ("subtype" in data.object) {
            subtype = data.object["subtype"].get!string.to!WeaponSubtype;
            type = subtypeToType[subtype];
        } switch (data.object["type"].get!string) {
			case "knife", "blade", "sword":
				this.type = WeaponType.sword;
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
				if ("type" in data.object) type = data.object["type"].get!string.to!WeaponType;
                else if (name.toLower.canFind(EnumMembers!WeaponType)) type = name.toLower.to!WeaponType;
                else throw new Exception("Weapon from JSON has no type");
		}

        this.options ~= ItemOption("Equip", delegate(Unit unit) {unit.currentWeapon = this;});
	}

    @trusted override ItemOption[] getOptions(Unit user) { // `@trusted` may be removed if a replacement for `canFind` is found.
        import std.algorithm.searching;
        if (user.currentWeapon is this) return [ItemOption("Equip", delegate(Unit unit) {unit.currentWeapon = this;})];
        else return [ItemOption("Remove", canFind(user.inventory, this) ?
        delegate (Unit unit) {unit.currentWeapon = null;} :
        delegate(Unit unit) {unit.currentWeapon = null; unit.inventory ~= this;}
        )];
    }

    AttackPotential getAttackPotential (Unit attacker, Unit opponent, uint distance=0) {    // Temporary function for attacks
        debug if (attacker is opponent) throw new Exception("`attacker` and `opponent` are the same object");
        
        if (distance==0) distance = measureDistance(attacker, opponent);
        short damage = cast(short) ((attacker.Str * (attacker.Str + this.Atk))/(attacker.Str + opponent.Def));
        ubyte hitChance = cast(ubyte) (250 * (opponent.size + this.crossSection) * attacker.Dex / measureDistance(attacker.getLocation, opponent.getLocation));
        return AttackPotential(damage:damage, hitChance:hitChance);
    }

    //ItemOption[] getAttacks(Unit user); // This will eventually return a list of moves that can be performed.
}

enum WeaponType : ubyte
{
	knife,
    sword,
	spear,
	axe,
	blunt,
	bow,
    gun
}

enum WeaponSubtype : ubyte
{
	dagger,
	backsword,
    longsword,
	rapier,
    hatchet,
	broadaxe,
    poleaxe,
	hammer,
	mace,
	morningStar,
	lance,
	spear,
	bow
}

const WeaponType[WeaponSubtype] subtypeToType = [
    WeaponSubtype.dagger: WeaponType.sword,
    WeaponSubtype.backsword: WeaponType.sword,
    WeaponSubtype.longsword: WeaponType.sword,
    WeaponSubtype.hatchet: WeaponType.axe,
    WeaponSubtype.broadaxe: WeaponType.axe,
    WeaponSubtype.poleaxe: WeaponType.axe,
    WeaponSubtype.hammer: WeaponType.blunt,
    WeaponSubtype.mace: WeaponType.blunt,
    WeaponSubtype.morningStar: WeaponType.blunt,
    WeaponSubtype.lance: WeaponType.spear,
    WeaponSubtype.spear: WeaponType.spear,
    WeaponSubtype.bow: WeaponType.bow,
    ];

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


/*unittest
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

    Vector2i[] blocked = [Vector2i(9,11), Vector2i(7,10), Vector2i(6,10)];

    foreach(int x, row; map.getGrid) foreach(int y, tile; row) {
        Vector2i location = {x, y};
        if (measureDistance(origin, Vector2i(x,y)) <= range && Vector2i(x,y) != origin) {
            if (canFind(blocked, location)) {
                assert(!canShoot(Vector2i(12,12), Vector2i(x,y), map), "Tile "~to!string(x)~", "~to!string(y)~" should be blocked.");
                //assert(!canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should be blocked.");
            }
            else if (x >= 12 || y >= 12 || x >= y) {
                assert(canShoot(Vector2i(12,12), Vector2i(x,y), map), "Tile "~to!string(x)~", "~to!string(y)~" should not be blocked.");
                assert(canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" not found in returned coordinates.");
            }
        } else assert(!canFind(attackable, Vector2i(x,y)), "Tile "~to!string(x)~", "~to!string(y)~" should not be in returned coordinates.");
    }
    writeln("`projectileScan` unittest passed! Yay!");
}*/