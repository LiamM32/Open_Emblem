module tile;

import unit;

class Tile
{
	public string tileName;
	protected bool allowStand = true;
	protected bool allowFly = true;
	public int stickyness = 0;

	protected short xlocation;
	protected short ylocation;

	public bool startLocation = false;

	public string textureName;
	public ushort textureID;
	
	public Unit occupant;

	this() {}
	
	this(string tileName, bool allowStand, bool allowFly, int stickyness, ushort textureID, string textureName = "") {
		this.tileName = tileName;
		this.allowStand = allowStand;
		this.allowFly = allowFly;
		this.stickyness = stickyness;
		this.textureName = textureName;
	}

	void setOccupant(Unit occupant) {
		this.occupant = occupant;
	}
	
	bool allowUnit(bool isFlyer) {
		if (isFlyer) return this.allowFly;
		else return this.allowStand;
	}

	int x() {
		return cast(int) this.xlocation;
	}
	int y() {
		return cast(int) this.ylocation;
	}
}
