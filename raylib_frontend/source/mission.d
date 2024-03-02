import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.json;
import std.algorithm.searching;
import raylib;

import map;
import tile;
import unit;

const Color SHADOW = {r:20, b:20, g:20, a:25};
const int TILESIZE = 64;



/*void Missionfunction(JSONValue missionData)
{
    Map map = new Map(missionData);
    Texture2D[] tileSprites;
    Texture2D[] sprites;
    //int scale = 64;
    Vector2 mousePosition;
    
    writeln("Got to mission.d 14");
    foreach(i, spriteName; map.getTextureIndex()) {
        string spritePath = ("../sprites/" ~ spriteName).buildNormalizedPath;
        if (!endsWith(spritePath, ".png")) spritePath ~= ".png";
        writeln(spritePath);
        tileSprites ~= LoadTexture(spritePath.toStringz);
    }
    missionData.destroy;
    ClearBackground(Colors.BLACK);

    ushort[string] spriteIndex;
    Unit[] myUnits;
    JSONValue myUnitsData = parseJSON(readText("Units.json"));
    foreach (k, unitData; myUnitsData.array) {
        Unit unit = new Unit(map, unitData);
        string spriteName = unitData.object["Sprite"].get!string;
        if (spriteName in spriteIndex) {
            string spritePath = ("../sprites/" ~ spriteName).buildNormalizedPath;
            int spriteID = cast(ushort)sprites.length;
            sprites ~= LoadTexture(spritePath.toStringz);
        }
        unit.spriteID = spriteIndex[unitData.object["Sprite"].to!string];
        myUnits ~= unit;
    }

    while (!WindowShouldClose()) {
        BeginDrawing();
        scope(exit) EndDrawing();
        mousePosition = GetMousePosition;

        ClearBackground(Colors.BLACK);
        foreach (int gridx, tileRow; map.getGrid) {
            foreach (int gridy, tile; tileRow) {
                DrawTexture(tileSprites[tile.textureID], gridx*TILESIZE, gridy*TILESIZE, Colors.RAYWHITE);
                DrawRectangleLines(gridx*TILESIZE, gridy*TILESIZE, TILESIZE, TILESIZE, SHADOW);

                if (tile.occupant !is null) {
                    DrawTexture(sprites[tile.occupant.sprite], gridx*TILESIZE, gridy*TILESIZE, Colors.RAYWHITE);
                }
            }
        }
    }
    CloseWindow();
}*/

class Mission : Map
{
    Texture2D[] sprites;
    Unit[] units;
    Unit[] playerUnits;
    Unit* selectedUnit;

    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(JSONValue mapData) {
        {
            import std.algorithm;

            int[string] spriteIndex;
            writeln("Am here");
            super(mapData["map_name"].get!string);
            
            JSONValue[][] tileData;
            tileData.length = mapData.object["tiles"].array.length;
            this.grid.length = mapData.object["tiles"].array.length;
            writeln("Starting to unload tile data");
            foreach (x, tileRow; mapData.object["tiles"].array) {
                tileData[x] = tileRow.arrayNoRef;
                this.grid[x].length = tileRow.array.length;

                foreach (y, tile; tileRow.arrayNoRef) {
                    string tileName = "";
                    if ("name" in tile) tileName = tile["name"].get!string;
                    bool allowStand = tile["canWalk"].get!bool;
                    bool allowFly = true;// tile["canFly"].get!bool;
                    int stickiness = tile["stickiness"].get!int;
                    string spriteName = tile["tile_sprite"].get!string;
                    ushort spriteID;
                    if (spriteName in spriteIndex) {
                        spriteID = cast(ushort)spriteIndex[spriteName];
                    } else {
                        string spritePath = ("../sprites/" ~ spriteName).buildNormalizedPath;
                        spriteID = cast(ushort)this.sprites.length;
                        Texture2D newSprite = LoadTexture(spritePath.toStringz);
                        this.sprites ~= LoadTexture(spritePath.toStringz);
                        spriteIndex[spriteName] = spriteID;
                    }
                    this.grid[x][y] = new Tile(tileName, allowStand, allowFly, stickiness, spriteID, spriteName);
                    //this.loadJSONTileData(tile);
                    if ("Unit" in tile) this.loadUnitFromJSON(tile["Unit"], spriteIndex);
                }
                write("Finished loading row ");
                writeln(x);
            }
            writeln("Finished loading map " ~ this.name);
            {
                import std.conv;
                writeln("Map is "~to!string(this.grid.length)~" by "~to!string(this.grid.length)~" tiles.");
            }

            JSONValue playerUnitsData = parseJSON(readText("Units.json"));
            writeln("Opened Units.json");
            foreach (k, unitData; playerUnitsData.array) {
                this.playerUnits ~= loadUnitFromJSON(unitData, spriteIndex);
            }

            writeln("Finished loading player units");
        }

        validateRaylibBinding();
	    InitWindow(800, 600, "Open Emblem");
	    SetTargetFPS(60);
        scope(exit) CloseWindow();

        while(!WindowShouldClose())
        {
            BeginDrawing();
            //scope(exit) EndDrawing();
            Vector2 mousePosition = GetMousePosition();
            Vector2 highlightedTile;

            foreach (int gridx, tileRow; this.grid) {
                foreach (int gridy, tile; tileRow) {
                    DrawTexture(this.sprites[tile.textureID], gridx*TILESIZE, gridy*TILESIZE, Colors.RAYWHITE);
                    DrawRectangleLines(gridx*TILESIZE, gridy*TILESIZE, TILESIZE, TILESIZE, SHADOW);

                    if (tile.occupant !is null) {
                        DrawTexture(sprites[tile.occupant.spriteID], gridx*TILESIZE, gridy*TILESIZE, Colors.RAYWHITE);
                    }
                }
            }
            EndDrawing();
        }
        CloseWindow();
    }

    Unit loadUnitFromJSON (JSONValue unitData, ref int[string] spriteIndex) {
        Unit newUnit = new Unit(unitData);
        string spriteName = unitData["Sprite"].get!string;
        if (spriteName in spriteIndex) {
            newUnit.spriteID = spriteIndex[spriteName];
        } else {
            newUnit.spriteID = cast(uint)spriteIndex.length;
            spriteIndex[spriteName] = newUnit.spriteID;
        }
        units ~= newUnit;
        return newUnit;
    }
}