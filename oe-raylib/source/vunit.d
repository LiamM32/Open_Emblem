import std.json;
import raylib;
import constants;
import unit;
import spriteSet;
import mission;
import tile;
import common;
import map: Faction;

class VisibleUnit : Unit
{
    //UnitSpriteSet spriteSet;
    Texture2D sprite;
    Vector2 position;
    TileAccess[] path;

    this(Mission map, JSONValue unitData, Faction faction = null) {
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

    override void turnReset() {
        super.turnReset();
        position.x = this.xlocation*TILEWIDTH;
        position.y = this.ylocation*TILEHEIGHT;
    }

    override bool move(int x, int y) {
        import core.thread.osthread;
        
        if (this.distances[x][y].reachable) {
            TileAccess[] path = getPath(Vector2i(x,y));
            super.move(x, y);
            return true;
        } else return false;
        position.x = this.xlocation*TILEWIDTH;
        position.y = this.ylocation*TILEHEIGHT;
    }

    void followPath(int x, int y) {
        import std.stdio;
        writeln("Doing followPath");
        TileAccess[] path = getPath(x, y);
        writeln(path);

        foreach(tileAccess; path) {
            Tile tile = tileAccess.tile;
            float move = 0.0f;
            while (move < 1.0f) {
                move += stepTowards(tile.x, tile.y, false);
                WaitTime(GetFrameTime);
                BeginDrawing();
                (cast(Mission)map).drawTiles;
                (cast(Mission)map).drawUnits;
                EndDrawing();
                import std.conv;
                writeln(this.name~" followed path to tile "~to!string(tile.x)~", "~to!string(tile.y));
            }
        }
        writeln("Finished followPath");
    }

    void stepTowards (Tile tile) { stepTowards(tile.x, tile.y);}
    
    void stepTowards() {
        stepTowards(this.xlocation, this.ylocation);
    }
    
    float stepTowards (int x, int y, bool trig=false) {
        import std.algorithm.comparison;
        import std.math.algebraic;
        
        Vector2 initial = this.position;
        float stepDistance = GetFrameTime / 1000;
        if (this.distances[x][y].directionTo.to!int%2) stepDistance /= 1.41421356237;
        if (x*TILEWIDTH > position.x) this.position.x += 1.0f;// = min(position.x+stepDistance, cast(float)(x*TILEWIDTH));
        else if (x*TILEWIDTH < position.x) this.position.x -= 1.0f; // = max(position.x-stepDistance, cast(float)(x*TILEWIDTH));
        if (y*TILEHEIGHT > position.y) position.y += 1.0f;// = min(position.y+stepDistance, cast(float)(y*TILEHEIGHT));
        else if (y*TILEHEIGHT < position.y) this.position.y -= 1.0f;// = max(position.y-stepDistance, cast(float)(y*TILEHEIGHT));
        Vector2 step = position - initial;
        return abs(max(position.x/TILEWIDTH, position.y/TILEHEIGHT));
    }

    debug {
        void verify() {
            assert(this.currentTile !is null, "Unit "~name~"'s `currentTile` property is not set.");
            assert(this.currentTile.occupant == this, "Unit "~name~" has it's `currentTile` property set to a Tile object, but that Tile object does not have "~name~" in it's `occupant` property.");
            assert(this.xlocation == this.currentTile.x, "Unit "~name~"'s `xlocation` property is not the same as it's tile's.");
            assert(this.ylocation == this.currentTile.y, "Unit "~name~"'s `ylocation` property is not the same as it's tile's.");
        }
    }
}