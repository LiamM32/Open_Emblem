import raylib;
version (raygui) import raygui;
import std.string: toStringz;
import std.algorithm.comparison;
import std.conv;
import vunit;
import unit;
import common;

class FontSet {
    private static FontSet defaultSet;
    
    Font[5] fonts;

    Font serif() { return fonts[0]; }
    Font serif_bold() { return fonts[1]; }
    Font serif_italic() { return fonts[2]; }
    Font sans() { return fonts[3]; }
    Font sans_bold() { return fonts[4]; }

    this() {
        fonts[FontStyle.serif] = LoadFont("../sprites/font/LiberationSerif-Regular.ttf");
        fonts[FontStyle.serif_bold] = LoadFont("../sprites/font/LiberationSerif-Bold.ttf");
        fonts[FontStyle.serif_italic] = LoadFont("../sprites/font/LiberationSerif-Italic.ttf");
        fonts[FontStyle.sans] = LoadFont("../sprites/font/LiberationSans-Regular.ttf");
        fonts[FontStyle.sans_bold] = LoadFont("../sprites/font/LiberationSans-Bold.ttf");
        foreach (ref fontStyle; this.fonts) {
            GenTextureMipmaps(&fontStyle.texture);
            SetTextureFilter(fontStyle.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        }
    }

    static FontSet getDefault() {
        if (defaultSet is null) defaultSet = new FontSet();
        return defaultSet;
    }
}

enum FontStyle { serif, serif_bold, serif_italic, sans, sans_bold, }

class TextButton
{
    Rectangle outline;
    Font font;
    Texture renderedText;
    Color buttonColour;
    Color fontColour;
    string text;
    float fontSize;
    float lineSpacing = 1.0;
    Vector2 textAnchor;

    version(FontSet) {
        static this() {
            font = FontSet.getDefault.sans_bold;
        }
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
        this.font = FontSet.getDefault.sans_bold;
        GenTextureMipmaps(&font.texture);

        Vector2 textDimensions = MeasureTextEx(TextButton.font, text.toStringz, to!float(fontSize), lineSpacing);
        this.textAnchor.x = outline.x + outline.width/2 - textDimensions.x/2;
        this.textAnchor.y = outline.y + outline.height/2 - textDimensions.y/2;
    }

    void draw() {
        DrawRectangleRec(outline, buttonColour);
        DrawTextEx(font, this.text.toStringz, textAnchor, fontSize, lineSpacing, fontColour);
        if(CheckCollisionPointRec(GetMousePosition(), outline)) DrawRectangleRec(outline, Colours.Highlight);
        DrawRectangleLinesEx(outline, 1.0f, fontColour);
    }

    bool button(ref bool hover) {
        DrawRectangleRec(outline, buttonColour);
        DrawTextEx(font, this.text.toStringz, textAnchor, fontSize, lineSpacing, fontColour);
        if(CheckCollisionPointRec(GetMousePosition(), outline)) {
            DrawRectangleRec(outline, Colours.Highlight);
            hover = true;
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) return true;
        }
        DrawRectangleLinesEx(outline, 1.0f, fontColour);
        return false;
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
    Font font;
    int x;
    int y;
    int width;
    int height;
    VisibleUnit unit;
    string infotext;

    /*static this() {
        font = FontSet.getDefault.serif;
    }*/
    
    this (VisibleUnit unit, int screenx, int screeny ) {
        this.outline = Rectangle(screenx, screeny, 192, 80);
        this.imageFrame = Rectangle(screenx+4, screeny+4, 64, 64);
        this.unit = unit;
        this.x = screenx;
        this.y = screeny;
        this.width = 256;
        this.height = 72;

        this.font = FontSet.getDefault.serif;
        GenTextureMipmaps(&font.texture);

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

    bool draw(Texture[] sprites) {
        if (unit.currentTile !is null) return false;
        DrawRectangleRec(outline, Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(outline, 1.0f, Colors.BLACK);
        DrawTexture(unit.sprite, cast(int)outline.x+4, cast(int)outline.y+2, Colors.WHITE);
        //DrawText(this.unit.name.toStringz, x+80, y+4, 14, Colors.BLACK);
        DrawTextEx(font, unit.name.toStringz, Vector2(x+80, y+4), 17.0f, 1.0f, Colors.BLACK);
        //DrawText(this.infotext.toStringz, x+80, y+20, 11, Colors.BLACK);
        DrawTextEx(font, infotext.toStringz, Vector2(x+80, y+20), 12.5f, 1.0f, Colors.BLACK);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        return true;
    }
}

class MenuList (ArrayType)
{
    Rectangle[] rects;
    string[] optionNames;
    version (raygui) string optionString;
    Vector2i origin;

    this(int x, int y) {
        this.origin.x = x;
        this.origin.y = y;
    }

    this(int x, int y, ArrayType[] array) {
        this.origin.x = x;
        this.origin.y = y;
        reset(array);
    }

    void reset(ArrayType[] array) {
        import std.stdio;
        if (array[0] is null) writeln("Array is empty"); return;
        rects.length = array.length;
        optionNames.length = array.length;
        version (raygui) optionString = "";
        foreach (i, object; array) {
            version (customgui) optionNames[i] = object.name;
            version (raygui) optionString ~= ";"~object.name;
            rects[i] = Rectangle(x:origin.x, y:origin.y+i*24, width:96, height:24);
        }
    }

    bool draw(ref ubyte selected) {
        foreach (i, optionRect; rects) {
            version (customgui) {
                DrawRectangleRec(optionRect, Colours.Paper);
                if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(GetMousePosition, optionRect)) {
                    selected = cast(ubyte) i;
                    return true;
                }
            }
            version (raygui) if (GuiButton(optionRect, optionNames[i].toStringz)) {
                selected = cast(ubyte) i;
                return true;
            }
        }
        return false;
    }
}

enum Colours {
    Shadow = Color(r:0, b:0, g:0, a:150),
    Highlight = Color(245, 245, 245, 32),
    Startpoint = Color(250, 250, 60, 35),
    Paper = Color(r:240, b:210, g:234, a:250),
    Crimson = Color(160, 7, 16, 255),
}