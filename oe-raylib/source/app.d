import std.stdio;
import std.file;
import std.json;
import raylib;
version (raygui) import raygui;
//import fluid;
import ui;

import mission;

const int screenWidth = 768;
const int screenHeight = 768;

void main()
{
	validateRaylibBinding();
	InitWindow(screenWidth, screenHeight, "Open Emblem");
	SetTargetFPS(getRefreshRate);
    version (raygui) setRayGuiStyle();

    scope(exit) CloseWindow();

    Mission mission = new Mission("../maps/test-map.json");
    mission.run();
    writeln("Mission constructor finished.");
    CloseWindow();
}

uint getRefreshRate() {
    version (FixedRefresh) {
        return 180;
    } else version (linux) {
        import x11.Xlib;
        import x11.extensions.Xrandr;
        Display* display = XOpenDisplay(null);
        int screen = DefaultScreen(display);
        XRRScreenConfiguration* config = XRRGetScreenInfo(display, XRootWindow(display, screen));
        return XRRConfigCurrentRate(config);
    }else version (Windows) {
        DEVMODE mode;
        mode.dmSize = DEVMODE.sizeof;
        EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, &mode);
        return mode.dmDisplayFrequency;
    } else version (OSX) {
        return 60;
    }
}

version (raygui) void setRayGuiStyle() {
    import raygui;
    import std.string:toStringz;
    auto fontPath = "../sprites/font/LiberationSans-Bold.ttf".toStringz;
    int zero = 0;
    GuiLoadStyle("../sprites/paperstyle.txt.rgs".toStringz);
    GuiSetFont(FontSet.getDefault.sans_bold);
    Font font = LoadFontEx(fontPath, 16, &zero, 0);
    GuiSetStyle(_GuiControl.DEFAULT, _GuiControlProperty.BORDER_WIDTH, 1);
    GuiSetStyle(_GuiControl.DEFAULT, _GuiDefaultProperty.TEXT_SIZE, 15);
}