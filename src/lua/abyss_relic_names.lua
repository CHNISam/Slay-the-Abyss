-- Project display translations, not an implementation or availability catalog.
-- Canonical source translations take priority, with authored Chinese fallback.
-- Only SacredBark/Darkstone
-- names were independently checked against the STS1 Chinese community wiki.
local M={}
local names={
 ['Whetstone']='磨刀石',['Boot']='靴子',['Blood Vial']='血瓶',MealTicket='餐券',['Pen Nib']='钢笔尖',Akabeko='赤牛',
 Lantern='启程灯',['Regal Pillow']='皇家枕头',['Bag of Preparation']='备战袋',['Ancient Tea Set']='古茶具',
 ['Smiling Mask']='微笑面具',['Potion Belt']='药水腰带',PreservedInsect='昆虫标本',Omamori='护符',MawBank='聚财罐',
 ['Art of War']='兵法',['Toy Ornithopter']='玩具扑翼机',CeramicFish='陶鱼',Vajra='裂岩杵',['Centennial Puzzle']='百年积木',
 Strawberry='草莓',['Happy Flower']='快乐小花',['Oddly Smooth Stone']='光滑岩片',['War Paint']='战纹涂料',
 ['Bronze Scales']='铜鳞',['Juzu Bracelet']='念珠',['Dream Catcher']='捕梦网',Nunchaku='双节棍',['Tiny Chest']='小宝箱',
 Orichalcum='奥利哈钢',Anchor='石锚',['Bag of Marbles']='弹珠袋',['Red Skull']='红头骨',
 ['Bottled Tornado']='瓶装旋风',Sundial='日晷',Kunai='苦无',Pear='梨',['Blue Candle']='蓝蜡烛',['Eternal Feather']='永恒羽毛',
 StrikeDummy='打击木偶',['Singing Bowl']='颂钵',Matryoshka='套娃',InkBottle='墨水瓶',['The Courier']='快递员',
 ['Frozen Egg 2']='冰冻胎石',['Ornamental Fan']='精致折扇',['Bottled Lightning']='瓶装闪电',['Gremlin Horn']='地精号角',
 HornCleat='系缆桩',['Toxic Egg 2']='淬毒胎石',['Letter Opener']='开信刀',['Question Card']='问号卡',['Bottled Flame']='瓶装火焰',
 Shuriken='手里剑',['Molten Egg 2']='熔火胎石',['Meat on the Bone']='带骨肉',['Darkstone Periapt']='黑石护符',
 ['Mummified Hand']='干瘪之手',Pantograph='缩放仪',['White Beast Statue']='白兽雕像',['Mercury Hourglass']='水银沙漏',
 ['Self Forming Clay']='自塑黏土',['Paper Frog']='纸蛙',Ginger='生姜',['Old Coin']='古旧钱币',['Bird Faced Urn']='鸟面瓮',
 ['Unceasing Top']='不休陀螺',Torii='鸟居',StoneCalendar='石历',Shovel='铲子',WingedGreaves='羽翼护胫',
 ['Thread and Needle']='针线',Turnip='萝卜',['Ice Cream']='冰淇淋',Calipers='卡钳',['Lizard Tail']='蜥蜴尾巴',
 ['Prayer Wheel']='转经轮',Girya='壶铃',['Dead Branch']='枯木树枝',['Du-Vu Doll']='咒术娃娃',Pocketwatch='怀表',
 Mango='芒果',['Incense Burner']='香炉',['Gambling Chip']='赌博筹码',['Peace Pipe']='宁静烟斗',CaptainsWheel='船舵',
 FossilizedHelix='螺旋化石',TungstenRod='钨钢短杖',['Magic Flower']='魔法花',["Charon's Ashes"]='卡戎之灰',
 ['Champion Belt']='冠军腰带',Sling='投石索',HandDrill='手钻',Toolbox='工具箱',['Chemical X']='化学物质零号',
 ["Lee's Waffle"]='李家华夫饼',Orrery='星系仪',DollysMirror='多利之镜',OrangePellets='橙色药丸',PrismaticShard='棱镜碎片',
 ClockworkSouvenir='齿轮纪念品',['Frozen Eye']='冻结之眼',TheAbacus='算盘',['Medical Kit']='医药箱',Cauldron='大锅',
 ['Strange Spoon']='奇怪的勺子',['Membership Card']='会员卡',Brimstone='硫磺',['Fusion Hammer']='聚变之锤',
 ['Velvet Choker']='天鹅绒颈圈',['Runic Dome']='符文圆顶',SlaversCollar='缚岩项圈',['Snecko Eye']='异蛇之眼',
 ["Pandora's Box"]='潘多拉魔盒',['Cursed Key']='诅咒钥匙',['Busted Crown']='破碎王冠',Ectoplasm='灵质',
 ['Tiny House']='小屋',Sozu='静泉竹筒',["Philosopher's Stone"]='贤者之石',Astrolabe='星盘',['Black Star']='黑星',
 SacredBark='神圣树皮',['Empty Cage']='空鸟笼',['Runic Pyramid']='符文金字塔',['Calling Bell']='召唤铃铛',
 ['Coffee Dripper']='咖啡滤杯',['Black Blood']='深燃之心',['Mark of Pain']='痛楚印记',['Runic Cube']='符文立方体',
 ['Snake Skull']='异蛇头骨',['Ninja Scroll']='忍术卷轴',['Paper Crane']='纸鹤',['Tough Bandages']='结实绷带',
 ['The Specimen']='生物标本',Tingsha='铜钹',TwistedFunnel='扭曲漏斗',WristBlade='袖剑',HoveringKite='悬浮风筝',
 ['Ring of the Serpent']='长蛇戒指',DataDisk='数据磁盘',['Symbiotic Virus']='共生病毒',Cables='镀金线缆',
 ['Emotion Chip']='情感芯片',['Runic Capacitor']='符文电容器',Inserter='机械臂',FrozenCore='冻结核心',
 ['Nuclear Battery']='核能电池',Damaru='手摇鼓',Yang='阴阳鱼',TeardropLocket='泪滴吊坠',CloakClasp='斗篷扣',
 GoldenEye='黄金眼',Melange='美琅脂',HolyWater='圣水',VioletLotus='紫色莲花',
 ['Burning Blood']='余烬之心',Circlet='头环',['Ring of the Snake']='蛇之戒指',['Cracked Core']='破损核心',['PureWater']='纯净之水',
}
local legacy={burning_blood='Burning Blood',anchor='Anchor',vajra='Vajra',bag_of_preparation='Bag of Preparation',
 lantern='Lantern',oddly_smooth_stone='Oddly Smooth Stone',bronze_scales='Bronze Scales',membership_card='Membership Card',
 courier='The Courier',smiling_mask='Smiling Mask',black_blood='Black Blood',slavers_collar='SlaversCollar',sozu='Sozu',
 black_star='Black Star',circlet='Circlet'}
local function chinese(value)return type(value)=='string' and value:find('[\228-\233]')~=nil end
function M.get(data,id)
    if type(id)~='string' then return '未知遗物' end
    for _,entry in ipairs(data and data.relics and data.relics.relics or {})do
        if entry.id==id or entry.sourceId==id or legacy[entry.id]==id then
            local sourceName=names[entry.sourceId or legacy[entry.id] or id]
            if sourceName then return sourceName end
            if chinese(entry.name) then return entry.name end
            return names[entry.sourceId or legacy[entry.id] or id] or '未知遗物'
        end
    end
    return names[legacy[id] or id] or '未知遗物'
end
return M
