module oe.tile;

import oe.unit;
import oe.common;

class Tile
{
	public string tileName;
	protected bool allowStand = true;
	protected bool allowFly = true;
	bool allowShoot = true;
	public int stickyness = 0;

	protected short xlocation;
	protected short ylocation;

	public bool startLocation = false;

	public string textureName;
	public ushort textureID;
	
	public Unit occupant;

	this(int x, int y) {
		this.xlocation = cast(short)x;
		this.ylocation = cast(short)y;
	}
	
	this(int x, int y, string tileName, bool allowStand, bool allowFly, int stickyness, ushort textureID, string textureName = "") {
		this.xlocation = cast(short)x;
		this.ylocation = cast(short)y;
		this.tileName = tileName;
		this.allowStand = allowStand;
		this.allowFly = allowFly;
		this.stickyness = stickyness;
		this.textureName = textureName;
	}

	this(int x, int y, bool allowStand=true, bool allowFly=true, bool allowShoot=true, int stickyness=0) {
		this.xlocation = cast(short)x;
		this.ylocation = cast(short)y;
		this.allowStand = allowStand;
		this.allowFly = allowFly;
		this.allowShoot = allowShoot;
		this.stickyness = stickyness;
	}

	void setOccupant(Unit occupant) {
		this.occupant = occupant;
	}
	
	bool allowUnit(bool isFlyer) {
		if (this.occupant !is null) return false;
		else if (isFlyer) return this.allowFly;
		else return this.allowStand;
	}

	Vector2i location() {
		return Vector2i(cast(int)xlocation, cast(int)ylocation);
	}

	int x() {
		return cast(int) this.xlocation;
	}
	int y() {
		return cast(int) this.ylocation;
	}
}
