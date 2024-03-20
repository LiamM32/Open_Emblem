import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm;
import std.datetime.stopwatch;
version (Fluid) {
    import fluid;
} else import raylib;
version (raygui) import raygui;

import common;
import map;
import faction;
import tile;
import vtile;
import unit;
import vunit;
import vector_math;
import constants;
import ui;
import spriteLoader;

const bool updateOnClick = false;

class Mission : Map
{
    Faction playerFaction;
    
    static SpriteLoader spriteLoader;
    version (customgui) static Font font;
    Texture2D[] sprites;
    Texture2D gridMarker;
    
    
    Camera2D camera;
    private Vector2 mousePosition;
    private Vector2i mouseGridPosition;
    Rectangle mapArea = {x:0, y:0};          // Rectangle representing the map area in world space.
    Rectangle mapView;          // Rectanlge representing the visible part of the map in screen space.
    StopWatch missionTimer;
    VisibleTile[] startingTiles;
    
    Unit selectedUnit;


    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        camera.offset = Vector2(0.0f, 0.0f);
        import std.algorithm;
        import std.conv;
        import std.uni: toLower;

        version (customgui) this.font = FontSet.getDefault.serif;

        spriteLoader = SpriteLoader.current;

        super(mapData["map_name"].get!string);
        super.loadFactionsFromJSON(mapData);

        this.grid.length = mapData.object["tiles"].array.length;
        writeln("Starting to unload tile data");
        foreach (uint x, tileRow; mapData.object["tiles"].array) {
            foreach (uint y, tileData; tileRow.arrayNoRef) {
                VisibleTile tile =  new VisibleTile(x, y, tileData);
                this.grid[x] ~= tile;
                if ("Unit" in tileData) {
                    JSONValue unitData = tileData["Unit"];
                    Faction faction;
                    if ("faction" in tileData["Unit"]) faction = factionsByName[unitData["faction"].get!string.toLower];
                    else if ("enemy" in factionsByName) faction = factionsByName["enemy"];
                    else faction = this.factions[1];
                    VisibleUnit occupyingUnit = new VisibleUnit(this, tileData["Unit"]);
                    writeln("New unit "~occupyingUnit.name~" is part of the "~faction.name~" faction.");
                    this.allUnits ~= cast(Unit) occupyingUnit;
                    faction.units ~= cast(Unit) occupyingUnit;
                    occupyingUnit.setLocation(x, y);
                } else if ("Player Unit" in tileData) {
                    this.grid[x][y].startLocation = true;
                    startingTiles ~= tile;
                }
            }
        }
        this.gridWidth = cast(ushort)this.grid.length;
        this.gridLength = cast(ushort)this.grid[0].length;
        this.mapArea.width = cast(int)this.gridLength * TILEWIDTH;
        this.mapArea.height = cast(int)this.gridWidth * TILEHEIGHT;
        writeln(mapArea.height);
        mapArea = Rectangle(x:0, y:0, width:grid.length*TILEWIDTH, height:grid[0].length*TILEHEIGHT);
        debug writeln("Finished loading map " ~ this.name);
        this.playerFaction = factionsByName["player"];
        this.gridMarker = spriteLoader.getSprite("grid marker");
        this.fullyLoaded = true;

        this.turnReset;
    }

    void run() {
        startPreparation();
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight);
        writeln("There are ", factions.length, " factions.");
        while(!WindowShouldClose) {
            playerTurn();
            factions[1].turn();
        }
    }

    void startPreparation() {   
        this.phase = GamePhase.Preparation;

        Rectangle menuBox = {x:0, y:GetScreenHeight()-96, width:GetScreenWidth(), height:96};
        Unit[] availableUnits;
        UnitInfoCard[Unit] unitCards;
        
        JSONValue playerUnitsData = parseJSON(readText("Units.json"));
        debug writeln("Opened Units.json");
        foreach (uint k, unitData; playerUnitsData.array) {
            VisibleUnit unit = new VisibleUnit(this, unitData, factionsByName["player"]);//loadUnitFromJSON(unitData, spriteIndex, false);
            availableUnits ~= unit;
            unitCards[unit] = new UnitInfoCard(unit, k*258, GetScreenHeight()-88);
        }
        debug writeln("There are "~to!string(unitCards.length)~" units available.");

        foreach (i, unit; this.allUnits) {
            if (unit !is null) writeln("mission.allUnits has a unit named "~unit.name);
            else writeln("mission.allUnits["~to!string(i)~"] is null");
        }

        version (Fluid) {
            Label startButton = button("Start Mission", delegate {
                this.endTurn();
            });
        } else version (raygui) {
            Rectangle startButton = {x:GetScreenWidth()-160, y:menuBox.y-16, width:160, height:32};
        } else version (customgui) {
            TextButton startButton;
            {
                Rectangle buttonOutline = {x:GetScreenWidth()-160, y:menuBox.y-16, width:160, height:32};
                startButton = new TextButton(buttonOutline, "Start Mission", 24, Colours.Crimson, true);
            }
        }

        mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);
        camera.zoom = 1.0f;
        camera.rotation = 0.0f;
        camera.offset = Vector2(mapView.width/2.0f, mapView.height/2.0f);
        camera.target.x = mapArea.width/2.0f;
        camera.target.y = mapArea.height-mapView.height/2.0f;
        foreach (startTile; startingTiles) camera.target.y = max(startTile.y+TILEHEIGHT*2, mapArea.height) - mapView.height/2.0f;
        
        missionTimer = StopWatch(AutoStart.yes);
        bool startButtonAvailable = false;
        bool leftClick;
        const Vector2 dragOffset = {x: -TILEWIDTH/2, y: -TILEHEIGHT*0.75 };
        ushort unitsDeployed = 0;

        while(!WindowShouldClose() && phase==GamePhase.Preparation) {
            unitsDeployed = 0;
            mousePosition = GetMousePosition();
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);

            BeginDrawing();
            this.offsetCamera(mapView);
            BeginMode2D(camera);

            drawGround();
            foreach(startTile; startingTiles) { //This loop handles the starting locations, where the player may place their units.
                Rectangle startTileRect = startTile.getRect();
                DrawRectangleRec(startTileRect, Color(250, 250, 60, 60));
                DrawRectangleLinesEx(startTileRect, 1.5f, Color(240, 240, 40, 120));
                if (startTile.occupant !is null) {
                    unitsDeployed++;
                    Vector2 destination = startTile.origin + Vector2(0, -24);
                    Color tint;
                    if (startTile.occupant == this.selectedUnit) tint = Color(250, 250, 250, 190);
                    else tint = Color(255, 255, 255, 255);
                    DrawTextureV((cast(VisibleUnit)startTile.occupant).sprite, destination, tint);
                }
                if (mouseGridPosition == Vector2i(startTile.x, startTile.y)) {
                    DrawRectangleRec(startTileRect, Color(250, 30, 30, 30));
                    if (leftClick) {
                        Unit previousOccupant = startTile.occupant;
                        if (selectedUnit !is null) {
                            if (selectedUnit.currentTile !is null) selectedUnit.currentTile.occupant = null;
                            selectedUnit.currentTile = startTile;
                            debug writeln("Unit "~selectedUnit.name~" is being deployed.");
                        }
                        startTile.occupant = selectedUnit;
                        
                        if (previousOccupant !is null) previousOccupant.currentTile = null;
                        selectedUnit = previousOccupant;
                    }
                }
            }
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
            EndMode2D();

            DrawRectangleRec(menuBox, Colours.Paper);
            foreach (card; unitCards) if (card.unit.currentTile is null) {
                card.draw(this.sprites);
                if (leftClick && card.available && CheckCollisionPointRec(mousePosition, card.outline)) this.selectedUnit = card.unit;
            }

            if (this.selectedUnit !is null) {
                DrawTextureV((cast(VisibleUnit)this.selectedUnit).sprite, mousePosition+dragOffset, Colors.WHITE);
            }
            if (unitsDeployed > 0 && missionTimer.peek() >= msecs(WAITTIME*startingTiles.length/unitsDeployed)) {
                version (customgui) {
                    startButton.draw();
                    if (CheckCollisionPointRec(mousePosition, startButton.outline) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                        EndDrawing();
                        break;
                    }
                } else version (raygui) {
                    if (GuiButton(startButton, "Start Mission".toStringz)) {
                        EndDrawing();
                        break;
                    }
                }
            }

            debug if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
                DrawRectangleRec(mapView, Color(250, 20, 20, 50));
            }

            version (drawFPS) DrawFPS(20, 20);
            EndDrawing();
        }

        foreach (card; unitCards) {
            destroy(card);
        }
        destroy(menuBox);
        
        foreach (startTile; this.startingTiles) if (startTile.occupant !is null) {
            writeln("Looking at starting tile "~to!string(startTile.x())~", "~to!string(startTile.y()));
            this.allUnits ~= cast(VisibleUnit) startTile.occupant;
            this.factionsByName["player"].units ~= startTile.occupant;
            startTile.occupant.setLocation(startTile.x(), startTile.y());
        }
        this.startingTiles.length = 0;

        debug verifyEverything;

        this.endTurn;
    }

    void playerTurn() {
        import item;

        this.factionsByName["player"].turnReset();
        
        Vector2 mousePosition = GetMousePosition();
        bool onButton = false;
        bool leftClick = false;
        VisibleTile cursorTile;

        version (customgui) {
            TextButton moveButton;
            TextButton attackButton;
            TextButton itemsButton;
            TextButton waitButton;
            TextButton backButton;
            TextButton finishButton;
            {
                Rectangle buttonOutline = {x:GetScreenWidth-96, y:GetScreenHeight-32, 80, 32};
                backButton = new TextButton(buttonOutline, "Back", 20, Colours.Crimson, true);
                buttonOutline.y -= 48;
                waitButton = new TextButton(buttonOutline, "Wait", 20, Colours.Crimson, true);
                buttonOutline.y -= 48;
                itemsButton = new TextButton(buttonOutline, "Items", 20, Colours.Crimson, true);
                buttonOutline.y -= 48;
                attackButton = new TextButton(buttonOutline, "Attack", 20, Colours.Crimson, true);
                buttonOutline.y -= 48;
                moveButton = new TextButton(buttonOutline, "Move", 20, Colours.Crimson, true);
                buttonOutline = Rectangle(x:GetScreenWidth-128, y:GetScreenHeight-32, 128, 32);
                finishButton = new TextButton(buttonOutline, "Finish turn", 20, Colours.Crimson, true);
            }
            assert(moveButton.buttonColour == Colours.Crimson, "Move button does not appear to be initialized.");
        } else version (raygui) {
            Rectangle moveButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*5), 96, 32};
            Rectangle attackButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*4), 96, 32};
            Rectangle itemsButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*3), 96, 32};
            Rectangle waitButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*2), 96, 32};
            Rectangle backButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*1), 96, 32};
            Rectangle finishButton = {x:GetScreenWidth-128, y:GetScreenHeight-32, 128, 32};
        }

        MenuList!Item itemsList;
        
        enum Action:ubyte {Nothing, Move, Attack, Items, EndTurn};
        Action playerAction = Action.Nothing;

        VisibleUnit movingUnit = null;
        debug Texture arrow = LoadTexture("../sprites/arrow.png");

        debug verifyEverything();

        while(!WindowShouldClose() && playerAction != Action.EndTurn)
        {
            debug if (playerAction != Action.Nothing && selectedUnit is null) throw new Exception ("`playerAction is not set to `Nothing`, but `selectedUnit` is null.");
            mousePosition = GetMousePosition();
            mouseGridPosition.x = cast(int)GetScreenToWorld2D(GetMousePosition, camera).x / TILEWIDTH;
            mouseGridPosition.y = cast(int)GetScreenToWorld2D(GetMousePosition, camera).y / TILEHEIGHT;
            cursorTile = cast(VisibleTile)getTile(mouseGridPosition, true);
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);
            offsetCamera(mapView);
            if (movingUnit !is null) movingUnit.stepTowards();
            BeginDrawing();
            BeginMode2D(camera);
            drawGround();

            if (selectedUnit !is null) switch(playerAction) {
                case Action.Move:
                    foreach (tileAccess; selectedUnit.getReachable!TileAccess) {
                        DrawRectangleRec((cast(VisibleTile)tileAccess.tile).rect, Color(60, 240, 120, 30));
                    }
                    if (leftClick && selectedUnit.getTileAccess(mouseGridPosition).reachable) {
                        selectedUnit.move(cursorTile.x, cursorTile.y);
                        playerAction = Action.Nothing;
                    }
                    break;
                case Action.Attack:
                    foreach (tileAccess; selectedUnit.getAttackable!TileAccess) {
                        DrawRectangleRec((cast(VisibleTile)tileAccess.tile).rect, Color(60, 240, 120, 30));
                    }
                    if (leftClick && cursorTile.occupant !is null && canFind(playerFaction.enemies, cursorTile.occupant.faction)) {
                        selectedUnit.move(mouseGridPosition.x, mouseGridPosition.y);
                        playerAction = Action.Nothing;
                    }
                    break;
                default: break;
            }
            if (cursorTile !is null) DrawRectangleRec(cursorTile.rect, Colours.Highlight); // Highlights the tile where the cursor is.

            //if (selectedUnit !is null) DrawRectangleRec((cast(VisibleTile)selectedUnit.currentTile).rect, Colours.Highlight);
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
            EndMode2D();
            
            /*switch (playerAction) {
                case Action.Nothing:
                    if (cursorTile.occupant !is null && cursorTile)
            }*/
            
            if (selectedUnit !is null) {
                if (playerAction == Action.Nothing) {
                    version (customgui) {
                        if (selectedUnit.canMove && moveButton.button(onButton)) {
                            playerAction = Action.Move;
                        } else if (!selectedUnit.hasActed && attackButton.button(onButton)) {
                            playerAction = Action.Attack;
                        } else if (itemsButton.button(onButton)) {
                            playerAction = Action.Items;
                            itemsList = new MenuList!Item(GetScreenWidth-128, GetScreenHeight()/2, selectedUnit.inventory);
                        } else if (waitButton.button(onButton)) {
                            selectedUnit.hasActed = true;
                            selectedUnit.finishedTurn = true;
                            playerAction = Action.Nothing;
                            selectedUnit = null;
                        } else if (backButton.button(onButton)) selectedUnit = null;
                    } version (raygui) {
                        if (selectedUnit.MvRemaining > 1) if (GuiButton(moveButton, "#150#Move".toStringz)) playerAction = Action.Move;
                        if (!selectedUnit.hasActed) if (GuiButton(attackButton, "#155#Attack".toStringz)) playerAction = Action.Attack;
                        if (GuiButton(itemsButton, "Items".toStringz)) playerAction = Action.Items;
                        if (GuiButton(waitButton, "#149#Wait ".toStringz)) {
                            selectedUnit.hasActed = true;
                            selectedUnit.finishedTurn = true;
                            playerAction = Action.Nothing;
                            selectedUnit = null;
                        }
                        if (GuiButton(backButton, "Back".toStringz)) selectedUnit = null;
                    }
                } else {
                    version (customgui) {
                        if (backButton.button(onButton)) playerAction = Action.Nothing;
                    } version (raygui) {
                        if (GuiButton(backButton, "Back".toStringz)) playerAction = Action.Nothing;
                    }
                    ubyte selectedItem;
                    if (playerAction == Action.Items && itemsList !is null && itemsList.draw(selectedItem)) { //The `itemsList !is null` check can be removed if it won't result in a segfault.
                        // Do something with item.
                        playerAction = Action.Nothing;
                        destroy(itemsList);
                    }
                }
            } else {
                ushort remaining = cast(short)(factionsByName["player"].units.length * 2);
                foreach (unit; factionsByName["player"].units) {
                    remaining -= unit.hasActed;
                    remaining -= unit.finishedTurn;
                }
                if (remaining < 3) {
                    version (customgui) {
                        finishButton.draw;
                        if (finishButton.button(onButton)) playerAction = Action.EndTurn;
                    } version (raygui) {
                        if (GuiButton(finishButton, "Finish turn".toStringz)) playerAction = Action.EndTurn;
                    }
                }
            }
            version (drawFPS) DrawFPS(20, 20);
            EndDrawing();
        }

        selectedUnit = null;
        endTurn();
    }

    void drawGround() {
        foreach (uint x, row; cast(VisibleTile[][]) grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
            }
        }
    }

    void drawGridMarkers(long time) {
        import std.math.trigonometry:sin;
        import std.math;
        
        float sinwave = 80*(sin(cast(float)time/300.0f)+1.0);
        int opacity = sinwave.to!int + 20;
        foreach (uint x, row; cast(VisibleTile[][]) grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(this.gridMarker, tile.origin, Color(10,10,10, cast(ubyte)sinwave));
            }
        }
    }

    void drawUnits() {
        Color shade;
        foreach (VisibleUnit unit; cast(VisibleUnit[]) allUnits) {
            if (this.phase==GamePhase.PlayerTurn && unit.hasActed) shade = Color(200,200,200,200);
            else shade = Colors.WHITE;
            DrawTextureV(unit.sprite, unit.position+Vector2(0.0f,-24.0f), shade);
        }
    }

    void drawOnMap(Texture2D sprite, Rectangle rect) {
        Vector2 destination = rectDest(rect, camera.offset);
        DrawTextureRec(sprite, rect, destination, Colors.WHITE);
    }
    void drawOnMap(Rectangle rect, Color colour) {
        rect.x += camera.offset.x;
        rect.y += camera.offset.y;
        DrawRectangleRec(rect, colour);
    }

    void offsetCamera(Rectangle mapView) { 
        mousePosition = GetMousePosition();
        {
            Vector2 mouseWorldPosition = GetScreenToWorld2D(mousePosition, camera);
            mouseGridPosition.x = cast(int)mouseWorldPosition.x / TILEWIDTH;
            mouseGridPosition.y = cast(int)mouseWorldPosition.y / TILEHEIGHT;
        }
        
        Vector2 targetOffset;
        
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT)) {
            targetOffset = GetMouseDelta();
        } else {
            float framelength = GetFrameTime();
            if (IsKeyDown(KeyboardKey.KEY_A)) {
                targetOffset.x = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_D)) {
                targetOffset.x = framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_W)) {
                targetOffset.y = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_S)) {
                targetOffset.y = framelength * 24.0;
            }
        }
        camera.target -= targetOffset;

        Vector2 margins = {0, 0}; // This step can later be reworked to happen less frequently.
        if (mapArea.width < mapView.width) margins.x = (mapView.width-mapArea.width)/2;
        if (mapArea.height < mapView.height) margins.y = (mapView.height-mapArea.height)/2;

        Vector2 topLeftPosition = GetScreenToWorld2D(Vector2(mapView.x, mapView.y), camera);
        Vector2 bottomRightPosition = GetScreenToWorld2D(Vector2(mapView.x+mapView.width, mapView.y+mapView.height), camera);
        if (topLeftPosition.x < (mapArea.x - margins.x)) camera.target.x -= topLeftPosition.x;
        else if (bottomRightPosition.x > mapArea.width + margins.x) camera.target.x -= bottomRightPosition.x - mapArea.width;
        if (topLeftPosition.y < (mapArea.y - margins.y)) camera.target.y -= topLeftPosition.y;
        else if (bottomRightPosition.y > (mapArea.y + mapArea.height)) camera.target.y -= bottomRightPosition.y - (mapArea.y + mapArea.height);
    }
}


unittest
{
    debug writeln("Starting Mission unittest");
    validateRaylibBinding();
    InitWindow(400, 400, "Mission unittest");
    Mission mission = new Mission("../maps/test-map.json");
    foreach (unit; mission.allUnits) {
        assert(unit.map == mission, "Unit does not have it's `map` set to current Mission.");
    }
    writeln("Mission unittest passed");
}