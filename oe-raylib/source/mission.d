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

class Mission : Map
{
    Texture2D[] sprites;
    Unit[] playerUnits;
    Unit* selectedUnit;

    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        {
            import std.algorithm;
            import std.conv;

            int[string] spriteIndex;
            super(mapData["map_name"].get!string);

            Unit[] npcUnits;
            JSONValue[][] tilesData;
            tilesData.length = mapData.object["tiles"].array.length;
            this.grid.length = mapData.object["tiles"].array.length;
            writeln("Starting to unload tile data");
            foreach (int x, tileRow; mapData.object["tiles"].array) {
                tilesData[x] = tileRow.arrayNoRef;
                this.grid[x].length = tileRow.array.length;
                //npcUnitsData[x].length = tileRow.length;

                foreach (int y, tile; tileRow.arrayNoRef) {
                    string tileName = "";
                    if ("name" in tile) tileName = tile["name"].get!string;
                    bool allowStand = tile["canWalk"].get!bool;
                    bool allowFly = true;// tile["canFly"].get!bool;
                    int stickiness = tile["stickiness"].get!int;
                    string spriteName = tile["tile_sprite"].get!string;
                    ushort spriteID;
                    spriteID = loadNumberTexture(spriteName, spriteIndex, this.sprites);
                    this.grid[x][y] = new Tile(tileName, allowStand, allowFly, stickiness, spriteID, spriteName);
                    writeln ("Tile "~to!string(x)~", "~to!string(y)~" has been added to the grid.");
                    //this.loadJSONTileData(tile);
                    if ("Unit" in tile) {
                        Unit occupyingUnit = this.loadUnitFromJSON(tile["Unit"], spriteIndex);
                        occupyingUnit.setLocation(x, y);
                    }
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
        this.fullyLoaded = true;
    
        scope(exit) CloseWindow();

        import std.datetime.stopwatch;
        auto missionTimer = StopWatch(AutoStart.yes);
        Texture2D gridMarker = LoadTexture("../sprites/grid-marker.png".toStringz);
        
        Vector2 mousePosition = GetMousePosition();
        Vector2 highlightedTile;

        bool oscDirection = false;
        ubyte markerOpacity;

        while(!WindowShouldClose())
        {
            import std.math.trigonometry : sin;
            BeginDrawing();
            //scope(exit) EndDrawing();
            mousePosition = GetMousePosition();

            if (oscDirection) {
                markerOpacity += 2;
                if (markerOpacity == 128) oscDirection = false;
            } else {
                markerOpacity -= 2;
                if (markerOpacity == 32) oscDirection = true;
            }

            foreach (int gridx, tileRow; this.grid) {
                foreach (int gridy, tile; tileRow) {
                    DrawTexture(this.sprites[tile.textureID], gridx*TILESIZE, gridy*TILESIZE, Colors.WHITE);
                    //DrawRectangleLines(gridx*TILESIZE, gridy*TILESIZE, TILESIZE, TILESIZE, SHADOW);
                    DrawTextureEx(gridMarker, Vector2(gridx*TILESIZE, gridy*TILESIZE), 0.0, 1.0, Color(10,10,10, markerOpacity));
                }
            }
            foreach (int gridx, tileRow; this.grid) {
                foreach (int gridy, tile; tileRow) {
                        if (tile.occupant !is null) {
                        DrawTexture(this.sprites[tile.occupant.spriteID], gridx*TILESIZE, gridy*TILESIZE-24, Colors.WHITE);
                    }
                }
            }
            EndDrawing();
        }
        CloseWindow();
    }

    Unit loadUnitFromJSON (JSONValue unitData, ref int[string] spriteIndex) {
        Unit newUnit = new Unit(this, unitData);
        string spriteName = unitData["Sprite"].get!string;
        if (spriteName in spriteIndex) {
            newUnit.spriteID = spriteIndex[spriteName];
        } else {
            newUnit.spriteID = cast(uint)this.sprites.length;
            spriteIndex[spriteName] = newUnit.spriteID;
            string spritePath = ("../sprites/units/" ~ spriteName).buildNormalizedPath;
            if (!spritePath.endsWith(".png")) spritePath ~= ".png";
            this.sprites ~= LoadTexture(spritePath.toStringz);
        }
        //allUnits ~= newUnit; Removed because this was added to Unit.this
        return newUnit;
    }
}

ushort loadNumberTexture (string spriteName, ref int[string] spriteIndex, ref Texture2D[] sprites) {
    ushort spriteID;
    if (spriteName in spriteIndex) {
        spriteID = cast(ushort)spriteIndex[spriteName];
    } else {
        string spritePath = ("../sprites/tiles/" ~ spriteName).buildNormalizedPath;
        spriteID = cast(ushort)sprites.length;
        sprites ~= LoadTexture(spritePath.toStringz);
        spriteIndex[spriteName] = spriteID;
    }
    return spriteID;
}