#!/usr/bin/env python3
"""Read-only, standard-library card presentation renderer. No game integration.

Usage: python tools/render_traveler_cards.py SOURCE OVERLAY [--output DISPLAY]
Source upgrade uses shallow field replacement, never recursive list merging.
Overlay: {"locale":"zh-CN","cards":{"id":{"name":...,"textTemplate":...,
"upgradeTextTemplate":...}}}. Only numeric source paths and {cost} interpolate.
"""
import argparse
import json
import math
from pathlib import Path
import re
import sys


class PresentationError(ValueError):
    """Invalid or ambiguous presentation input."""


def require(condition, message):
    if not condition:
        raise PresentationError(message)


def object_fields(value, allowed, required, label):
    require(isinstance(value, dict), f'{label}: expected object')
    require(not (set(value) - allowed), f'{label}: unknown fields {sorted(set(value) - allowed)}')
    require(required <= set(value), f'{label}: missing fields {sorted(required - set(value))}')


def nonempty(value, label):
    require(isinstance(value, str) and bool(value.strip()), f'{label}: expected nonempty string')


def numeric(value):
    return type(value) is int or (type(value) is float and math.isfinite(value))


def cost_label(card):
    require(type(card.get('cost')) is int and card['cost'] >= 0, 'cost: expected nonnegative integer')
    require(card.get('costMode') in (None, 'all_energy'), 'unknown costMode contract')
    if card.get('costMode') == 'all_energy':
        require(card['cost'] == 0, 'all_energy requires zero stored cost')
        return 'X'
    return str(card['cost'])


PATH = re.compile(r'(?:cost|effects\.(?:0|[1-9][0-9]*)(?:\.then\.(?:0|[1-9][0-9]*))*\.(?:value|times))\Z')
TOKEN = re.compile(r'\{([^{}]+)\}')


def render_template(template, card):
    nonempty(template, 'template')
    literal = TOKEN.sub('', template)
    require('{' not in literal and '}' not in literal, 'malformed template braces')
    require(not any(c.isdecimal() for c in literal), 'numeric literals must come from source placeholders')

    def replace(match):
        path = match.group(1)
        require(PATH.fullmatch(path) is not None, f'illegal placeholder: {path}')
        if path == 'cost':
            return cost_label(card)
        value = card
        for segment in path.split('.'):
            if isinstance(value, list):
                require(segment.isdecimal() and int(segment) < len(value), f'out-of-range placeholder: {path}')
                value = value[int(segment)]
            else:
                require(isinstance(value, dict) and segment in value, f'unresolved placeholder: {path}')
                value = value[segment]
        require(numeric(value), f'placeholder is not finite numeric data: {path}')
        return str(value)

    return TOKEN.sub(replace, template)


def semantics(value):
    """Numeric edits can reuse prose; structural or categorical edits cannot."""
    if numeric(value):
        return '<numeric>'
    if isinstance(value, list):
        return [semantics(v) for v in value]
    if isinstance(value, dict):
        return {k: semantics(v) for k, v in value.items() if k not in {'upgrade', 'text', 'upgradeText'}}
    return value


CARD_FIELDS = {'id','name','sts_name','cost','effects','upgrade','text','upgradeText',
               'type','rarity','condition','exhaust','innate','ethereal','costMode'}
UPGRADE_FIELDS = {'cost','effects','condition','exhaust','innate','ethereal','costMode'}


# Deliberately bounded to the normalized first-pool source contract. A new op
# needs an explicit review rather than silently producing plausible prose.
KNOWN_OPS = {
    'damage', 'block', 'damageAll', 'applyStatus', 'applyStatusAll',
    'gainStatus', 'gainStatusPerTurn', 'gainTemporaryStrength',
    'addCardToDiscard', 'damageEqualToBlock', 'exhaustRandom', 'exhaustChoose',
    'draw', 'putOnDrawPile', 'blockPerTurn', 'noDrawThisTurn', 'loseHp',
    'energy', 'conditional', 'doubleBlock', 'increaseDamageThisCombat',
    'healEqualToDamageDealt',
}


def validate_effects(effects):
    require(isinstance(effects, list), 'effects: expected array')
    for effect in effects:
        object_fields(effect, {'op','value','times','status','card','if','then'}, {'op'}, 'effect')
        require(isinstance(effect['op'], str) and effect['op'] in KNOWN_OPS, 'unknown effect operation')
        for key in ('value', 'times'):
            if key in effect:
                require(numeric(effect[key]), f'effect.{key}: expected finite number')
        for key in ('status', 'card', 'if'):
            if key in effect:
                nonempty(effect[key], f'effect.{key}')
        if effect['op'] == 'conditional':
            require('if' in effect and 'then' in effect, 'conditional requires if and then')
        else:
            require('if' not in effect and 'then' not in effect, 'unexpected conditional fields')
        if 'then' in effect:
            validate_effects(effect['then'])


def render_cards(source, overlay):
    require(isinstance(source, dict) and isinstance(source.get('cards'), list), 'source.cards: expected array')
    object_fields(overlay, {'locale','cards'}, {'locale','cards'}, 'overlay')
    require(overlay['locale'] == 'zh-CN', 'unsupported locale')
    require(isinstance(overlay['cards'], dict), 'overlay.cards: expected ID-keyed object')
    cards = source['cards']
    ids = []
    for card in cards:
        object_fields(card, CARD_FIELDS, {'id','name','cost','effects'}, 'source card')
        nonempty(card['id'], 'source id')
        nonempty(card['name'], 'source name')
        validate_effects(card['effects'])
        ids.append(card['id'])
    require(len(ids) == len(set(ids)), 'duplicate source card ID')
    require(set(ids) == set(overlay['cards']), f'card ID mismatch: missing={sorted(set(ids)-set(overlay["cards"]))}, unknown={sorted(set(overlay["cards"])-set(ids))}')
    result = []
    for card in cards:
        identity = card['id']
        presentation = overlay['cards'][identity]
        try:
            object_fields(presentation, {'name','textTemplate','upgradeTextTemplate'}, {'name','textTemplate'}, 'card overlay')
            nonempty(presentation['name'], 'display name')
            upgrade = card.get('upgrade', {})
            object_fields(upgrade, UPGRADE_FIELDS, set(), 'upgrade')
            upgraded = {**card, **upgrade}
            validate_effects(upgraded['effects'])
            upgrade_template = presentation.get('upgradeTextTemplate')
            if upgrade_template is None:
                require('upgradeTextTemplate' not in presentation, 'upgradeTextTemplate cannot be null')
                require(semantics(card) == semantics(upgraded), 'semantic upgrade requires upgradeTextTemplate')
                upgrade_template = presentation['textTemplate']
            result.append({'id': identity, 'name': presentation['name'],
                           'cost': cost_label(card), 'text': render_template(presentation['textTemplate'], card),
                           'upgradeCost': cost_label(upgraded), 'upgradeText': render_template(upgrade_template, upgraded)})
        except PresentationError as exc:
            raise PresentationError(f'{identity}: {exc}') from exc
    return {'locale': overlay['locale'], 'cards': result}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'duplicate JSON key: {key}')
        result[key] = value
    return result


def load_json(path):
    with Path(path).open(encoding='utf-8') as stream:
        return json.load(stream, object_pairs_hook=unique_object,
                         parse_constant=lambda value: (_ for _ in ()).throw(PresentationError(f'invalid JSON number: {value}')))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('overlay', type=Path)
    parser.add_argument('--output', type=Path, help='Optional display JSON destination; default stdout')
    args = parser.parse_args(argv)
    try:
        if args.output is not None:
            for path in (args.source, args.overlay):
                require(args.output.resolve() != path.resolve(), 'output must not overwrite either input')
                require(not (args.output.exists() and path.exists() and args.output.samefile(path)), 'output must not alias either input')
        result = render_cards(load_json(args.source), load_json(args.overlay))
        text = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        if args.output is None:
            # Pipes on Windows may otherwise inherit an ASCII/ANSI encoding.
            if hasattr(sys.stdout, 'reconfigure'):
                sys.stdout.reconfigure(encoding='utf-8')
            sys.stdout.write(text)
        else:
            args.output.write_text(text, encoding='utf-8')
        return 0
    except (PresentationError, OSError, ValueError, RecursionError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
