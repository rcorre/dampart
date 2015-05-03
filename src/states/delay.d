module states.delay;

import dau;

private enum defaultTime = 0.2f;

/// Wait for a specified amount of time
class Delay : State!Game {
  private {
    float _timer;
  }

  this(float time = defaultTime) {
    _timer = time;
  }

  override {
    void update(Game game) {
      _timer -= game.deltaTime;

      if (_timer <= 0) {
        game.states.pop();
      }
    }
  }
}

