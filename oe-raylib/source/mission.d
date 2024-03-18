import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm.searching;
import std.datetime.stopwatch;
version (Fluid) {
    import fluid;
} else import raylib;
version (raygui) import raygui;

import common;
import map;
import tile;
import vtile;
import unit;
import vunit;
import vector_math;
import constants;
import ui;

const bool updateOnClick = false;

class Mission : MapTemp!(VisibleTile, VisibleUnit)
{
    Texture2D[] sprites;
    Texture2D gridMarker;
    Texture2D*[string] spriteIndex;
    Unit selectedUnit;
    version (customgui) static Font font;
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
        import std.uni: toLower;

        version (customgui) this.font = FontSet.getDefault.serif;

        super(mapData["map_name"].get!string);
        super.loadFactionsFromJSON(mapData);

        this.grid.length = mapData.object["tiles"].array.length;
        writeln("Starting to unload tile data");
        foreach (uint x, tileRow; mapData.object["tiles"].array) {
            foreach (uint y, tileData; tileRow.arrayNoRef) {
                string spriteName = tileData["tile_sprite"].get!string;
                string spritePath = ("../sprites/tiles/" ~ spriteName).buildNormalizedPath;
                VisibleTile tile =  new VisibleTile(tileData, this.spriteIndex, x, y);
                if (spriteName in this.spriteIndex) tile.sprite = spriteIndex[spriteName];
                else {
                    this.sprites ~= LoadTexture(spritePath.toStringz);
                    tile.sprite = &this.sprites[$-1];
                    this.spriteIndex[spriteName] = &this.sprites[$-1];
                }
                this.grid[x] ~= tile;
                if ("Unit" in tileData) {
                    JSONValue unitData = tileData["Unit"];
                    Faction faction;
                    if ("faction" in tileData["Unit"]) faction = factionsByName[unitData["faction"].get!string.toLower];
                    else if ("enemy" in factionsByName) faction = factionsByName["enemy"];
                    else faction = this.factions[1];
                    VisibleUnit occupyingUnit = new VisibleUnit(this, tileData["Unit"]);
                    writeln("New unit "~occupyingUnit.name~" is part of the "~faction.name~" faction.");
                    this.allUnits ~= occupyingUnit;
                    faction.units ~= occupyingUnit;
                    occupyingUnit.setLocation(x, y);
                } else if ("Player Unit" in tileData) {
                    this.grid[x][y].startLocation = true;
                    startingPoints ~= tile;
                }
            }
        }
        this.gridWidth = cast(ushort)this.grid.length;
        this.gridLength = cast(ushort)this.grid[0].length;
        this.mapSizePx.x = cast(int)this.grid.length * TILEWIDTH;
        this.mapSizePx.y = cast(int)this.grid[0].length * TILEHEIGHT;
        debug writeln("Finished loading map " ~ this.name);
        {
            import std.conv;
            debug writeln("Map is "~to!string(this.grid.length)~" by "~to!string(this.grid.length)~" tiles.");
        }
        this.gridMarker = LoadTexture("../sprites/grid-marker.png".toStringz);
        this.fullyLoaded = true;

        this.turnReset;
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
        debug writeln("Opened Units.json");
        foreach (uint k, unitData; playerUnitsData.array) {
            VisibleUnit unit = new VisibleUnit(this, unitData, factionsByName["player"]);//loadUnitFromJSON(unitData, spriteIndex, false);
            unit.map = this;
            availableUnits ~= unit;
            unitCards[unit] = new UnitInfoCard(unit, k*258, GetScreenHeight()-88);
        }
        debug writeln("There are "~to!string(unitCards.length)~" units available.");

        foreach (i, unit; this.allUnits) {
            if (unit !is null) writeln("mission.allUnits has a unit named "~unit.name);
            else writeln("mission.allUnits["~to!string(i)~"] is null");
        }

        this.phase = GamePhase.Preparation;

        version (Fluid) {
            Label startButton = button("Start Mission", delegate {
                this.nextTurn();
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
        
        missionTimer = StopWatch(AutoStart.yes);
        bool startButtonAvailable = false;
        Vector2 mousePosition = GetMousePosition();
        bool leftClick;
        const Vector2 dragOffset = {x: -TILEWIDTH/2, y: -TILEHEIGHT*0.75 };
        this.offset = Vector2(0.0, -96.0);
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);
        ushort unitsDeployed = 0;

        while(!WindowShouldClose() && phase==GamePhase.Preparation) {
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
                        if (selectedUnit.currentTile == tile) {
                            tile.occupant = selectedUnit;
                            selectedUnit = null;
                        } else {
                            Unit previousOccupant = tile.occupant;
                            if (this.selectedUnit.currentTile !is null) this.selectedUnit.currentTile.occupant = null;
                            tile.occupant = this.selectedUnit;
                            this.selectedUnit.currentTile = tile;
                            writeln("Unit "~tile.occupant.name~" is being deployed.");
                            if (previousOccupant !is null) previousOccupant.currentTile = null;
                            this.selectedUnit = previousOccupant;
                        }
                        deployed = true;
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
            this.factionsByName["player"].units ~= startTile.occupant;
            startTile.occupant.setLocation(startTile.x(), startTile.y());
        }
        this.startingPoints.length = 0;

        foreach (unit; this.allUnits) unit.verify();
        debug {
            foreach (uint x, row; this.grid) {
                foreach (uint y, tile; row) {
                    assert(tile.occupant is null || tile == tile.occupant.currentTile);
                    assert(tile.x == x);
                    assert(tile.y == y);
                }
            }
        }

        this.nextTurn;
    }

    void playerTurn() {
        import item;

        this.factionsByName["player"].turnReset();
        
        Vector2 mousePosition = GetMousePosition();
        bool onButton = false;
        bool leftClick = false;

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
        
        enum Action:ubyte {Nothing, Move, Attack, Items};
        Action playerAction = Action.Nothing;

        VisibleUnit movingUnit = null;
        debug Texture arrow = LoadTexture("../sprites/arrow.png");

        foreach (row; this.grid) foreach (tile; row) {
            writeln("Tile ", tile.x, ", ", tile.y, " is occupied by ", tile.occupant);
        }

        while(!WindowShouldClose())
        {
            debug if (playerAction != Action.Nothing && selectedUnit is null) throw new Exception ("`playerAction is not set to `Nothing`, but `selectedUnit` is null.");
            mousePosition = GetMousePosition();
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);
            this.offsetMap(mapView);
            if (movingUnit !is null) movingUnit.stepTowards();
            BeginDrawing();

            drawTiles();
            foreach (uint gridx, row; this.grid) {
                foreach (uint gridy, tile; row) {
                    if (playerAction == Action.Move && selectedUnit.getDistance(gridx,gridy).reachable) {
                        DrawRectangleRec(tile.getRect(offset), Color(60, 240, 120, 30));
                        debug DrawTextureEx(arrow, Vector2(cast(float)(gridx*TILEWIDTH+32), cast(float)(gridy*TILEWIDTH+32)), cast(float)selectedUnit.getDistance(gridx,gridy).directionTo.getAngle, 1.0f, Color(120, 240, 120, 60));
                        if(leftClick && CheckCollisionPointRec(mousePosition, tile.getRect(offset))) {
                            selectedUnit.move(gridx, gridy);
                            movingUnit = cast(VisibleUnit)selectedUnit;
                            playerAction = Action.Nothing;
                        }
                    } else if (playerAction == Action.Attack && selectedUnit.getDistance(gridx,gridy).attackableNow) {
                        if (tile.occupant !is null) {
                            DrawRectangleRec(tile.getRect(offset), Color(240, 60, 60, 60));
                        } else DrawRectangleRec(tile.getRect(offset), Color(200, 60, 60, 30));
                        if(leftClick && CheckCollisionPointRec(mousePosition, tile.getRect(offset))) {
                            selectedUnit.attack(gridx, gridy);
                            movingUnit = cast(VisibleUnit)selectedUnit;
                            playerAction = Action.Nothing;
                        }
                    }
                    if (CheckCollisionPointRec(mousePosition, tile.getRect(offset))) {
                        if (tile.occupant !is null) { // This should later be filtered for only enemy factions.
                            if (leftClick && playerAction == Action.Nothing) {
                                this.selectedUnit = tile.occupant;
                                this.selectedUnit.updateDistances;
                                if (updateOnClick) this.selectedUnit.updateDistances();
                            }
                            if (this.selectedUnit !is null) {
                                if (this.selectedUnit.getDistance(gridx, gridy).reachable) {
                                    DrawRectangleRec(tile.getRect(offset), Color(100, 100, 245, 32));
                                }
                            }
                        } /*else {
                            if(playerAction == Action.Move && leftClick && selectedUnit.getDistance(gridx,gridy).reachable) {
                                selectedUnit.move(gridx, gridy);
                                movingUnit = cast(VisibleUnit)selectedUnit;
                                playerAction = Action.Nothing;
                            }
                        }*/
                        if (!onButton) DrawRectangleRec(tile.getRect(offset), Colours.Highlight);
                    }
                }
            }
            if (selectedUnit !is null) DrawRectangleRec((cast(VisibleTile)selectedUnit.currentTile).rect, Colours.Highlight);
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
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
                        if (finishButton.button(onButton)) break;
                    } version (raygui) {
                        if (GuiButton(finishButton, "Finish turn".toStringz)) break;
                    }
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
        Color shade;
        foreach (VisibleUnit unit; this.allUnits) {
            Vector2 destination = unit.position;
            destination += offset + Vector2(0, -24);
            if (this.phase==GamePhase.PlayerTurn && unit.hasActed) shade = Color(200,200,200,200);
            else shade = Colors.WHITE;
            DrawTextureV(unit.sprite, destination, shade);
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