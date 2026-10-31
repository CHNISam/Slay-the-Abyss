// Translate resolved production text settings to simulator text-box properties.
export function simTextProperties(text,argb) {
 return {adaptiveFontSize:text.autoSize===true,text:text.content,fontSize:text.fontSize,minimumFontSize:text.minFontSize??text.fontSize,
  fontColor:argb(text.colour),bgColor:0,enableOutline:false,
  horizontalAlignment:text.align==='left'?'Left':'Middle',verticalAlignment:text.valign==='top'?'Top':'Middle'};
}
