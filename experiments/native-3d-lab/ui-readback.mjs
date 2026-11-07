import {normalizeUi,equivalent,interfaceMetadata} from '../../scripts/native-candidate-audit.mjs';

// The native writer omits an empty child list. This is the empty-container
// default, not a tolerance for missing controls or other unknown fields.
export function controlsForReadback(controls,source=false){
  const normalized=normalizeUi(controls,'controls',source);
  function visit(nodes){for(const node of nodes){
    // Installed writer defaults minFontSize to 20; reader omits exactly 20.
    if(node.text?.minFontSize===20)delete node.text.minFontSize;
    if(node.children?.length===0)delete node.children;
    else if(node.children)visit(node.children);
  }}
  visit(normalized);return normalized;
}
export function uiEquivalent(expected,actual){
  return equivalent(controlsForReadback(expected.controls,true),controlsForReadback(actual.controls),'controls')
    &&equivalent(interfaceMetadata(expected),interfaceMetadata(actual));
}
