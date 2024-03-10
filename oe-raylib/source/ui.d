import raylib;
import std.string: toStringz;
import std.algorithm.comparison;
import std.conv;
import vunit;
import unit;

version (FontSet) const bool FONTSET = true;
else const FONTSET = false;

version (FontSet) {
    class UIElement
    {
        static FontSet fontSet;
        Rectangle outline;

        /*static*/ this() {
            font.serif = LoadFont("../sprites/font/LiberationSerif-Regular.ttf");
            font.serif_bold = LoadFont("../sprites/font/LiberationSerif-Bold.ttf");
            font.serif_italic = LoadFont("../sprites/font/LiberationSerif-Italic.ttf");
            font.serif = LoadFont("../sprites/font/LiberationSans-Regular.ttf");
            font.serif_bold = LoadFont("../sprites/font/LiberationSans-Bold.ttf");
        }

        abstract void draw();
    }

    class FontSet {
        Font serif;
        Font serif_bold;
        Font serif_italic;
        Font sans;
        Font sans_bold;
    }
}

class TextButton /*: UIElement*/
{
    Rectangle outline;
    static Font font;
    Color buttonColour;
    Color fontColour;
    string text;
    float fontSize;
    float lineSpacing = 1.0;
    Vector2 textAnchor;

    this(Vector2 midpoint, string text, Color colour, int fontSize = 15) {
        Vector2 textDimensions = MeasureTextEx(TextButton.font, text.toStringz, cast(float)fontSize, lineSpacing);
        this.textAnchor.x = midpoint.x - textDimensions.x / 2;
        this.textAnchor.y = midpoint.y - textDimensions.y / 2;
        this.outline.width = max(80, textDimensions.x);
        this.outline.height = max(32, textDimensions.y);
        this.outline.x = midpoint.x - outline.width / 2;
        this.outline.y = midpoint.y - outline.height / 2;
        this.text = text;
        TextButton.fontSize = fontSize;
        this.buttonColour = colour;
        TextButton.fontColour = Colors.RAYWHITE;
    }
    
    this(Rectangle outline, Font font, string text, int fontSize, Color buttonColour, bool whiteText) {
        TextButton.font = font;
        this(outline, text, fontSize, buttonColour, whiteText);
    }
    
    this(Rectangle outline, string text, int fontSize, Color buttonColour, bool whiteText) {
        this.outline = outline;
        this.buttonColour = buttonColour;
        this.text = text;
        TextButton.fontSize = to!float(fontSize);
        if (whiteText) TextButton.fontColour = Colors.RAYWHITE;
        else TextButton.fontColour = Colors.BLACK;

        Vector2 textDimensions = MeasureTextEx(TextButton.font, text.toStringz, to!float(fontSize), lineSpacing);
        this.textAnchor.x = outline.x + outline.width/2 - textDimensions.x/2;
        this.textAnchor.y = outline.y + outline.height/2 - textDimensions.y/2;
    }

    version (FontSet) override void draw() {
        DrawRectangleRec(outline, buttonColour);
        DrawTextEx(font.sans_bold, this.text.toStringz, textAnchor, fontSize, lineSpacing, fontColour);
    }
    else void draw() {
        DrawRectangleRec(outline, buttonColour);
        //debug { if (font is null) throw new Exception("TextButton.draw: `font` is null"); }
        DrawTextEx(font, this.text.toStringz, textAnchor, fontSize, lineSpacing, fontColour);
    }

    debug {
        void dump() {
            import std.stdio;
            writeln("Dumping info on TextButton "~to!string(this));
            writeln(font);
            writeln(outline);
            writeln(buttonColour);
            writeln(fontColour);
            writeln(text);
            writeln(fontSize);
            writeln(lineSpacing);
            writeln(textAnchor);
        }
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
    VisibleUnit unit;
    string infotext;

    this (VisibleUnit unit, int screenx, int screeny ) {
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

    bool available() {
        if (unit.currentTile is null) return true;
        else return false;
    }
    
    UnitStats stats() {
        return this.unit.getStats;
    }

    void draw(Texture2D[] sprites) {
        DrawRectangleRec(outline, Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(outline, 1.0f, Colors.BLACK);
        DrawTexture(this.unit.sprite, cast(int)outline.x+4, cast(int)outline.y+2, Colors.WHITE);
        DrawText(this.unit.name.toStringz, x+80, y+4, 14, Colors.BLACK);
        DrawText(this.infotext.toStringz, x+80, y+20, 11, Colors.BLACK);
    }
}

enum Colours {
    SHADOW = Color(r:20, b:20, g:20, a:25),
    CursorHighlight = Color(245, 245, 245, 32),
    Startpoint = Color(250, 250, 60, 35),
    Paper = Color(r:240, b:210, g:234, a:250),
    Crimson = Color(180, 7, 13, 255),
}