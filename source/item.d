import std.json;

class Item
{
	string name;
	ushort volume;
}

class Weapon : Item
{
	bool projectile;
	ushort range;
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