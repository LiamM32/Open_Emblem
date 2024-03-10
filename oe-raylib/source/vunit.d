import std.json;
import raylib;
import unit;
import spriteSet;
import mission;

class VisibleUnit : Unit
{
    //UnitSpriteSet spriteSet;
    Texture2D sprite;

    this(Mission map, JSONValue unitData) {
        import std.string:toStringz;
        import std.path : buildNormalizedPath;
        import std.algorithm.searching;
        import std.stdio;

        super(map, unitData);
        string spritePath = ("../sprites/units/" ~ unitData["Sprite"].get!string); //.buildNormalizedPath;
        if (!spritePath.endsWith(".png")) spritePath ~= ".png";
        writeln("Sprite for unit "~this.name~" is "~spritePath);
        this.sprite = LoadTexture(spritePath.toStringz);
    }

    void verify() {
        assert(this.currentTile !is null, "Unit "~name~"'s `currentTile` property is not set.");
        assert(this.currentTile.occupant == this, "Unit "~name~" has it's `currentTile` property set to a Tile object, but that Tile object does not have "~name~" in it's `occupant` property.");
        assert(this.xlocation == this.currentTile.x, "Unit "~name~"'s `xlocation` property is not the same as it's tile's.");
        assert(this.ylocation == this.currentTile.y, "Unit "~name~"'s `ylocation` property is not the same as it's tile's.");
    }
}