import std.file;
import std.json;
import std.string:toStringz;
import raylib;

class SpriteLoader
{
    static SpriteLoader currentLoader;
    
    string[string] spritePaths;
    Texture2D[string] spriteIndex;
    
    this() {
        JSONValue spritesJSON = parseJSON(readText("sprites.json"));
        import std.stdio;

        foreach (name, path; spritesJSON.object) {
            writeln(name);
            writeln(path);
            spritePaths[name] = path.get!string;
        }

        if (currentLoader is null) currentLoader = this;
    }

    static SpriteLoader current() {
        if (currentLoader is null) currentLoader = new SpriteLoader;
        return currentLoader;
    }

    Texture2D getSprite(string name) {
        if (name in spriteIndex) return spriteIndex[name];
        else if (name in spritePaths) {
            spriteIndex[name] = LoadTexture(spritePaths[name].toStringz);
        }
        return spriteIndex[name];
    }
}