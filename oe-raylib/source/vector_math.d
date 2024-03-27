import raylib;
import common;

Rectangle offsetRect(Rectangle rect, Vector2 offset) { //Determines where to place a rectangle by adding it's built-in x and y values to an offset.
    rect.x += offset.x;
    rect.y += offset.y;
    return rect;
}

Vector2 gridToPixels (Vector2i input) {
    import constants;
    Vector2 output;
    output.x = cast(float)( input.x * TILEWIDTH );
    output.y = cast(float)( input.y * TILEHEIGHT );
    return output;
}