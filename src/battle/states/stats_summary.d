module battle.states.stats_summary;

import std.math      : pow;
import std.conv      : to;
import std.format    : format;
import std.container : Array;
import dau;
import battle.battle;
import constants;
import transition;

private enum {
  fontName  = "Mecha",
  fontSize  = 24,
  textDepth = 5,

  titleStartPos = Vector2i(320, -100),
  titleEndPos   = Vector2i(320, 100),

  // where text enters relative to its destination
  labelStartOffset = Vector2i(-500, 0),
  valueStartOffset = Vector2i(500, 0),

  // where text entries stay near the center of the screen
  firstLabelPos = Vector2i(320, 200),
  firstValuePos = Vector2i(480, 200),

  tickerMargin = Vector2i(0, 100), // space between score tickers

  slideDuration  = 1, // time for text to slide into place
  tickerDuration = 2, // time for ticker to count to score
  holdDuration   = 2, // how long to display scores before exiting

  // this represents position relative to the transition progress (0 to 1)
  transitionFn = (float x) => x.pow(0.25),

  // max opacity with which to dim the background
  backgroundOpacity = 0.5f,
  backgroundDepth = 4
}

/// Play a short animation before entering the next phase
class StatsSummary : BattleState {
  private {
    ScoreTicker[] _tickers;
    Font          _font;
    SoundEffect   _tickSound;
    Bitmap        _background;

    const string                        _titleText;
    Transition!(Vector2i, transitionFn) _titlePos;
    Transition!(float,    transitionFn) _backgroundOpacity;
  }

  this(Battle battle, int currentRound) {
    _font = battle.game.fonts.get(fontName, fontSize);
    _tickSound = battle.game.audio.getSound("score_ticker");
    _titlePos.initialize(titleStartPos, slideDuration);

    _titleText = "Round %d Summary:".format(currentRound);

    _background = Bitmap(al_create_bitmap(screenW, screenH));
    al_set_target_bitmap(_background);
    al_clear_to_color(Color.black);
    al_set_target_backbuffer(battle.game.display.display);

    _backgroundOpacity.initialize(0, slideDuration);
  }

  ~this() {
    al_destroy_bitmap(_background);
  }

  override {
    void enter(Battle battle) {
      super.enter(battle);

      _titlePos.go(titleEndPos);
      _backgroundOpacity.go(backgroundOpacity);

      _tickers ~= ScoreTicker(
          "Territory:",
          battle.player.statsThisRound.territoryScore,
          firstLabelPos + tickerMargin * 0,
          firstValuePos + tickerMargin * 0);

      _tickers ~= ScoreTicker(
          "Reactors:",
          battle.player.statsThisRound.reactorScore,
          firstLabelPos + tickerMargin * 1,
          firstValuePos + tickerMargin * 1);

      _tickers ~= ScoreTicker(
          "Destruction:",
          battle.player.statsThisRound.destructionScore,
          firstLabelPos + tickerMargin * 2,
          firstValuePos + tickerMargin * 2);

      _tickers ~= ScoreTicker(
          "Total:",
          battle.player.statsThisRound.totalScore,
          firstLabelPos + tickerMargin * 3,
          firstValuePos + tickerMargin * 3);

      battle.game.events.sequence(
        slideDuration , &startTickingScores,
        tickerDuration, &doneTickingScores ,
        holdDuration  , &slideOut,
        slideDuration , () => battle.states.pop()
      );
    }

    void run(Battle battle) {
      super.run(battle);
      auto game = battle.game;

      _titlePos.update(game.deltaTime);
      _backgroundOpacity.update(game.deltaTime);

      dimBackground(battle.game.renderer);

      // update and draw the ticker text entries
      auto batch = TextBatch(_font, textDepth);

      drawTitleText(batch);

      foreach(ref ticker ; _tickers) {
        ticker.update(game.deltaTime);
        ticker.draw(batch);

        battle.game.renderer.draw(batch);
      }
    }
  }

  private void startTickingScores() {
    _tickSound.play();
    foreach(ref ticker ; _tickers) ticker.startTickingScore();
  }

  private void doneTickingScores() {
    _tickSound.stop();
  }

  private void slideOut() {
    foreach(ref ticker ; _tickers) ticker.exitScreen();
    _titlePos.reverse();
    _backgroundOpacity.reverse();
  }

  private void drawTitleText(ref TextBatch batch) {
    Text text;

    text.transform.pos = _titlePos.value;
    text.color = Color.white;
    text.text = _titleText;

    batch ~= text;
  }

  private void dimBackground(Renderer renderer) {
    Sprite sprite;
    sprite.region = Rect2i(0, 0, screenW, screenH);
    sprite.color  = Color(0, 0, 0, _backgroundOpacity.value);

    auto batch = SpriteBatch(_background, backgroundDepth);
    batch ~= sprite;
    renderer.draw(batch);
  }
}

private:
struct ScoreTicker {
  const string                        _label; // identifies the value
  const int                           _scoreTarget;
  Transition!int                      _scoreValue; // ticks up from 0 to over time
  Transition!(Vector2i, transitionFn) _labelPos;
  Transition!(Vector2i, transitionFn) _scorePos;

  this(string label, int score, Vector2i labelTopLeft, Vector2i valueTopLeft) {
    _label = label;
    _scoreTarget = score;

    _labelPos.initialize(labelTopLeft + labelStartOffset, slideDuration);
    _labelPos.go(labelTopLeft);

    _scorePos.initialize(valueTopLeft + valueStartOffset, slideDuration);
    _scorePos.go(valueTopLeft);

    _scoreValue.initialize(0, tickerDuration);
  }

  void startTickingScore() { _scoreValue.go(_scoreTarget); }

  void exitScreen() {
    _labelPos.reverse();
    _scorePos.reverse();
  }

  void update(float timeElapsed) {
    _scoreValue.update(timeElapsed);
    _labelPos.update(timeElapsed);
    _scorePos.update(timeElapsed);
  }

  void draw(ref TextBatch batch) {
    Text labelText, valueText;

    labelText.color = Color.white;
    valueText.color = Color.white;

    labelText.transform = _labelPos.value;
    valueText.transform = _scorePos.value;

    labelText.text = _label;
    valueText.text = _scoreValue.value.to!string;

    batch ~= labelText;
    batch ~= valueText;
  }
}