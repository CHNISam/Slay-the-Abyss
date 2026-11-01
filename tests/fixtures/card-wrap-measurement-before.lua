-- Frozen pre-optimization fit from 8fe960ff; exact output-equivalence oracle only.
local Theme=require("abyss_theme")
local M={}
local function units(text)
    local n=0
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        n=n+(#ch>1 and 1 or ch:match('[ilI.,:;! ]') and .35 or ch:match('[MW]') and .9 or .65)
    end
    return n
end
-- Mirror native wrapping: Latin/digit runs break only at spaces, closing CJK
-- punctuation never starts a line and opening punctuation never ends one.
-- Treating every glyph as a free break point under-counted lines, so long
-- dynamic bodies (e.g. 格挡反击「（当前 N 点）」) passed fit and were clipped.
local closing={['，']=1,['。']=1,['、']=1,['；']=1,['：']=1,['）']=1,['」']=1,['！']=1,['？']=1,['》']=1,
    [',']=1,['.']=1,[')']=1,[';']=1,[':']=1,['!']=1,['?']=1}
local opening={['（']=1,['「']=1,['《']=1,['(']=1}
local function atoms(text)
    local out,glue={},false
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local word=#ch==1 and ch:match('[%w%+%-%%]')
        local last=out[#out]
        if ch=='\n' or ch==' ' then out[#out+1]=ch;glue=false
        elseif type(last)=='table' and (glue or closing[ch] or word and last.word) then
            last.text=last.text..ch;last.word=word and last.word;glue=opening[ch]~=nil
        else out[#out+1]={text=ch,word=word};glue=opening[ch]~=nil end
    end
    return out
end
local function lines(text,width,font)
    local count,used=1,0
    for _,atom in ipairs(atoms(text:gsub('<[^>]+>',''))) do
        if atom=='\n' then count=count+1;used=0
        elseif atom==' ' then used=used+units(' ')*font
        else
            local advance=units(atom.text)*font
            if used>0 and used+advance>width then count=count+1;used=0 end
            while advance>width do count=count+1;advance=advance-width end
            used=used+advance
        end
    end
    return count
end
function M.fit(text,maximum,width,height,lineScale,advance)
    for font=maximum,Theme.font.minimum,-1 do
        if lines(text,width/(advance or 1),font)*font*(lineScale or 1.3)<=height then return font,true end
    end
    return Theme.font.minimum,false
end
return M.fit
