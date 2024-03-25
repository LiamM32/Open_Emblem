debug import std.stdio;

import std.json;
import raylib;
import constants;
import unit;
import spriteSet;
import mission;
import tile;
import common;
import faction;

class VisibleUnit : Unit
{
    //UnitSpriteSet spriteSet;
    Texture2D sprite;
    Vector2 position;
    ActionStep[] queue;

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

        if (this.faction is null) this.faction = faction;
    }

    bool acting() {
        return this.queue.length > 0;
    }

    bool act() {
        if (queue.length == 0) return false;
        bool done;
        switch (queue[0].action) {
            case Action.Move:
                stepTowards(queue[0].tile);
                if (position == gridToPixels(queue[0].tile.location)) done = true;
                break;
            case Action.Attack:
                super.attack(queue[0].tile.x, queue[0].tile.y);
                done = true;
                break;
            default: break;
        }
        if (done) {
            debug writeln("Got here.");
            for (int i=0; i<queue.length-1; i++) {
                queue[i] = queue[i+1];
            }
            queue.length--;
        }
        import std.math;
        if (abs(position.x-xlocation*TILEWIDTH)+abs(position.y-ylocation*TILEHEIGHT) == 0) {
            writeln(this.name~" diff ", (position.x-xlocation*TILEWIDTH), ", ", (position.y-ylocation*TILEHEIGHT));
        }
        return true;
    }

    override void turnReset() {
        super.turnReset();
        position.x = this.xlocation*TILEWIDTH;
        position.y = this.ylocation*TILEHEIGHT;
    }

    override bool move(int x, int y) {
        import core.thread.osthread;
        
        if (this.tileReach[x][y].reachable) {
            Tile[] path = getPath(Vector2i(x,y));
            debug writeln("Path length is ", path.length);
            foreach(tile; path) {
                debug assert(tile !is null);
                this.queue ~= ActionStep(action:Action.Move, tile:tile);
            }
            super.move(x, y);
            return true;
        } else return false;
    }

    override bool attack(uint x, uint y) {
        if (canAttack(x, y)) {
            queue ~= ActionStep(action:Action.Attack, tile:map.getTile(x,y));
            return true;
        } else return false;
    }

    void followPath (TileAccess[] path) {
        Vector2 destination = gridToPixels(path[$-1].tile.location);
        while (this.position != destination) {
            stepTowards(path[$-1].tile);
        }
    }

    void stepTowards (Tile tile) { stepTowards(tile.x, tile.y);}
    
    void stepTowards() {
        stepTowards(this.xlocation, this.ylocation);
    }
    
    float stepTowards (int x, int y, bool trig=false) {
        import std.algorithm.comparison;
        import std.math.algebraic;
        
        Vector2 initial = this.position;
        float stepDistance = GetFrameTime;
        //debug writeln(stepDistance);
        if (this.tileReach[x][y].directionTo.diagonal) stepDistance /= 1.41421356237f;
        if (x*TILEWIDTH > position.x) this.position.x = min(position.x+stepDistance*TILEWIDTH, cast(float)(x*TILEWIDTH));
        else if (x*TILEWIDTH < position.x) this.position.x = max(position.x-stepDistance*TILEWIDTH, cast(float)(x*TILEWIDTH));
        if (y*TILEHEIGHT > position.y) position.y = min(position.y+stepDistance*TILEHEIGHT, cast(float)(y*TILEHEIGHT));
        else if (y*TILEHEIGHT < position.y) this.position.y = max(position.y-stepDistance*TILEHEIGHT, cast(float)(y*TILEHEIGHT));
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

    struct ActionStep {
        Action action;
        Tile tile;
    }
}