local D=require("abyss_card_display")
for _,text in ipairs({"伤害 ，","伤害\n，","伤害 ！","text .","伤害）","（伤害）"}) do
 local size,fits=D.fit(text,22,100,100)
 assert(type(size)=="number" and size>=12 and type(fits)=="boolean",text)
end
print("CARD_TEXT_PUNCTUATION_PASS 6")
