import std.json;
import raylib;
import tile;
import common;
import constants;
import spriteLoader;

class VisibleTile : Tile//T!VisibleTile
{
    Texture2D[2] sprites; // `sprite[0]` is the ground sprite.
    Rectangle rect;

    this(uint x, uint y, JSONValue tileData) {
        string tileName = "";
        if ("name" in tileData) tileName = tileData["name"].get!string;
        this.allowStand = tileData["canWalk"].get!bool;
        if ("canFly" in tileData) this.allowFly = tileData["canFly"].get!bool;
        if ("canShoot" in tileData) this.allowShoot = tileData["canShoot"].get!bool;
        else this.allowShoot = this.allowStand;
        this.stickyness = tileData["stickiness"].get!int;
        this.rect.x = cast(float) x * TILEWIDTH;
        this.rect.y = cast(float) y * TILEHEIGHT;
        this.rect.width = TILEWIDTH;
        this.rect.height = TILEHEIGHT;

        this.sprites[0] = SpriteLoader.current.getSprite(tileData["ground"].get!string);
        if ("obstacle" in tileData) this.sprites[1] = SpriteLoader.current.getSprite(tileData["obstacle"].get!string);

        super(cast(int)x, cast(int)y);
    }

    Vector2 getDestination (Vector2 offset) {
        offset.x += this.origin.x;
        offset.y += this.origin.y;
        return offset;
    }

    Vector2 origin() {
        return Vector2(x:rect.x, y:rect.y);
    }

    Rectangle getRect() {
        return this.rect;
    }

    Rectangle getRect(Vector2 offset) {
        Rectangle rect = this.rect;
        rect.x += offset.x;
        rect.y += offset.y;
        return rect;
    }
}