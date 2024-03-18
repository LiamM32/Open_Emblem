import map;
import unit;

class Faction
{
    Map map;
    string name;
    Unit[] units;
    string[] allyNames;
    Faction[] allies;
    string enemyNames;
    Faction[] enemies;
    bool isPlayer;

    this(string name, bool isPlayer=false) {
        this.name = name;
        this.isPlayer = isPlayer;
    }

    void setAlliesEnemies(ref Faction[string] factionsByName) {
        import std.conv;
        foreach (name; allyNames) {
            if (name in factionsByName) allies ~= factionsByName[name];
        }
        foreach (name; enemyNames) {
            if (name.to!string in factionsByName) enemies ~= factionsByName[name.to!string];
        }
    }

    void turnReset() {
        foreach (unit; this.units) {
            unit.turnReset();
        }
    }
}