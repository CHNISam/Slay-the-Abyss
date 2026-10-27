"""Independent fixed-source OrbWalker arithmetic, not original-binary execution.

No production data or Lua imports. Uses the existing Python STS Random model.
319009: OrbWalker constructor/getMove and CardGroup.addToRandomSpot.
"""
import json

from sts1_combat_gold import Random


def vector(seed):
    hp_rng, ai_rng = Random(seed), Random(seed)
    discarded, hp = hp_rng.integer(90, 96), hp_rng.integer(90, 96)
    moves, rolls = [], []
    for _ in range(5):
        roll = ai_rng.integer(0, 99)
        preferred = "claw" if roll < 40 else "laser"
        move = preferred
        if len(moves) >= 2 and moves[-2:] == [preferred, preferred]:
            move = "laser" if preferred == "claw" else "claw"
        rolls.append(roll)
        moves.append(move)
    return {"seed": str(seed), "discardedHp": discarded, "hp": hp,
            "primaryRolls": rolls, "moves": moves,
            "monsterHpCounter": hp_rng.counter, "aiCounter": ai_rng.counter}


def placement(size):
    rng = Random(1)
    position = rng.integer(0, size - 1) if size else 0
    return {"seed": "1", "originalDrawSize": size,
            "sourceInsertionIndex": position, "cardRandomCounter": rng.counter}


if __name__ == "__main__":
    print(json.dumps({"hpAndAi": [vector(seed) for seed in (1, 42, 77)],
                      "placement": [placement(size) for size in (0, 1, 2)]}, indent=2))
