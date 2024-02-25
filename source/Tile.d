module tile;

import unit;

class Tile
{
	private bool allowStand = true;
	private bool allowFly = true;
	public int stickyness = 0;
	
	public Unit occupant;
	
	bool allowUnit(bool isFlyer) {
		if (isFlyer) return this.allowFly;
		else return this.allowStand;
	}
}
