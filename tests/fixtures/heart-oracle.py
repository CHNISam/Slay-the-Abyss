"""Pinned319009 A0 CorruptHeart method interpreter, independent of product Lua.

Only the independent integer Random model is shared. Actions are source plans,
not simulated player damage, natural victories or an original-PC execution.
"""
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
Base = runpy.run_path(str(ROOT / 'tools/oracles/sts1_combat_gold.py'))['Random']


class Random(Base):
    def boolean(self):
        self.counter += 1
        a, b = self.a, self.b
        a ^= (a << 23) & ((1 << 64) - 1)
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & ((1 << 64) - 1)
        return bool((self.b + b) & 1)


def status(name, value):
    return {'op': 'gainStatus', 'status': name, 'value': value}


def build(seed):
    ai = Random(seed)
    first, move_count, buff_count, strength, last = True, 0, 0, 0, None

    def choose():
        nonlocal first, move_count, last
        ai.integer(0, 99)  # AbstractMonster.rollMove, even though num is ignored.
        if first:
            first, last = False, 'debilitate'
            return last
        if move_count % 3 == 0:
            result = 'blood_shots' if ai.boolean() else 'echo_attack'
        elif move_count % 3 == 1:
            result = 'echo_attack' if last != 'echo_attack' else 'blood_shots'
        else:
            result = 'buff'
        move_count += 1
        last = result
        return result

    move = choose()
    initial, rows = ai.snapshot(), []
    for _ in range(24):
        if move == 'debilitate':
            actions = [{'op': 'applyStatus', 'status': name, 'value': 2}
                       for name in ('vulnerable', 'weak', 'frail')]
            actions += [{'op': 'heartStatusDraw', 'card': name, 'value': 1}
                        for name in ('dazed', 'slimed', 'wound', 'burn', 'void')]
        elif move == 'blood_shots':
            actions = [{'op': 'damage', 'value': 2, 'times': 12}]
        elif move == 'echo_attack':
            actions = [{'op': 'damage', 'value': 40}]
        else:
            base = max(0, -strength) + 2
            extra = [('artifact', 2), ('beat_of_death', 1), ('painful_stabs', -1),
                     ('strength', 10)][buff_count] if buff_count < 4 else ('strength', 50)
            actions = [status('strength', base), status(*extra)]
            strength += base + (extra[1] if extra[0] == 'strength' else 0)
            buff_count += 1
        next_move = choose()
        rows.append({'intent': move, 'actions': actions, 'aiAfterRoll': ai.snapshot(),
                     'moveCount': move_count, 'buffCount': buff_count})
        move = next_move
    return {'seed': str(seed), 'initialAi': initial, 'steps': rows,
            'nextIntent': move, 'finalAi': ai.snapshot()}


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


if __name__ == '__main__':
    import sys
    result = [build(seed) for seed in ('0', '1', '42', '-1', '9223372036854775807', '-9223372036854775808')]
    print('-- Independent fixed319009 source plans only.\nreturn ' + lua(result)
          if '--lua' in sys.argv else json.dumps(result, indent=2))
