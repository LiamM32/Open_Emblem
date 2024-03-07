import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm.searching;
import raylib;

import map;
import tile;
import unit;
import vector_math;

const int TILESIZE = 64;
const Color OPAQUEWHITE = Colors.WHITE;

class Mission : Map
{
    Texture2D[] sprites;
    int[string] spriteIndex;
    Unit[] playerUnits;
    Unit* selectedUnit;
    bool isPlayerTurn;
    Rectangle[][] gridRects;
    GridTile[][] squareGrid;
    Vector2 offset;
    Rectangle mapView;
    Vector2i mapSizePx;

    this() {
        JSONValue missionData = parseJSON(readText("../maps/test-map.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        GridTile[] startingPoints;
        this.offset = Vector2(0.0f, 0.0f);
        {
            import std.algorithm;
            import std.conv;

            super(mapData["map_name"].get!string);

            this.grid.length = mapData.object["tiles"].array.length;
            this.squareGrid.length = mapData.object["tiles"].array.length;
            writeln("Starting to unload tile data");
            foreach (int x, tileRow; mapData.object["tiles"].array) {
                foreach (int y, tileData; tileRow.arrayNoRef) {
                    string tileName = "";
                    if ("name" in tileData) tileName = tileData["name"].get!string;
                    bool allowStand = tileData["canWalk"].get!bool;
                    bool allowFly = true;// tile["canFly"].get!bool;
                    int stickiness = tileData["stickiness"].get!int;
                    string spriteName = tileData["tile_sprite"].get!string;
                    ushort spriteID;
                    spriteID = loadNumberTexture(spriteName, spriteIndex, this.sprites);
                    Tile tile =  new Tile(tileName, allowStand, allowFly, stickiness, spriteID, spriteName);
                    GridTile gridTile = new GridTile(tile, x, y);
                    this.grid[x] ~= tile;
                    this.squareGrid[x] ~= gridTile;
                    assert(this.grid[x][y] == this.squareGrid[x][y].tile);
                    if ("Unit" in tileData) {
                        Unit occupyingUnit = this.loadUnitFromJSON(tileData["Unit"], spriteIndex);
                        occupyingUnit.setLocation(x, y);
                    } else if ("Player Unit" in tileData) {
                        this.grid[x][y].startLocation = true;
                        startingPoints ~= gridTile;
                    }
                }
                write("Finished loading row ");
                writeln(x);
            }
            this.mapSizePx.x = cast(int)this.squareGrid.length * TILESIZE;
            this.mapSizePx.y = cast(int)this.squareGrid[0].length * TILESIZE;
            writeln("Finished loading map " ~ this.name);
            {
                import std.conv;
                writeln("Map is "~to!string(this.grid.length)~" by "~to!string(this.grid.length)~" tiles.");
            }
        }
        this.fullyLoaded = true;
        
        {
            Rectangle unitSelectionBox = {x:0, y:GetScreenHeight()-96, width:GetScreenWidth(), height:96};
            Unit[] availableUnits;
            UnitCard[Unit*] unitCards;
            
            JSONValue playerUnitsData = parseJSON(readText("Units.json"));
            writeln("Opened Units.json");
            foreach (int k, unitData; playerUnitsData.array) {
                Unit unit = loadUnitFromJSON(unitData, spriteIndex, false);
                availableUnits ~= unit;
                unitCards[&unit] = new UnitCard(unit, k*258, GetScreenHeight()-72);
            }
            writeln("There are "~to!string(unitCards.length)~" units available.");
            
            scope(exit) CloseWindow();
            
            Vector2 mousePosition = GetMousePosition();
            const Vector2 dragOffset = {x: -TILESIZE/2, y: -TILESIZE*0.75 };
            this.offset = Vector2(0.0, -96.0);
            this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);

            while(!WindowShouldClose()) {
                BeginDrawing();
                this.offsetMap(mapView);
                drawTiles();
                drawUnits();
                foreach(startTile; startingPoints) {
                    DrawRectangleRec(startTile.getRect, Color(250, 250, 60, 30));
                    if (startTile.occupant !is null) {
                        Vector2 destination = vect2sum(startTile.getOriginSS, Vector2(0, -24));
                        DrawTextureV(this.sprites[startTile.occupant.spriteID], destination, Colors.WHITE);
                    }
                }

                DrawRectangleRec(unitSelectionBox, Colours.PAPER);
                foreach (card; unitCards) if (card.available) {
                    card.draw();
                }

                if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
                    DrawRectangleRec(mapView, Colours.SHINE);
                }

                mousePosition = GetMousePosition();
                if (this.selectedUnit is null) {
                    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                        foreach (card; unitCards) if (CheckCollisionPointRec(mousePosition, card.outerRect)) {
                            this.selectedUnit = &card.unit;
                            card.available = false;
                        }
                    }
                } else {
                    DrawTextureV(this.sprites[this.selectedUnit.spriteID], vect2sum(mousePosition, dragOffset), Colors.WHITE);
                    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                        bool drop = true;
                        foreach (gridTile; startingPoints) if (CheckCollisionPointRec(mousePosition, gridTile.getRect)) {
                            if (gridTile.occupant !is null) {
                                gridTile.tile.occupant = this.selectedUnit;
                                drop = false;
                                break;
                            }
                        }
                        /*if (drop) {
                            unitCards[selectedUnit].available = true;
                        }
                        this.selectedUnit = null;*/
                    }
                } 

                EndDrawing();
            }
        }

        playerTurn();
    }

    void playerTurn() {
        this.isPlayerTurn = true;
        this.turnReset();

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

            drawTiles();
            foreach (int gridx, row; this.squareGrid) {
                foreach (int gridy, gridTile; row) {
                    //DrawTexture(this.sprites[tile.textureID], gridx*TILESIZE, gridy*TILESIZE, Colors.WHITE);
                    if (this.isPlayerTurn && CheckCollisionPointRec(mousePosition, gridTile.getRect)) {
                        if (gridTile.tile.occupant !is null) {
                            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                                this.selectedUnit = gridTile.tile.occupant;
                                this.selectedUnit.updateDistances();
                            }
                            if (this.selectedUnit !is null) {
                                if (this.selectedUnit.getDistance(gridx, gridy).reachable) {
                                    DrawRectangleRec(gridTile.getRect, Color(100, 100, 245, 32));
                                }
                            }
                        }
                        DrawRectangleRec(gridTile.getRect, Color(245, 245, 245, 32));
                    }
                    //DrawRectangleLines(gridx*TILESIZE, gridy*TILESIZE, TILESIZE, TILESIZE, Colours.SHADOW);
                    DrawTextureEx(gridMarker, Vector2(gridx*TILESIZE, gridy*TILESIZE), 0.0, 1.0, Color(10,10,10, markerOpacity));
                }
            }
            drawUnits();
            foreach (int gridx, tileRow; this.grid) {
                foreach (int gridy, tile; tileRow) {
                    if (tile.occupant !is null) {
                        //DrawTexture(this.sprites[tile.occupant.spriteID], gridx*TILESIZE, gridy*TILESIZE-24, Colors.WHITE);
                    }
                }
            }
            EndDrawing();
        }
        CloseWindow();
    }

    void drawTiles() {
        foreach (int x, row; this.squareGrid) {
            foreach (int y, gridTile; row) {
                DrawTextureV(gridTile.sprite, gridTile.getOriginSS, Colors.WHITE);
            }
        }
    }

    void drawUnits() {
        foreach (unit; this.allUnits) {
            Vector2 origin = {x: unit.xlocation*TILESIZE+this.offset.x, y: unit.ylocation*TILESIZE+this.offset.y-24};
            DrawTextureV(this.sprites[unit.spriteID], origin, Colors.WHITE);
        }
    }

    void drawOnMap(Texture2D sprite, Rectangle rect) {
        Vector2 destination = rectDest(rect, this.offset);
        DrawTextureRec(sprite, rect, destination, OPAQUEWHITE);
    }
    void drawOnMap(Rectangle rect, Color colour) {
        rect.x += this.offset.x;
        rect.y += this.offset.y;
        DrawRectangleRec(rect, colour);
    }

    void offsetMap(Rectangle mapView) { 
        Vector2 offsetOffset;
        Vector2 SECornerSS = vect2sum(this.squareGrid[$-1][$-1].SECornerSS, this.offset);
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT)) {
            offsetOffset = GetMouseDelta();
        } else {
            float framelength = GetFrameTime();
            if (IsKeyDown(KeyboardKey.KEY_A)) {
                offsetOffset.x = -framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_D)) {
                offsetOffset.x = framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_W)) {
                offsetOffset.y = -framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_S)) {
                offsetOffset.y = framelength * 32.0;
            }
        }
        this.offset = vect2sum(offsetOffset, this.offset);
        if (offset.x > mapView.x) offset.x = 0.0f;
        else if (offset.x + mapSizePx.x < mapView.width) offset.x = mapView.width - mapSizePx.x;
        if (offset.y > mapView.y) offset.y = 0.0f;
        else if (offset.y + mapSizePx.y < mapView.height) offset.y = mapView.height - mapSizePx.y;
    }

    Unit loadUnitFromJSON (JSONValue unitData, ref int[string] spriteIndex, bool addToMap=true) {
        Unit newUnit;
        if (addToMap) newUnit = new Unit(this, unitData);
        else newUnit = new Unit(unitData);
        string spriteName = unitData["Sprite"].get!string;
        if (spriteName in spriteIndex) {
            newUnit.spriteID = spriteIndex[spriteName];
        } else {
            newUnit.spriteID = cast(uint)this.sprites.length;
            assert(newUnit.spriteID > 0);
            writeln("Player unit spriteID = "~to!string(newUnit.spriteID));
            spriteIndex[spriteName] = newUnit.spriteID;
            string spritePath = ("../sprites/units/" ~ spriteName).buildNormalizedPath;
            if (!spritePath.endsWith(".png")) spritePath ~= ".png";
            this.sprites ~= LoadTexture(spritePath.toStringz);
        }
        //allUnits ~= newUnit; Removed because this was added to Unit.this
        return newUnit;
    }

    class GridTile
    {
        Tile tile;
        private Vector2i origin;
        int x;
        int y;

        this(Tile tile, int x, int y) {
            this.tile = tile;
            this.origin = Vector2i(x*TILESIZE, y*TILESIZE);
            this.x = x;
            this.y = y;
        }

        Rectangle getRect() {
            float x = this.origin.x + this.outer.offset.x;
            float y = this.origin.y + this.outer.offset.y;
            return Rectangle(x:x, y:y, width:TILESIZE, height:TILESIZE);
        }
        Vector2i getOriginAbs() {
            return this.origin;
        }
        Vector2 getOriginSS() {
            float x = this.origin.x + this.outer.offset.x;
            float y = this.origin.y + this.outer.offset.y;
            return Vector2(x, y);
        }
        Vector2 SECornerSS() {
            float x = this.origin.x + TILESIZE + this.outer.offset.x;
            float y = this.origin.y + TILESIZE + this.outer.offset.y;
            return Vector2(x, y);
        }

        Unit* occupant() {
            return this.tile.occupant;
        }
        int spriteID() {
            return cast(int)this.tile.textureID;
        }
        Texture2D sprite() {
            return this.outer.sprites[this.tile.textureID];
        }
    }

    class UnitCard
    {
        Rectangle outerRect;
        Rectangle imageFrame;
        int x;
        int y;
        int width;
        int height;
        Unit unit;
        bool available = true;

        this (Unit unit, int screenx, int screeny ) {
            this.outerRect = Rectangle(screenx, screeny, 256, 72);
            this.imageFrame = Rectangle(screenx+4, screeny+4, 64, 64);
            this.unit = unit;

            this.x = screenx;
            this.y = screeny;
            this.width = 256;
            this.height = 72;
        }

        UnitStats stats() {
            return this.unit.getStats;
        }

        void draw() {
            DrawRectangleRec(outerRect, Color(r:250, b:230, g:245, a:200));
            DrawRectangleLinesEx(outerRect, 1.0f, Colors.BLACK);
            DrawTexture(this.outer.sprites[this.unit.spriteID], cast(int)outerRect.x+4, cast(int)outerRect.y+4, Colors.WHITE);
            //DrawTexture(this.outer.sprites[this.unit.spriteID], this.width+4, this.height+4, Colors.WHITE);
        }
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

enum Colours {
    SHADOW = Color(r:20, b:20, g:20, a:25),
    PAPER = Color(r:240, b:210, g:234, a:250),
    SHINE = Color(250, 250, 60, 30),
}