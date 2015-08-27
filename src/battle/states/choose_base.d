module battle.states.choose_base;

import std.range;
import std.random;
import std.algorithm : filter, minPos;
import std.container : Array;
import dau;
import dtiled;
import jsonizer;
import battle.battle;
import battle.entities;

/// Player is holding a wall segment they can place with a mouse click
class ChooseBase : BattleState {
  private RowCol       _currentCoord;
  private Array!RowCol _reactorCoords;

  override {
    void enter(Battle battle) {
      super.enter(battle);
      _reactorCoords = Array!RowCol(battle.map
        .allCoords
        .filter!(x => battle.map.tileAt(x).hasReactor));

      _currentCoord = _reactorCoords.front;
      selectReactor(battle, _currentCoord);
    }

    void onCursorMove(Battle battle, Vector2f direction) {
      auto dist(RowCol coord) { return _currentCoord.manhattan(coord); }

      // try to pick the closest reactor in the direction the cursor was moved
      auto res = _reactorCoords[]
        .filter!(x => x != _currentCoord)
        .filter!(coord =>
          (direction.y < 0 && (coord.row - _currentCoord.row) < 0) ||
          (direction.y > 0 && (coord.row - _currentCoord.row) > 0) ||
          (direction.x < 0 && (coord.col - _currentCoord.col) < 0) ||
          (direction.x > 0 && (coord.col - _currentCoord.col) > 0))
        .minPos!((a,b) => dist(a) < dist(b));

      if (!res.empty) {
        // clear walls from previous selection
        foreach(coord ; battle.data.getWallCoordsForReactor(_currentCoord)) {
          battle.map.clear(coord);
        }

        selectReactor(battle, res.front);
      }
    }

    void onConfirm(Battle battle) {
      // mark all tiles in area surrounding the selection as enclosed
      foreach(tile ; battle.map.enclosedTiles!(x => x.hasWall)(_currentCoord, Diagonals.yes)) {
        tile.isEnclosed = true;
      }

      // base is chosen, end this state
      battle.states.pop();
    }
  }

  private void selectReactor(Battle battle, RowCol reactorCoord) {
    // set walls for new selection
    _currentCoord = reactorCoord;

    // place walls around new base
    foreach(coord ; battle.data.getWallCoordsForReactor(_currentCoord)) {
      battle.map.place(new Wall, coord);
    }

    // The walls need to evaluate their sprites
    foreach(coord ; battle.data.getWallCoordsForReactor(_currentCoord)) {
      battle.map.regenerateWallSprite(coord);
    }
  }
}