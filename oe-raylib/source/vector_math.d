import raylib;
import common;

Vector2 rectDest(Rectangle rect, Vector2 offset, bool otherCorner = false) { //Determines where to place a rectangle by adding it's built-in x and y values to an offset.
    Vector2 location = offset;
    location.x += rect.x;
    location.y += rect.y;
    if (otherCorner) {
        location.x += rect.width;
        location.y += rect.height;
    }
    return location;
}