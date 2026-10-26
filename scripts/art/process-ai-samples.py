"""Two user-supplied art samples; orchestrates the existing upstream APIs only."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SAMPLES = {
    'lumine': {'file': 'lumine_geo_portrait.png', 'crop': [250, 40, 880, 800],
               'size': [252, 304], 'budget': 768},
    'starfall': {'file': 'starfall_sword_art.png', 'crop': [20, 400, 1420, 1022],
                 'size': [288, 128], 'budget': 256},
    'lumine-face': {'file': 'lumine_geo_portrait.png', 'crop': [570, 190, 790, 390],
                    'size': [88, 80], 'budget': 256},
}


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def assemble_card_art(frame_scene, art_scene):
    """Flatten art into the existing slot without promoting its local backgrounds."""
    frame_scene = frame_scene.model_copy(deep=True)
    insert_at = next(i for i, e in enumerate(frame_scene.elements) if e.id == 'attack-art-panel') + 1
    art = []
    # The pinned Lua/GIA exporters sort backgrounds before zIndex, stably.
    # Resolve that order locally BEFORE clearing flags: a background can have
    # a higher zIndex than foreground art. It must not escape behind the card.
    for e in sorted(art_scene.elements, key=lambda e: (0 if e.isBackground else 1, e.zIndex)):
        e = e.model_copy(deep=True)
        e.isBackground = False
        e.id = 'art-' + e.id
        e.x, e.y, e.width, e.height = 18 + e.x / 2, 48 + e.y / 2, e.width / 2, e.height / 2
        if e.luaMask:
            e.luaMask.offsetX /= 2
            e.luaMask.offsetY /= 2
            e.luaMask.width /= 2
            e.luaMask.height /= 2
        art.append(e)
    frame_scene.elements[insert_at:insert_at] = art
    for i, e in enumerate(frame_scene.elements):
        e.zIndex = i
    return frame_scene


def fit(args):
    from PIL import Image
    import cv2
    sys.path.insert(0, str(args.primitive.resolve()))
    import primitive_backend
    import fill_shaper
    import lua_export
    task_temp = ROOT / 'build/ai-art/tmp'
    task_temp.mkdir(parents=True, exist_ok=True)
    tempfile.tempdir = str(task_temp)
    spec = SAMPLES[args.asset]
    out = ROOT / 'art/processed/ai-samples' / args.asset / args.route
    out.mkdir(parents=True, exist_ok=True)
    source = ROOT / 'art/source' / spec['file']
    image = Image.open(source).convert('RGB')
    original_size = image.size
    if args.route in ('B', 'B2'):
        image = image.crop(spec['crop']).resize(tuple(spec['size']), Image.Resampling.LANCZOS)
        # Finite palette lowers low-contrast texture competition while preserving the source composition.
        image = image.quantize(colors=48, method=Image.Quantize.MEDIANCUT).convert('RGB')
        count = spec['budget']
    else:
        image.thumbnail((192, 192), Image.Resampling.LANCZOS)
        count = 256
    image.save(out / 'input.png')
    config = {'num_primitives': count, 'allowed_shapes': ['circle'],
              'detail_scale': 1, 'workers': 4, 'transparent_output': False}
    started = time.perf_counter()
    fitted = primitive_backend.fit_image_with_primitive(cv2.imread(str(out / 'input.png')), config)
    seconds = time.perf_counter() - started
    width, height = image.size
    elements = fill_shaper.results_to_elements(fitted['results'], 1, (width / 2, height / 2), output_alpha=1)
    result = {'mode': 'fill', 'image_size': {'width': width, 'height': height},
              'config': {'pixel_per_unit': 1, **config}, 'elements': elements}
    save_json(out / 'fit.raw.json', result)
    cv2.imwrite(str(out / 'fit.preview.png'), fitted['preview'])
    adapted = copy.deepcopy(result)
    for element in adapted['elements']:
        element['center']['y'] += height  # Existing documented upstream coordinate adapter.
    (out / 'primitive.lua').write_text(lua_export.build_lua_export_text(adapted, image_name=args.asset), encoding='utf-8')
    save_json(out / 'recipe.json', {'asset': args.asset, 'route': args.route,
        'source': str(source.relative_to(ROOT)), 'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'originalSize': original_size, 'crop': spec['crop'] if args.route == 'B' else None,
        'inputSize': image.size, 'palette': 48 if args.route == 'B' else None,
        'config': config, 'fitSeconds': seconds, 'controls': len(elements),
        'randomSeed': 'upstream clock seed; exact refit is nondeterministic'})
    print(f'{args.asset}/{args.route}: {len(elements)} controls; {seconds:.2f}s', flush=True)


def export(args):
    sys.path.insert(0, str(args.editor.resolve() / 'backend'))
    from app import main as editor
    from app import lua_scene
    out = ROOT / 'art/processed/ai-samples' / args.asset / args.route
    primitive_path = out / 'primitive.lua'
    if args.route == 'B2':
        primitive_path = out.parent / 'B/primitive.lua'
        out.mkdir(parents=True, exist_ok=True)
    imported = editor.import_scene(editor.ImportRequest(sourceType='lua',
        content=primitive_path.read_text(encoding='utf-8'), sourceName=args.asset + '-' + args.route))
    scene = imported.scene
    patch_scene = None
    if args.route == 'B2':
        assert args.asset == 'lumine'
        # Reallocate, rather than increase, the image budget: body 512 + face 256.
        scene.elements = scene.elements[:512]
        patch_path = ROOT / 'art/processed/ai-samples/lumine-face/B/primitive.lua'
        patch_scene = editor.import_scene(editor.ImportRequest(sourceType='lua',
            content=patch_path.read_text(encoding='utf-8'))).scene
        save_json(out/'recipe.json',{'asset':'lumine','route':'B2','source':'art/source/lumine_geo_portrait.png',
            'body':'lumine/B/primitive.lua first 512 shapes','face':'lumine-face/B/primitive.lua',
            'faceSourceCrop':[570,190,790,390],'faceCanvas':[88,80],'faceOffsetInBody':[128,60],
            'bodyBudget':512,'faceBudget':256,'whiteBases':2,'runtimeControls':939,
            'gia':'Use B/asset.gia; B2 patch clipping is Lua only'})
    original_overflow = []
    repaired = []
    w, h = scene.canvas.width, scene.canvas.height
    # Go primitive starts its alpha composition on opaque white. Preserve that base in-game.
    scene.elements.insert(0, editor.SceneElementModel(id='opaque-fit-base', name='fit white base',
        type='rectangle', x=w/2, y=h/2, width=w, height=h, color='#ffffff',
        isBackground=True, zIndex=-1))
    for element in scene.elements:
        if element.type == 'rectangle':
            continue
        angle = math.radians(element.rotation)
        # Ellipse analytical extent, not its oversized rotated rectangle.
        ex = math.hypot(element.width * math.cos(angle), element.height * math.sin(angle)) / 2
        ey = math.hypot(element.width * math.sin(angle), element.height * math.cos(angle)) / 2
        if element.x-ex < 0 or element.x+ex > w or element.y-ey < 0 or element.y+ey > h:
            original_overflow.append(element.id)
            if args.route in ('B', 'B2'):
                element.luaMask = editor.LuaMaskModel(enabled=True, imageId=100001,
                    offsetX=w/2-element.x, offsetY=h/2-element.y, width=w, height=h)
                repaired.append({'id': element.id, 'action': 'upstream_rectangular_mask',
                                 'mask': element.luaMask.model_dump()})
    if patch_scene:
        pw, ph, ox, oy = 88, 80, 128, 60
        # Preview through upstream renderers, retaining the two independently clipped canvases.
        preview_base = scene.model_copy(deep=True)
        for e in preview_base.elements: e.luaMask = None
        base_bytes = editor.export_png(editor.ExportRequest(scene=preview_base)).body
        patch_scene.elements.insert(0, editor.SceneElementModel(id='patch-white',type='rectangle',
            x=pw/2,y=ph/2,width=pw,height=ph,color='#ffffff',isBackground=True,zIndex=-1))
        patch_bytes = editor.export_png(editor.ExportRequest(scene=patch_scene)).body
        from PIL import Image
        import io
        preview = Image.open(io.BytesIO(base_bytes)).convert('RGBA')
        preview.alpha_composite(Image.open(io.BytesIO(patch_bytes)).convert('RGBA'), (ox,oy))
        preview.save(out / 'asset.png')
        patch_base = editor.SceneElementModel(id='face-base', name='face patch white base',
            type='rectangle', x=ox+pw/2, y=oy+ph/2, width=pw, height=ph, color='#ffffff')
        scene.elements.append(patch_base)
        for i, element in enumerate(patch_scene.elements):
            if element.id == 'patch-white': continue
            element.id = 'face-' + str(i)
            angle = math.radians(element.rotation)
            ex = math.hypot(element.width*math.cos(angle),element.height*math.sin(angle))/2
            ey = math.hypot(element.width*math.sin(angle),element.height*math.cos(angle))/2
            overflow = element.x-ex < 0 or element.x+ex > pw or element.y-ey < 0 or element.y+ey > ph
            element.x += ox
            element.y += oy
            if overflow:
                element.luaMask = editor.LuaMaskModel(enabled=True,imageId=100001,
                    offsetX=ox+pw/2-element.x, offsetY=oy+ph/2-element.y,width=pw,height=ph)
                repaired.append({'id': element.id, 'action': 'face_patch_mask', 'mask': element.luaMask.model_dump()})
            scene.elements.append(element)
        # The upstream PNG/GIA exporters do not support per-element Lua masks.
        # Keep B2 as a Lua candidate; B remains the portable GIA version.
        for i, e in enumerate(scene.elements): e.zIndex = i
    scene.canvas.mask.enabled = False
    request = editor.ExportRequest(scene=scene, giaGroupName='Abyss_' + args.asset + '_' + args.route)
    for extension, fn in [('json', editor.export_json), ('lua', editor.export_lua)]:
        (out / ('asset.' + extension)).write_bytes(fn(request).body)
    # GIA has a group mask; Lua uses the editor's existing per-element mask runtime instead.
    gia_scene = scene.model_copy(deep=True)
    for element in gia_scene.elements:
        element.luaMask = None
    gia_scene.canvas.mask.enabled = args.route in ('B', 'B2')
    gia_request = editor.ExportRequest(scene=gia_scene, giaGroupName=request.giaGroupName)
    for extension, fn in ([] if patch_scene else [('gia', editor.export_gia), ('png', editor.export_png)]):
        (out / ('asset.' + extension)).write_bytes(fn(gia_request).body)
    if not patch_scene: save_json(out / 'asset.gia-scene.json', gia_scene.model_dump())
    # Re-read the real exported Lua and compare runtime coordinates with the JSON export.
    data = json.loads((out / 'asset.json').read_text(encoding='utf-8'))
    roundtrip = editor.parse_lua_scene((out / 'asset.lua').read_text(encoding='utf-8'))
    assert len(roundtrip.elements) == len(scene.elements)
    for a, b in zip(roundtrip.elements, scene.elements):
        assert abs(a.x-b.x) < .02 and abs(a.y-b.y) < .02
    drawing = lua_scene.read_drawing((out / 'asset.lua').read_text(encoding='utf-8'))
    save_json(out / 'editor-edits.json', {'source': 'image-editor-webui import_scene/export_* APIs',
        'originalOverflowCount': len(original_overflow), 'edits': repaired,
        'imageControls': len(scene.elements), 'maskControls': len(repaired),
        'controls': len(scene.elements) + len(repaired), 'luaRoundtripCoordinates': True,
        'giaMode': 'overlimit upstream class15; official GIA import not yet tested',
        'inGame': 'not_tested', 'warnings': imported.warnings})
    if args.asset == 'starfall' and args.route == 'B':
        import runpy
        from PIL import Image
        import io
        existing = runpy.run_path(str(ROOT / 'scripts/art/export-card-spike.py'))
        theme = json.loads((ROOT / 'data/presentation/ui_theme.json').read_text(encoding='utf-8'))
        cards = json.loads((ROOT / 'data/cards.json').read_text(encoding='utf-8'))['cards']
        card = copy.deepcopy(next(c for c in cards if c['id'] == 'cleave'))
        presentation = json.loads((ROOT / 'data/presentation/traveler.zh-CN.json').read_text(encoding='utf-8'))['cards']['cleave']
        card['name'] = presentation['name']
        card['text'] = presentation['textTemplate'].replace('{effects.0.value}',str(card['effects'][0]['value']))
        frame = existing['native_text_height_candidate'](existing['compose'](theme, card))
        frame['elements'] = [e for e in frame['elements'] if not e['id'].startswith('geo-crystal')]
        frame_scene = editor.import_scene(editor.ImportRequest(sourceType='json',content=json.dumps(frame))).scene
        frame_scene = assemble_card_art(frame_scene, scene)
        req = editor.ExportRequest(scene=frame_scene,giaGroupName='Abyss_Starfall_Card')
        for extension,fn in [('json',editor.export_json),('lua',editor.export_lua)]:
            (out/('card.'+extension)).write_bytes(fn(req).body)
        preview = Image.open(io.BytesIO(editor.export_png(editor.ExportRequest(
            scene=editor.import_scene(editor.ImportRequest(sourceType='json',content=json.dumps(frame))).scene)).body)).convert('RGBA')
        preview.alpha_composite(Image.open(out/'asset.png').convert('RGBA').resize((144,64),Image.Resampling.LANCZOS),(18,48))
        preview.save(out/'card.png')
        save_json(out/'card-mapping.json',{'cardId':'cleave','presentationName':card['name'],
            'artSlot':[144,64],'imageControls':len(frame_scene.elements)-4,'nativeTexts':4,'maskControls':len(repaired),
            'runtimeControls':len(frame_scene.elements)+len(repaired),'mechanicsModified':False})
    print(f'{args.asset}/{args.route}: exported Lua/JSON/PNG' + ('; GIA' if not patch_scene else '; no GIA for local patch') + f'; {len(scene.elements)} image controls; {len(repaired)} masks')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['fit', 'export'])
    parser.add_argument('asset', choices=SAMPLES)
    parser.add_argument('route', choices=['A', 'B', 'B2'])
    parser.add_argument('--primitive', type=Path)
    parser.add_argument('--editor', type=Path)
    args = parser.parse_args()
    (fit if args.phase == 'fit' else export)(args)
