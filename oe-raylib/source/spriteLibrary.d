import std.conv;
import std.string : toStringz;
import raylib;
import unit;

class UnitSpriteLibrary
{
    Image[8][4] attack_spear;
    Image[8][4] attack_bow;
    Image[6][4] attack_knife;
    Texture2D[][4] attack;
    Texture2D[9][4] walk;
    Texture2D[6] fall;
    Texture2D[7][4] stretch;

    this (string spriteSheetPath) {
        Image spriteSheet = LoadImage (spriteSheetPath.toStringz);
        Rectangle cutter = Rectangle(0, 0, 64, 64);
        for (int d=0; d<4; d++) {
            for (int i=0; i<7; ++i) {
                Image sprite = ImageCopy(spriteSheet);
                ImageCrop(&sprite, cutter);
                this.stretch[d][i] = LoadTextureFromImage(sprite);
                cutter.x += 64;
            }
            cutter.y += 64;
        }
    }

    void drawFrame (Unit* unit, Vector2 destination, float timer, Action action) {
        int direction = unit.direction / 2;
        int frameNum;
        switch (action) {
            case Action.stretch:
                frameNum = cast(int)timer % 7;
                DrawTextureV(this.stretch[direction][frameNum], destination, Colors.WHITE);
                break;
            case Action.walk:
                frameNum = cast(int)timer % 9;
                DrawTextureV(this.walk[direction][frameNum], destination, Colors.WHITE);
                break;
            case Action.attack:
                frameNum = cast(int)timer % 8;
                DrawTextureV(this.attack[direction][frameNum], destination, Colors.WHITE);
                break;
            case Action.fall:
                frameNum = cast(int)timer % 6;
                DrawTextureV(this.fall[frameNum], destination, Colors.WHITE);
                break;
            default: break;
        }
    }
}

enum Action : ubyte
{
    wait,
    stretch,
    walk,
    attack,
    fall,
}

unittest
{
    UnitSpriteLibrary spriteLibrary = new UnitSpriteLibrary("../sprites/units/male_crimson-leather.png");
}