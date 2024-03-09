import raylib;
import std.string: toStringz;
import std.conv;
import unit;

class TextButton
{
    static Font* font;
    Rectangle outline;
    Color buttonColour;
    Color fontColour;
    string text;
    float fontSize;
    float lineSpacing = 1.0;
    Vector2 textAnchor;
    

    this(Rectangle outline, Font font, string text, int fontSize, Color buttonColour, bool whiteText) {
        this.font = &font;
        this(outline, text, fontSize, buttonColour, whiteText);
    }
    
    this(Rectangle outline, string text, int fontSize, Color buttonColour, bool whiteText) {
        this.outline = outline;
        this.buttonColour = buttonColour;
        this.text = text;
        this.fontSize = to!float(fontSize);
        if (whiteText) this.fontColour = Colors.RAYWHITE;
        else this.fontColour = Colors.BLACK;

        Vector2 textDimensions = MeasureTextEx(*this.font, text.toStringz, to!float(fontSize), lineSpacing);
        this.textAnchor.x = outline.x + outline.width/2 - textDimensions.x/2;
        this.textAnchor.y = outline.y + outline.height/2 - textDimensions.y/2;
    }

    void draw() {
        DrawRectangleRec(outline, buttonColour);
        DrawTextEx(*font, text.toStringz, textAnchor, fontSize, lineSpacing, fontColour);
    }
}

class UnitInfoCard
{
    Rectangle outline;
    Rectangle imageFrame;
    int x;
    int y;
    int width;
    int height;
    Unit unit;
    bool available = true;
    string infotext;

    this (Unit unit, int screenx, int screeny ) {
        this.outline = Rectangle(screenx, screeny, 192, 80);
        this.imageFrame = Rectangle(screenx+4, screeny+4, 64, 64);
        this.unit = unit;
        this.x = screenx;
        this.y = screeny;
        this.width = 256;
        this.height = 72;

        UnitStats stats = unit.getStats;
        this.infotext ~= "Mv: "~to!string(stats.Mv)~"\n";
        this.infotext ~= "MHP: "~to!string(stats.MHP)~"\n";
        this.infotext ~= "Str: "~to!string(stats.Str)~"\n";
        this.infotext ~= "Def: "~to!string(stats.Def)~"\n";
    }
    ~this() {
        if (available) destroy(this.unit);
    }

    UnitStats stats() {
        return this.unit.getStats;
    }

    void draw(Texture2D[] sprites) {
        DrawRectangleRec(outline, Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(outline, 1.0f, Colors.BLACK);
        DrawTexture(sprites[this.unit.spriteID], cast(int)outline.x+4, cast(int)outline.y+2, Colors.WHITE);
        DrawText(this.unit.name.toStringz, x+80, y+4, 14, Colors.BLACK);
        DrawText(this.infotext.toStringz, x+80, y+20, 11, Colors.BLACK);
    }
}

enum Colours {
    SHADOW = Color(r:20, b:20, g:20, a:25),
    PAPER = Color(r:240, b:210, g:234, a:250),
    SHINE = Color(250, 250, 60, 35),
    CRIMSON = Color(210, 10, 15, 255),
}