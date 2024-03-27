debug import std.stdio;
import raylib;
version (raygui) import raygui;
import std.string: toStringz;
import std.algorithm.comparison;
import std.conv;
import vunit;
import unit;
import common;
import vector_math;

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

class UIStyle
{
    static UIStyle defaultStyle;
    
    Color baseColour;
    Color textColour;
    Color hoverColour;
    Color outlineColour;
    float outlineThickness;
    float padding = 0.0f;
    float lineSpacing = 1.0f;
    FontSet fontSet;

    this(Color baseColour, Color textColour, Color outlineColour, float outlineThickness, FontSet fontSet) {
        this.baseColour = baseColour;
        this.textColour = textColour;
        this.outlineColour = outlineColour;
        this.outlineThickness = outlineThickness;
        this.fontSet = FontSet.getDefault;
    }

    static UIStyle getDefault() {
        if (defaultStyle is null) defaultStyle = new UIStyle(Colours.Paper, Colors.BLACK, Colors.BROWN, 1.0f, FontSet.getDefault);
        return defaultStyle;
    }
}

interface UIElement {
    //void setStyle();
    bool draw(); // Returns whether the mouse is hovering.
    bool draw(Vector2 offset);
}

enum FontStyle { serif, serif_bold, serif_italic, sans, sans_bold, }

class Panel : UIElement
{
    Vector2 origin;
    UIElement[] children;

    bool draw() {
        bool hover;
        foreach (childElement; children) {
            if (childElement.draw) hover = true;;
        }
        return hover;
    }

    bool draw(Vector2 offset) {
        bool hover;
        foreach (childElement; children) {
            if (childElement.draw(offset)) hover = true;
        }
        return hover;
    }
}

class TextButton : UIElement
{
    Rectangle outline;
    UIStyle style;
    Font font;
    string text;
    float fontSize;
    Vector2 textAnchor;
    void delegate() onClick;

    version(FontSet) {
        static this() {
            font = FontSet.getDefault.sans_bold;
        }
    }

    this(Rectangle outline, UIStyle style, string text, int fontSize, void delegate() action) {
        this.outline = outline;
        this.text = text;
        this.style = style;
        this.fontSize = fontSize;
        this.onClick = action;
        this.font = style.fontSet.sans_bold;

        Vector2 textDimensions = MeasureTextEx(font, text.toStringz, fontSize, style.lineSpacing);
        this.textAnchor.x = outline.x + (outline.width - textDimensions.x) / 2; // + (textDimensions / 2); // After merging of my version of raylib-d, change to `textAnchor = outline.origin + (outline.dimensions - textDimensions) / 2;`.
        this.textAnchor.y = outline.y + (outline.height - textDimensions.y) / 2;
    }

    bool draw() {return draw(Vector2(0,0));}
    
    bool draw(Vector2 offset = Vector2(0,0)) {
        bool hover;
        DrawRectangleRec(offsetRect(outline, offset), style.baseColour);
        DrawTextEx(font, this.text.toStringz, textAnchor+offset, fontSize, style.lineSpacing, style.textColour);
        if(CheckCollisionPointRec(GetMousePosition(), outline)) {
            hover = true;
            DrawRectangleRec(outline, Colours.Highlight);
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
        }
        DrawRectangleLinesEx(outline, style.outlineThickness, style.outlineColour);
        return hover;
    }
}

class UnitInfoCard// : UIElement
{
    Rectangle outline;
    Rectangle imageFrame;
    Font font;
    VisibleUnit unit;
    string infotext;
    
    this (VisibleUnit unit, Vector2 position ) {
        this.outline = Rectangle(position.x, position.y, 192, 80);
        this.imageFrame = Rectangle(position.x+4, position.y+4, 64, 64);
        this.unit = unit;

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

    bool draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return false;
        DrawRectangleRec(offsetRect(outline, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(outline, offset), 1.0f, Colors.BLACK);
        DrawTextureV(unit.sprite, Vector2(outline.x,outline.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(outline.x,outline.y)` to `outline.origin` if my addition to Raylib-D gets merged.
        //DrawText(this.unit.name.toStringz, x+80, y+4, 14, Colors.BLACK);
        DrawTextEx(font, unit.name.toStringz, Vector2(outline.x+80, outline.y+4), 17.0f, 1.0f, Colors.BLACK);
        //DrawText(this.infotext.toStringz, x+80, y+20, 11, Colors.BLACK);
        DrawTextEx(font, infotext.toStringz, Vector2(outline.x+80, outline.y+20), 12.5f, 1.0f, Colors.BLACK);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        return true;
    }
}

class MenuList (ArrayType)
{
    Rectangle[] rects;
    string[] optionNames;
    version (raygui) string optionString;
    Vector2 origin;

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