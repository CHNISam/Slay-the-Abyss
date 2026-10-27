"""The candidate adapter reads literal upstream data, never a second exporter."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/art/assemble-native-card-samples.py'
spec = importlib.util.spec_from_file_location('candidate_art', SCRIPT)
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)

def drawing():
    return dict(format='gia', root=[0,0,144,64,.5,.5,.5,.5,.5,.5,1,1,0],
                rows=[[106057,1.125,-2.25,3.5,4.75,.5,.5,.5,.5,.5,.5,1,1,9.75]],
                rotations=[[23.125,-45.25]],imageTypes=['basic'],imageMasks=[],textboxes=[],bindings=[])

class CandidateArtTest(unittest.TestCase):
    def test_literal_adapter_retains_native_properties_without_exporting(self):
        self.assertTrue(callable(getattr(assembly,'assemble_candidate',None)), 'candidate literal adapter is missing')
        source=drawing();source['rows'][0]+=[12,34,56,78];before=copy.deepcopy(source)
        result=assembly.assemble_candidate(source,'cleave')
        self.assertEqual(source,before)
        self.assertEqual(result, [dict(image=106057,position=[1.125,-2.25],size=[3.5,4.75],pivot=[.5,.5],
            anchorMin=[.5,.5],anchorMax=[.5,.5],scale=[1,1],rotation=[23.125,-45.25,9.75],
            colour=[12,34,56,78],imageType='basic')])

    def test_candidate_rejects_other_canvas_masks_text_prefabs_and_lossy_values(self):
        self.assertTrue(callable(getattr(assembly,'assemble_candidate',None)), 'candidate literal adapter is missing')
        changes=[lambda d:d['root'].__setitem__(3,34),lambda d:d.update(textboxes=[{}]),
            lambda d:d.update(bindings=[[1,1,'prefab']]),lambda d:d.update(imageMasks=[dict(enabled=True)]),
            lambda d:d['rows'][0].__setitem__(0,999999),lambda d:d['rotations'][0].__setitem__(0,float('nan')),
            lambda d:d['rows'][0].__setitem__(17,256),lambda d:d.update(imageTypes=[])]
        for change in changes:
            source=drawing();source['rows'][0]+=[12,34,56,78];change(source)
            with self.subTest(source=source),self.assertRaises((ValueError,AssertionError)):
                assembly.assemble_candidate(source,'cleave')

    def test_registry_hashes_are_checked_before_parser_and_snapshot_is_not_an_input(self):
        self.assertTrue(callable(getattr(assembly,'read_candidate_registry',None)), 'candidate registry reader is missing')
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory);lua=folder/'a.lua';scene=folder/'a.json'
            lua.write_text('literal\n-- 编辑器回导数据\nSNAPSHOT SHOULD NOT BE PARSED');scene.write_text('{"canvas":{"width":144,"height":64},"elements":[{"type":"image"}]}')
            entry=dict(cardId='cleave',lua=str(lua),json=str(scene),luaSha256=hashlib.sha256(lua.read_bytes()).hexdigest(),jsonSha256=hashlib.sha256(scene.read_bytes()).hexdigest())
            registry=folder/'registry.json';registry.write_text(json.dumps(dict(schemaVersion=1,assets=[entry])))
            calls=[]
            def read(text):
                calls.append(text);d=drawing();d['rows'][0]+=[12,34,56,78];return d
            result=assembly.read_candidate_registry(registry,read)
            self.assertEqual(calls,['literal\n'])
            self.assertEqual(result['assets']['cleave']['luaSha256'],entry['luaSha256'])
            lua.write_text('changed')
            with self.assertRaisesRegex(ValueError,'hash'):assembly.read_candidate_registry(registry,read)
            self.assertEqual(len(calls),1)

if __name__=='__main__':unittest.main()
