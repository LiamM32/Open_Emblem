module tile;

import unit;

class Tile
{
	public string tileName;
	private bool allowStand = true;
	private bool allowFly = true;
	public int stickyness = 0;

	public string textureName;
	public ushort textureID;
	
	public Unit occupant;

	this() {}
	
	this(string tileName, bool allowStand, bool allowFly, int stickyness, ushort textureID, string textureName = "") {
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
