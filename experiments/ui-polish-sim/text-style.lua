-- Preserve runtime overrides, including explicit false, before falling back to
-- the production layout. The simulator must not inherit seed text sizing.
return function(control,spec,hex)
 local autoSize=control.adaptiveFontSize
 if autoSize==nil then autoSize=spec.text.autoSize end
 return {content=control.text,fontSize=control.fontSize or spec.text.fontSize,
  minFontSize=control.minimumFontSize or spec.text.minFontSize,autoSize=autoSize,
  colour=hex(control.fontColor)or spec.text.colour,align=spec.text.align,valign=spec.text.valign}
end
