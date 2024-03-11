import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm.searching;
import std.datetime.stopwatch;
import raylib;

import common;
import map;
import tile;
import vtile;
import unit;
import vunit;
import vector_math;
import ui;

const int TILESIZE = 64;

class Mission : MapTemp!(VisibleTile, VisibleUnit)
{
    Texture2D[] sprites;
    Texture2D gridMarker;
    Texture2D*[string] spriteIndex;
    Unit selectedUnit;
    public static Font font;
    Vector2 offset;
    Rectangle mapView;
    Vector2i mapSizePx;
    StopWatch missionTimer;

    VisibleTile[] startingPoints;

    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        this.offset = Vector2(0.0f, 0.0f);
        import std.algorithm;
        import std.conv;

        this.font = LoadFont("../sprites/font/LiberationSerif-Regular.ttf");

        super(mapData["map_name"].get!string);
        super.loadFactionsFromJSON(mapData);

        this.grid.length = mapData.object["tiles"].array.length;
        writeln("Starting to unload tile data");
        foreach (uint x, tileRow; mapData.object["tiles"].array) {
            foreach (uint y, tileData; tileRow.arrayNoRef) {
                string spriteName = tileData["tile_sprite"].get!string;
                string spritePath = ("../sprites/tiles/" ~ spriteName).buildNormalizedPath;
                VisibleTile tile =  new VisibleTile(tileData, this.spriteIndex, x, y);
                if (spriteName in this.spriteIndex) tile.sprite = spriteIndex["spriteName"];
                else {
                    this.sprites ~= LoadTexture(spritePath.toStringz);
                    tile.sprite = & this.sprites[$-1];
                }
                this.grid[x] ~= tile;
                if ("Unit" in tileData) {
                    VisibleUnit occupyingUnit = new VisibleUnit(this, tileData["Unit"]);
                    this.allUnits ~= occupyingUnit;
                    this.factionUnits[occupyingUnit.faction] ~= occupyingUnit;
                    occupyingUnit.setLocation(x, y);
                } else if ("Player Unit" in tileData) {
                    this.grid[x][y].startLocation = true;
                    startingPoints ~= tile;
                }
            }
            write("Finished loading row ");
            writeln(x);
        }
        this.mapSizePx.x = cast(int)this.grid.length * TILESIZE;
        this.mapSizePx.y = cast(int)this.grid[0].length * TILESIZE;
        writeln("Finished loading map " ~ this.name);
        {
            import std.conv;
            writeln("Map is "~to!string(this.grid.length)~" by "~to!string(this.grid.length)~" tiles.");
        }
        this.gridMarker = LoadTexture("../sprites/grid-marker.png".toStringz);
        this.fullyLoaded = true;
    }

    void run() {
        startPreparation();
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight);
        playerTurn();
    }

    void startPreparation() {   
        Rectangle menuBox = {x:0, y:GetScreenHeight()-96, width:GetScreenWidth(), height:96};
        Unit[] availableUnits;
        UnitInfoCard[Unit] unitCards;
        
        JSONValue playerUnitsData = parseJSON(readText("Units.json"));
        writeln("Opened Units.json");
        foreach (uint k, unitData; playerUnitsData.array) {
            VisibleUnit unit = loadUnitFromJSON(unitData, spriteIndex, false);
            unit.map = this;
            availableUnits ~= unit;
            unitCards[unit] = new UnitInfoCard(unit, k*258, GetScreenHeight()-88);
        }
        writeln("There are "~to!string(unitCards.length)~" units available.");

        foreach (i, unit; this.allUnits) {
            if (unit !is null) writeln("mission.allUnits has a unit named "~unit.name);
            else writeln("mission.allUnits["~to!string(i)~"] is null");
        }

        this.phase = GamePhase.Preparation;

        TextButton startButton;
        {
            Rectangle buttonOutline = {x:GetScreenWidth()-112, y:menuBox.y-16, width:80, height:32};
            startButton = new TextButton(buttonOutline, this.font, "Start Mission", 16, Colours.Crimson, true);
        }
        
        missionTimer = StopWatch(AutoStart.yes);
        bool startButtonAvailable = false;
        Vector2 mousePosition = GetMousePosition();
        bool leftClick;
        const Vector2 dragOffset = {x: -TILESIZE/2, y: -TILESIZE*0.75 };
        this.offset = Vector2(0.0, -96.0);
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);
        ushort unitsDeployed = 0;

        while(!WindowShouldClose()) {
            unitsDeployed = 0;
            mousePosition = GetMousePosition();
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);
            BeginDrawing();
            this.offsetMap(mapView);
            drawTiles();
            foreach(startTile; startingPoints) { //This loop handles the starting locations, where the player may place their units.
                Rectangle startTileRect = startTile.getRect(offset);
                DrawRectangleRec(startTileRect, Color(250, 250, 60, 60));
                DrawRectangleLinesEx(startTileRect, 1.5f, Color(240, 240, 40, 120));
                if (startTile.occupant !is null) {
                    unitsDeployed++;
                    Vector2 destination = startTile.getDestination(offset) + Vector2(0, -24);
                    Color tint;
                    if (startTile.occupant == this.selectedUnit) tint = Color(250, 250, 250, 190);
                    else tint = Color(255, 255, 255, 255);
                    DrawTextureV((cast(VisibleUnit)startTile.occupant).sprite, destination, tint);
                }
                if (CheckCollisionPointRec(mousePosition, startTileRect)) {
                    DrawRectangleRec(startTileRect, Color(250, 30, 30, 30));
                }
            }
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();

            DrawRectangleRec(menuBox, Colours.Paper);
            foreach (card; unitCards) if (card.unit.currentTile is null) {
                card.draw(this.sprites);
            }

            if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
                DrawRectangleRec(mapView, Color(250, 20, 20, 50));
            }

            if (this.selectedUnit is null) {
                if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    bool searching = true;
                    foreach (card; unitCards) if (CheckCollisionPointRec(mousePosition, card.outline)) {
                        searching = false;
                        if (card.available) {
                            this.selectedUnit = card.unit;
                            break;
                        }
                    }
                    if (searching) foreach (startTile; startingPoints) if (CheckCollisionPointRec(mousePosition, startTile.getRect(offset))) {
                        this.selectedUnit = startTile.occupant;
                    }
                }
            } else {
                DrawTextureV((cast(VisibleUnit)this.selectedUnit).sprite, mousePosition+dragOffset, Colors.WHITE);
                if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    bool deployed;
                    if (CheckCollisionPointRec(mousePosition, menuBox)) deployed = false;
                    else deployed = (this.selectedUnit.currentTile !is null);
                    foreach (tile; startingPoints) if (CheckCollisionPointRec(mousePosition, tile.getRect(offset))) {
                        Unit previousOccupant = tile.occupant;
                        if (this.selectedUnit.currentTile !is null) this.selectedUnit.currentTile.occupant = null;
                        tile.occupant = this.selectedUnit;
                        this.selectedUnit.currentTile = tile;
                        deployed = true;
                        writeln("Unit "~tile.occupant.name~" is being deployed.");
                        if (previousOccupant !is null) previousOccupant.currentTile = null;
                        this.selectedUnit = previousOccupant;
                        break;
                    }
                    if (!deployed) {
                        if (this.selectedUnit.currentTile !is null) {
                            this.selectedUnit.currentTile.occupant = null;
                            this.selectedUnit.currentTile = null;
                        }
                        this.selectedUnit = null;
                    }
                }
            }
            if (unitsDeployed > 0 && missionTimer.peek() >= msecs(1000*startingPoints.length/unitsDeployed)) {
                startButton.draw();
                if (CheckCollisionPointRec(mousePosition, startButton.outline) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    EndDrawing();
                    break;
                };
            }
            DrawFPS(20, 20);
            EndDrawing();
        }

        foreach (card; unitCards) {
            destroy(card);
        }
        destroy(menuBox);
        
        foreach (startTile; this.startingPoints) if (startTile.occupant !is null) {
            writeln("Looking at starting tile "~to!string(startTile.x())~", "~to!string(startTile.y()));
            this.allUnits ~= cast(VisibleUnit) startTile.occupant;
            this.factionUnits["player"] ~= cast(VisibleUnit) startTile.occupant;
            startTile.occupant.setLocation(startTile.x(), startTile.y());
        }
        this.startingPoints.length = 0;

        foreach (unit; this.allUnits) unit.verify();

        this.nextTurn;
    }

    void playerTurn() {
        this.turnReset();
        
        Vector2 mousePosition = GetMousePosition();
        bool onMap = true;
        bool leftClick = false;

        TextButton moveButton;
        TextButton attackButton;
        TextButton itemsButton;
        TextButton waitButton;
        TextButton backButton;
        {
            Rectangle buttonOutline = {x:GetScreenWidth-112, y:GetScreenHeight-32, 80, 32};
            backButton = new TextButton(buttonOutline, font, "Back", 16, Colours.Crimson, true);
            buttonOutline.y -= 48;
            waitButton = new TextButton(buttonOutline, font, "Wait", 16, Colours.Crimson, true);
            buttonOutline.y -= 48;
            moveButton = new TextButton(buttonOutline, font, "Move", 16, Colours.Crimson, true);
            buttonOutline.y -= 48;
            attackButton = new TextButton(buttonOutline, font, "Attack", 16, Colours.Crimson, true);
            buttonOutline.y -= 48;
            itemsButton = new TextButton(buttonOutline, font, "Items", 16, Colours.Crimson, true);
        }
        assert(moveButton.buttonColour == Colours.Crimson, "Move button does not appear to be initialized.");

        debug {
            moveButton.dump;
            attackButton.dump;
        }
        
        enum Action:ubyte {Nothing, Move, Attack, Items};
        Action playerAction = Action.Nothing;

        while(!WindowShouldClose())
        {
            debug if (playerAction != Action.Nothing && selectedUnit is null) throw new Exception ("`playerAction is not set to `Nothing`, but `selectedUnit` is null.");
            mousePosition = GetMousePosition();
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);
            this.offsetMap(mapView);
            BeginDrawing();

            drawTiles();
            foreach (uint gridx, row; this.grid) {
                foreach (uint gridy, tile; row) {
                    if (playerAction == Action.Move && selectedUnit.getDistance(gridx,gridy).reachable) DrawRectangleRec(tile.getRect(offset), Color(60, 240, 120, 30));
                    if (CheckCollisionPointRec(mousePosition, tile.getRect(offset))) {
                        if (tile.occupant !is null) {
                            if (leftClick && playerAction == Action.Nothing) {
                                this.selectedUnit = tile.occupant;
                                this.selectedUnit.updateDistances();
                            }
                            if (this.selectedUnit !is null) {
                                if (this.selectedUnit.getDistance(gridx, gridy).reachable) {
                                    DrawRectangleRec(tile.getRect(offset), Color(100, 100, 245, 32));
                                }
                            }
                        } else {
                            if(playerAction == Action.Move && leftClick && selectedUnit.getDistance(gridx,gridy).reachable) {
                                selectedUnit.move(gridx, gridy);
                            }
                        }
                        if (onMap) DrawRectangleRec(tile.getRect(offset), Colours.CursorHighlight);
                    }
                }
            }
            if (selectedUnit !is null) DrawRectangleRec((cast(VisibleTile)selectedUnit.currentTile).rect, Colours.CursorHighlight);
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
            if (selectedUnit !is null) {
                if (playerAction == Action.Nothing) {
                    moveButton.draw;
                    attackButton.draw;
                    itemsButton.draw;
                    waitButton.draw;
                    if (CheckCollisionPointRec(mousePosition, moveButton.outline)) {
                        onMap = false;
                        if (leftClick) playerAction = Action.Move;
                    } else if (CheckCollisionPointRec(mousePosition, attackButton.outline)) {
                        onMap = false;
                        if (leftClick) playerAction = Action.Attack;
                    } else if (CheckCollisionPointRec(mousePosition, itemsButton.outline)) {
                        onMap = false;
                        if (leftClick) playerAction = Action.Items;
                    } else onMap = true;
                } else {
                    backButton.draw;
                    if (CheckCollisionPointRec(mousePosition, backButton.outline)) {
                        onMap = false;
                        if (leftClick) playerAction = Action.Nothing;
                    } else onMap = true;
                }
            }
            EndDrawing();
        }

        this.nextTurn();
    }

    void drawTiles() {
        foreach (uint x, row; this.grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(*tile.sprite, tile.getDestination(offset), Colors.WHITE);
            }
        }
    }

    void drawGridMarkers(long time) {
        import std.math.trigonometry:sin;
        import std.math;
        
        float sinwave = 80*(sin(cast(float)time/300.0f)+1.0);
        int opacity = sinwave.to!int + 20;
        foreach (uint x, row; this.grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(this.gridMarker, tile.getDestination(offset), Color(10,10,10, cast(ubyte)sinwave));
            }
        }
    }

    void drawUnits() {
        foreach (unit; this.allUnits) {
            Vector2 origin = {x: unit.xlocation*TILESIZE+this.offset.x, y: unit.ylocation*TILESIZE+this.offset.y-24};
            DrawTextureV(unit.sprite, origin, Colors.WHITE);
        }
    }

    void drawOnMap(Texture2D sprite, Rectangle rect) {
        Vector2 destination = rectDest(rect, this.offset);
        DrawTextureRec(sprite, rect, destination, Colors.WHITE);
    }
    void drawOnMap(Rectangle rect, Color colour) {
        rect.x += this.offset.x;
        rect.y += this.offset.y;
        DrawRectangleRec(rect, colour);
    }

    void offsetMap(Rectangle mapView) { 
        Vector2 offsetOffset;
        Vector2 SECornerSS = this.grid[$-1][$-1].getDestination(this.offset);
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
        this.offset += offsetOffset;
        if (offset.x > mapView.x) offset.x = 0.0f;
        else if (offset.x + mapSizePx.x < mapView.width) offset.x = mapView.width - mapSizePx.x;
        if (offset.y > mapView.y) offset.y = 0.0f;
        else if (offset.y + mapSizePx.y < mapView.height) offset.y = mapView.height - mapSizePx.y;
    }

    VisibleUnit loadUnitFromJSON (JSONValue unitData, ref Texture*[string] spriteIndex, bool addToMap=true) {
        VisibleUnit newUnit = new VisibleUnit(this, unitData);
        string spriteName = unitData["Sprite"].get!string;
        string spritePath = ("../sprites/units/" ~ spriteName).buildNormalizedPath;
        this.sprites ~= LoadTexture(spritePath.toStringz);
        spriteIndex[spriteName] = &this.sprites[$-1];
        if (addToMap) allUnits ~= newUnit;
        return newUnit;
    }
}


unittest
{
    validateRaylibBinding();
    Mission mission = new Mission("../maps/test-map.json");
    writeln("Mission unittest: Finished Mission constructor.");
    foreach (unit; mission.allUnits) {
        assert(unit.map == mission);
        if(mission != unit.map) writeln("These objects do not match"); 
    }
}