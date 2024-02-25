module unit;

import std.stdio;
import std.conv;

import map;

class Unit {
    private Map map;
    private int xlocation;
    private int ylocation;
    
    static ubyte lookAhead;
    
    private string name;
    private uint Mv;
    private bool isFlyer = false;
    
    private int[][] distances;

    this(string name, Map map, short Mv) {
        this.map = map;
        this.distances.length = map.getWidth;
        foreach(ref row; this.distances) {
            row.length = map.getLength;
        }
        writeln(this.distances);
        
        this.name = name;
        this.Mv = Mv;
    }
    
    void setLocation(int x, int y) {
        this.xlocation = x;
        this.ylocation = y;
        
        this.map.getTile(x, y).occupant = this;
        
        foreach(ref row; this.distances) {
            foreach(ref tile; row) {
                tile = 0;
            }
        }
        this.updateDistances(this.Mv, x, y);
        
        writeln(this.distances);
    }
    
    private void updateDistances(int remainingMovement, int x, int y) {
        if ((x < 0) || (y < 0) || (x > this.map.getWidth) || (y > this.map.getLength)) return;
        if (!this.map.getTile(x, y).allowUnit(this.isFlyer)) return;
        if (this.distances[x][y] >= remainingMovement) return;
        
        remainingMovement -= this.map.getTile(x, y).stickyness;
        this.distances[x][y] = remainingMovement;
        
        if (remainingMovement >= 2) {
            this.updateDistances(remainingMovement - 2, x-1, y);
            this.updateDistances(remainingMovement - 2, x, y+1);
            this.updateDistances(remainingMovement - 2, x+1, y);
            this.updateDistances(remainingMovement - 2, x, y-1);
            
            if (remainingMovement >= 3) {
                this.updateDistances(remainingMovement - 3, x-1, y-1);
                this.updateDistances(remainingMovement - 3, x-1, y+1);
                this.updateDistances(remainingMovement - 3, x+1, y+1);
                this.updateDistances(remainingMovement - 3, x+1, y-1);
            }
        }
    }
}
