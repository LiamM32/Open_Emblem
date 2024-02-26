module unit;

import std.stdio;
import std.conv;

import map;

class Unit {
    private Map map;
    private int xlocation;
    private int ylocation;
    
    static ubyte lookahead = 1;
    
    private string name;
    private uint Mv;
    private bool isFlyer = false;
    
    private TileAccess[][] distances;

    this(string name, Map map, short Mv) {
        this.map = map;
        this.distances.length = map.getWidth;
        foreach(ref row; this.distances) {
            row.length = map.getLength;
        }
        
        this.name = name;
        this.Mv = Mv;
    }
    
    void setLocation(int x, int y) {
        this.xlocation = x;
        this.ylocation = y;
        
        writeln(this.name ~ " location: " ~ to!string(x) ~ ", " ~ to!string(y));
        
        this.map.getTile(x, y).occupant = this;
        
        foreach(ref row; this.distances) {
            foreach(ref tile; row) {
                tile.distance = 0;
                tile.reachable = false;
                tile.measured = false;
            }
        }
        
        this.updateDistances(0, x, y);
        
        writeln(this.distances);
    }
    
    private void updateDistances(uint distancePassed, int x, int y) {
        if ((x < 0) || (y < 0) || (x > this.map.getWidth) || (y > this.map.getLength)) return;
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer)) return;
        writeln("Made it here");
        if (this.distances[x][y].measured && this.distances[x][y].distance <= distancePassed) return;
        else if (this.distances[x][y].distance <= this.Mv) this.distances[x][y].reachable = true;
        
        this.distances[x][y].distance = distancePassed;
        this.distances[x][y].measured = true;
        
        distancePassed += this.map.getTile(x, y).stickyness;
        
        if (distancePassed <= this.Mv * this.lookahead -2) {
            this.updateDistances(distancePassed +2, x-1, y);
            this.updateDistances(distancePassed +2, x, y+1);
            this.updateDistances(distancePassed +2, x+1, y);
            this.updateDistances(distancePassed +2, x, y-1);
            
            if (distancePassed <= this.Mv * this.lookahead -3) {
                this.updateDistances(distancePassed +3, x-1, y-1);
                this.updateDistances(distancePassed +3, x-1, y+1);
                this.updateDistances(distancePassed +3, x+1, y+1);
                this.updateDistances(distancePassed +3, x+1, y-1);
            }
        }
    }
}

struct TileAccess
{
    uint distance;
    bool reachable = false;
    bool measured = false;
}
