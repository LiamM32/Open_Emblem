const int TILEWIDTH = 64;
const int TILEHEIGHT = 56;

debug const int WAITTIME = 800;
else const int WAITTIME = 1600;

enum Action:ubyte {Nothing, Move, Attack, Items, EndTurn};

import raylib;
import common;

Vector2 gridToPixels (Vector2i input) {
    Vector2 output;
    output.x = cast(float)( input.x * TILEWIDTH );
    output.y = cast(float)( input.y * TILEHEIGHT );
    return output;
}