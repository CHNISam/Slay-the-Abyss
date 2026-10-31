import test from 'node:test';
import assert from 'node:assert/strict';
import {nodeLayout} from '../scripts/node-ui-layout.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
test('Neow native image encoding keeps RGB and explicit alpha',()=>{
 const event=nodeLayout().controls[0].children.find(c=>c.name==='eventView');
 const figure=event.children.find(c=>c.name==='neowFigure');
 for(const c of figure.children) assert.match(c.colour,/^#[0-9a-f]{6}$/i);
 assert.equal(figure.children.find(c=>c.name==='shade').opacity,192/255);
 assert.equal(figure.children.find(c=>c.name==='scene').opacity,1);
 assert.equal(event.children.find(c=>c.name==='bubble').opacity,242/255);
});
test('four readable Neow options fit below dialogue inside the canvas',()=>{
 const n=nativeTheme.layout.nativeNode.event.neow,o=n.options;
 const highest=o.bottom+3*o.spacing+o.size[1]/2;
 assert.ok(n.bubble[1]-n.bubble[3]/2>highest);
 assert.ok(o.bottom-o.size[1]/2>=-nativeTheme.canvas.base[1]/2);
 assert.ok(o.spacing>o.size[1]);
 assert.ok(o.title[1]-o.title[3]/2>=o.description[1]+o.description[3]/2);
 assert.ok(o.title[1]+o.title[3]/2<=o.size[1]/2);
 assert.ok(o.description[1]-o.description[3]/2>=-o.size[1]/2);
});
