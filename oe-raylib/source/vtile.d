import std.json;
import raylib;
import tile;
import common;
import constants;

class VisibleTile : Tile//T!VisibleTile
{
    Texture2D* sprite;
    Rectangle rect;
    Vector2i origin;

    this(JSONValue tileData, ref Texture*[string] spriteIndex, uint x, uint y) {
        string tileName = "";
        if ("name" in tileData) tileName = tileData["name"].get!string;
        this.allowStand = tileData["canWalk"].get!bool;
        if ("canFly" in tileData) this.allowFly = tileData["canFly"].get!bool;
        if ("canShoot" in tileData) this.allowShoot = tileData["canShoot"].get!bool;
        else this.allowShoot = this.allowStand;
        this.stickyness = tileData["stickiness"].get!int;
        this.textureName = tileData["tile_sprite"].get!string;
        this.origin = Vector2i(x*TILEWIDTH, y*TILEHEIGHT);
        this.rect.x = cast(float) x * TILEWIDTH;
        this.rect.y = cast(float) y * TILEHEIGHT;
        this.rect.width = TILEWIDTH;
        this.rect.height = TILEHEIGHT;

        super(cast(int)x, cast(int)y);
    }

    Vector2 getDestination (Vector2 offset) {
        offset.x += this.origin.x;
        offset.y += this.origin.y;
        return offset;
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