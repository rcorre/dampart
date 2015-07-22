module states.fight_ai;

import std.math   : PI, sgn, approxEqual;
import std.array  : array;
import std.random : uniform, randomSample;
import dau;
import dtiled;
import states.battle;
import states.fight;

private enum {
  minEnemyFireCooldown = 2,
  maxEnemyFireCooldown = 5,
  enemySize = Vector2i(32,32),

  enemyAccuracy = 0.5,
  enemySpeed = 90,
  enemyRotationSpeed = 4,
  enemyRange = 240,
}

class FightAI : Fight {
  private {
    alias EnemyList = DropList!(Enemy, x => x.destroyed);

    EnemyList _enemies;
    int _round;
    RowCol[] _targets;  // coordinates enemies should target
  }

  this(Battle battle, int round) {
    super(battle);
    _round = round;
  }

  override {
    void enter(Battle battle) {
      super.enter(battle);
      // consider all tiles with walls as targets
      _targets = battle.map.allCoords.filter!(x => battle.map.tileAt(x).hasWall).array;

      _enemies = new EnemyList;

      _enemies.insert(
          battle.data
          .getEnemyWave(_round)  // get the wave data for this round
          .map!(x => Enemy(x))); // create an enemy at each location
    }

    void run(Battle battle) {
      super.run(battle);

      battle.cannonTarget = battle.game.input.mousePos;

      updateEnemies(battle);
      battle.drawEnemies(_enemies[].map!(x => x.transform));
    }

    void onProjectileExplode(Battle battle, Vector2f pos, float radius) {
      super.onProjectileExplode(battle, pos, radius);
      foreach(ref enemy ; _enemies) {
        if (enemy.pos.distance(pos) < radius) {
          enemy.destroyed = true;
        }
      }
    }
  }

  private:
  void updateEnemies(Battle battle) {
    auto game = battle.game;

    // when no enemies are left, and all projectiles are gone, end the battle
    if (_enemies.empty && super.allProjectilesExpired)
      battle.states.pop();

    foreach(ref enemy ; _enemies) {
      enemy.fireCooldown -= game.deltaTime;

      if (battle.map.tileAt(enemy.target).hasWall) {
        auto targetPos = battle.map.tileCenter(enemy.target).as!Vector2f;

        // rotate towards the target
        auto angleDiff = enemy.transform.angle - (targetPos - enemy.pos).angle;
        if (!angleDiff.approxEqual(0, 0.1)) {
          enemy.transform.angle -= angleDiff.sgn * enemyRotationSpeed * game.deltaTime;
        }

        if (enemy.pos.distance(targetPos) > enemyRange) {
          // not in range, so move towards the target
          enemy.pos.moveTo(targetPos, game.deltaTime * enemySpeed);
        }
        else if (enemy.fireCooldown < 0) {
          // in range and weapons ready, so fire!
          auto target = enemy.target;
          if (uniform(0f, 1f) > enemyAccuracy) {
            // simulate a 'miss' by targeting an adjacent tile
            target = target.adjacent(Diagonals.yes).randomSample(1).front;
          }

          enemy.fireCooldown = uniform(minEnemyFireCooldown, maxEnemyFireCooldown);
          spawnProjectile(enemy.pos, battle.map.tileCenter(target).as!Vector2f);
        }
      }
      else {
        // target tile no longer holds a wall, pick a new target
        enemy.target = _targets.randomSample(1).front;
        assert(battle.map.contains(enemy.target));
      }
    }
  }
}

private:
struct Enemy {
  Transform!float transform;
  float fireCooldown;
  RowCol target;
  bool destroyed;

  this(Vector2f position) {
    this.transform = position;
    this.fireCooldown = uniform(minEnemyFireCooldown, maxEnemyFireCooldown);
  }

  ref auto pos() { return transform.pos; }
}
