module tile;

import unit;

class Tile
{
	private bool allowStand = true;
	private bool allowFly = true;
	public int stickyness = 0;

	public string textureName;
	public ushort spriteID;
	
	public Unit occupant;

	this() {}
	
	this(bool allowStand, bool allowFly, int stickyness, string textureName = "") {
		this.allowStand = allowStand;
		this.allowFly = allowFly;
		this.stickyness = stickyness;
		this.textureName = textureName;
	}
	
	bool allowUnit(bool isFlyer) {
		if (isFlyer) return this.allowFly;
		else return this.allowStand;
	}
}
