-- Generated from production-25d.json. Original native geometry; not PNG fitting.
local M = {}
local LAYERS = {
  {name="01-air",drift=0,speed=0,shapes={
    {1,"cold-night",640,360,1500,880,0,"#171f2b",255},
    {2,"distant-haze",840,260,1100,560,0,"#52606b",12},
    {2,"amber-halo",1035,290,460,450,0,"#e3b866",4},
    {2,"amber-halo-core",1035,290,260,310,0,"#e3b866",4},
    {2,"mist-north",380,158,710,21,0,"#84939d",12},
    {2,"mist-north-fray",520,173,440,9,0,"#84939d",12},
    {2,"mist-east",1060,204,540,18,0,"#84939d",12},
    {2,"mist-east-fray",1140,219,300,7,0,"#84939d",12},
    {2,"mist-valley",600,346,1100,36,0,"#84939d",12},
  }},
  {name="02-distant-mountains",drift=2.2,speed=0.13,shapes={
    {3,"ridge-west",120,325,430,355,-10,"#344553",255},
    {3,"ridge-west-shoulder",300,364,410,235,8,"#344553",255},
    {3,"ridge-north",578,332,560,370,7,"#3b4d59",255},
    {3,"ridge-north-edge",695,370,350,245,-13,"#344753",255},
    {3,"ridge-east",1150,325,470,440,9,"#3a4b55",255},
    {3,"ridge-east-shoulder",935,379,350,220,-9,"#3b4d58",255},
    {3,"lit-facet-west",88,327,120,290,-10,"#41525c",255},
    {3,"lit-facet-north",550,332,138,315,7,"#4a5c65",255},
    {3,"lit-facet-north-low",705,370,80,170,-13,"#455862",255},
    {3,"lit-facet-east",1100,319,115,330,9,"#50616a",255},
    {1,"valley-floor",640,465,1500,175,0,"#2d3d49",255},
    {2,"low-cloud",650,401,1370,71,0,"#62737b",35},
    {2,"low-cloud-inner",530,422,1100,25,0,"#76878d",15},
    {3,"near-ridge-west-a",64,446,300,145,-14,"#273642",255},
    {3,"near-ridge-west-b",285,467,270,101,15,"#273642",255},
    {3,"near-ridge-east-a",1197,445,260,166,8,"#273642",255},
    {3,"near-ridge-east-b",1005,478,290,86,-7,"#273642",255},
    {2,"valley-fog-west",342,415,780,25,0,"#8d9a9b",12},
    {2,"valley-fog-east",1000,421,650,17,0,"#8d9a9b",11},
  }},
  {name="03-sealed-gate",drift=4.0,speed=0.15,shapes={
    {1,"gate-terrace-shadow",1012,486,374,35,0,"#161f29",255},
    {1,"terrace-front",1012,470,352,24,0,"#46505a",255},
    {1,"terrace-rim",1010,455,338,7,0,"#738080",255},
    {1,"upper-step-front",1010,445,290,20,0,"#515a60",255},
    {1,"upper-step-rim",1007,434,292,5,0,"#858b86",255},
    {1,"portal-cavity",1014,322,192,215,0,"#18232e",255},
    {1,"inner-amber-shadow",1014,323,126,185,0,"#a87937",15},
    {1,"threshold",1011,425,181,7,0,"#c5ad79",255},
    {1,"lintel-shadow",1016,214,299,27,0,"#293640",255},
    {1,"lintel-face",1003,200,296,27,0,"#7b8078",255},
    {1,"lintel-top-edge",1003,185,297,5,0,"#a3a18c",255},
    {1,"lintel-lower-edge",1004,215,281,5,0,"#414c52",255},
    {1,"lintel-right-return",1157,203,12,29,0,"#4e5a5d",255},
    {1,"lintel-inlay",1003,199,240,2,0,"#e3b866",145},
    {1,"crown-base",1004,177,195,12,0,"#666f6c",255},
    {1,"crown-edge",1004,169,196,3,0,"#aaa58b",255},
    {1,"crown-stone",1005,144,55,39,0,"#6c7672",255},
    {1,"crown-diamond",1005,146,26,26,45,"#bda875",255},
    {1,"crown-recess",1005,146,16,16,45,"#35444a",255},
    {1,"left-plinth-dark",894,421,75,23,0,"#26333c",255},
    {1,"left-plinth",890,410,76,16,0,"#737b74",255},
    {1,"left-shaft",890,319,52,169,0,"#697571",255},
    {1,"left-shadow-return",914,319,12,169,0,"#3b4a50",255},
    {1,"left-lit-edge",868,319,4,169,0,"#a4a58d",255},
    {1,"left-inner-recess",887,321,20,139,0,"#45595c",255},
    {1,"left-inset-gold",887,321,2,125,0,"#e3b866",130},
    {1,"left-capital-shadow",893,235,74,15,0,"#3b4b50",255},
    {1,"left-capital",890,224,79,15,0,"#8c9181",255},
    {1,"left-capital-glint",887,216,76,3,0,"#b1ac91",255},
    {1,"left-masonry-joint-0",890,269,47,2,0,"#3a4a4f",255},
    {1,"left-masonry-joint-1",890,319,47,2,0,"#3a4a4f",255},
    {1,"left-masonry-joint-2",890,369,47,2,0,"#3a4a4f",255},
    {1,"left-relief-0",890,279,29,2,0,"#879083",255},
    {1,"left-relief-1",876,291,2,25,0,"#879083",255},
    {1,"left-relief-2",890,303,29,2,0,"#879083",255},
    {1,"left-relief-3",904,293,2,22,0,"#879083",255},
    {1,"left-relief-4",895,284,17,2,0,"#879083",255},
    {1,"left-relief-5",902,279,2,12,0,"#879083",255},
    {1,"right-plinth-dark",1126,421,75,23,0,"#26333c",255},
    {1,"right-plinth",1122,410,76,16,0,"#737b74",255},
    {1,"right-shaft",1122,319,52,169,0,"#697571",255},
    {1,"right-shadow-return",1146,319,12,169,0,"#3b4a50",255},
    {1,"right-lit-edge",1100,319,4,169,0,"#a4a58d",255},
    {1,"right-inner-recess",1119,321,20,139,0,"#45595c",255},
    {1,"right-inset-gold",1119,321,2,125,0,"#e3b866",130},
    {1,"right-capital-shadow",1125,235,74,15,0,"#3b4b50",255},
    {1,"right-capital",1122,224,79,15,0,"#8c9181",255},
    {1,"right-capital-glint",1119,216,76,3,0,"#b1ac91",255},
    {1,"right-masonry-joint-0",1122,269,47,2,0,"#3a4a4f",255},
    {1,"right-masonry-joint-1",1122,319,47,2,0,"#3a4a4f",255},
    {1,"right-masonry-joint-2",1122,369,47,2,0,"#3a4a4f",255},
    {1,"right-relief-0",1122,279,29,2,0,"#879083",255},
    {1,"right-relief-1",1108,291,2,25,0,"#879083",255},
    {1,"right-relief-2",1122,303,29,2,0,"#879083",255},
    {1,"right-relief-3",1136,293,2,22,0,"#879083",255},
    {1,"right-relief-4",1127,284,17,2,0,"#879083",255},
    {1,"right-relief-5",1134,279,2,12,0,"#879083",255},
    {1,"seal-aura",1012,301,69,69,45,"#e3b866",12},
    {1,"seal-outer",1012,301,47,47,45,"#e3b866",255},
    {1,"seal-cutout",1012,301,41,41,45,"#28373c",255},
    {1,"seal-inner",1012,301,18,18,45,"#f0b850",255},
    {1,"seal-hanging-ray",1012.0,253.5,29.0,1,90.0,"#e3b866",100},
    {1,"seal-falling-ray",1012.0,360.0,50.0,1,90.0,"#e3b866",90},
    {1,"west-wall",117,436,250,77,0,"#37454b",255},
    {1,"west-wall-top",113,397,256,7,0,"#66716b",255},
    {1,"wall-joint-0",45,425,80,2,0,"#273740",255},
    {1,"wall-joint-1",169,452,97,2,0,"#273740",255},
    {1,"wall-joint-2",74,469,115,2,0,"#273740",255},
    {1,"weathered-lintel0",951.5,191.5,11.402,1.3,37.875,"#394a4e",210},
    {1,"weathered-lintel1",954.0,200.0,10.77,1.3,111.801,"#394a4e",210},
    {1,"weathered-lintel2",960.0,208.5,17.464,1.3,23.629,"#394a4e",210},
    {1,"weathered-right-capital0",1131.5,221.5,10.296,1.3,119.055,"#394a4e",210},
    {1,"weathered-right-capital1",1134.5,228.5,12.083,1.3,24.444,"#394a4e",210},
    {1,"weathered-left-plinth0",877.5,409.0,12.042,1.3,41.634,"#394a4e",210},
    {1,"weathered-left-plinth1",879.0,416.0,8.485,1.3,135.0,"#394a4e",210},
  }},
  {name="04-seal-terrace",drift=6,speed=0.17,shapes={
    {1,"ground",640,636,1530,330,0,"#232d36",255},
    {2,"terrace-shadow",639,538,1000,173,0,"#111d27",190},
    {2,"disc-front",639,515,937,134,0,"#3c454b",255},
    {2,"disc-gold-weather",639,508,929,125,0,"#706d59",255},
    {2,"disc-rim",639,501,942,123,0,"#92917a",255},
    {2,"disc-surface",639,498,922,112,0,"#4e5b5e",255},
    {2,"inset-ring",639,498,805,91,0,"#837f67",255},
    {2,"inset-surface",639,498,793,87,0,"#435358",255},
    {1,"seal-arc-00",992.291,501.65,10.407,1.2,135.456,"#e3b866",115},
    {1,"seal-arc-01",970.885,510.746,26.794,1.2,165.17,"#e3b866",115},
    {1,"seal-arc-02",926.86,518.974,43.034,1.2,172.055,"#e3b866",115},
    {1,"seal-arc-03",863.219,525.772,56.626,1.2,175.307,"#e3b866",115},
    {1,"seal-arc-04",784.298,530.678,66.473,1.2,177.411,"#e3b866",115},
    {1,"seal-arc-05",695.474,533.357,71.858,1.2,179.069,"#e3b866",115},
    {1,"seal-arc-06",602.802,533.626,72.399,1.2,-179.408,"#e3b866",115},
    {1,"seal-arc-07",512.597,531.467,68.059,1.2,-177.801,"#e3b866",115},
    {1,"seal-arc-08",431.006,527.028,59.144,1.2,-175.833,"#e3b866",115},
    {1,"seal-arc-09",363.59,520.61,46.297,1.2,-172.939,"#e3b866",115},
    {1,"seal-arc-10",314.942,512.652,30.518,1.2,-167.325,"#e3b866",115},
    {1,"seal-arc-11",288.378,503.695,13.653,1.2,-147.951,"#e3b866",115},
    {1,"seal-arc-12",285.709,494.35,10.407,1.2,-44.544,"#e3b866",115},
    {1,"seal-arc-13",307.115,485.254,26.794,1.2,-14.83,"#e3b866",115},
    {1,"seal-arc-14",351.14,477.026,43.034,1.2,-7.945,"#e3b866",115},
    {1,"seal-arc-15",414.781,470.228,56.626,1.2,-4.693,"#e3b866",115},
    {1,"seal-arc-16",493.702,465.322,66.473,1.2,-2.589,"#e3b866",115},
    {1,"seal-arc-17",582.526,462.643,71.858,1.2,-0.931,"#e3b866",115},
    {1,"seal-arc-18",675.198,462.374,72.399,1.2,0.592,"#e3b866",115},
    {1,"seal-arc-19",765.403,464.533,68.059,1.2,2.199,"#e3b866",115},
    {1,"seal-arc-20",846.994,468.972,59.144,1.2,4.167,"#e3b866",115},
    {1,"seal-arc-21",914.41,475.39,46.297,1.2,7.061,"#e3b866",115},
    {1,"seal-arc-22",963.058,483.348,30.518,1.2,12.675,"#e3b866",115},
    {1,"seal-arc-23",989.622,492.305,13.653,1.2,32.049,"#e3b866",115},
    {1,"stone-seam-0",1054.663,510.37,50.422,1.5,2.25,"#293b43",255},
    {1,"stone-seam-1",937.887,533.868,36.68,1.5,9.001,"#293b43",255},
    {1,"stone-seam-2",690.696,547.636,10.116,1.5,51.726,"#293b43",255},
    {1,"stone-seam-3",353.168,535.285,35.156,1.5,170.23,"#293b43",255},
    {1,"stone-seam-4",228.109,512.374,49.858,1.5,177.356,"#293b43",255},
    {1,"stone-seam-5",245.283,478.143,47.829,1.5,-176.191,"#293b43",255},
    {1,"stone-seam-6",410.253,455.701,28.541,1.5,-166.283,"#293b43",255},
    {1,"stone-seam-7",719.014,448.877,12.483,1.5,-39.021,"#293b43",255},
    {1,"stone-seam-8",984.837,468.414,42.186,1.5,-6.443,"#293b43",255},
    {1,"amber-fracture-0-0",235.5,502.0,29.069,1.7,-3.945,"#e3b866",180},
    {1,"amber-fracture-0-1",257.0,504.0,15.232,1.7,23.199,"#e3b866",180},
    {1,"amber-fracture-0-2",278.0,506.0,28.071,1.7,-4.086,"#e3b866",180},
    {1,"amber-fracture-1-0",972.5,488.0,23.77,1.7,165.379,"#e3b866",180},
    {1,"amber-fracture-1-1",950.0,489.5,22.204,1.7,-172.235,"#e3b866",180},
    {1,"amber-fracture-1-2",928.5,491.0,21.84,1.7,164.055,"#e3b866",180},
    {1,"amber-fracture-2-0",726.0,537.0,23.409,1.7,-160.017,"#e3b866",180},
    {1,"amber-fracture-2-1",718.0,529.5,9.22,1.7,-49.399,"#e3b866",180},
    {1,"amber-fracture-2-2",710.0,523.5,22.561,1.7,-167.196,"#e3b866",180},
    {2,"lower-atmosphere",640,690,1570,220,0,"#151e29",130},
  }},
  {name="05-broken-column",drift=9,speed=0.19,shapes={
    {2,"column-ground-shadow",144,529,317,57,0,"#111c26",210},
    {1,"column-foot-shadow",135,506,150,31,0,"#253039",255},
    {1,"column-foot",126,489,141,30,0,"#70786f",255},
    {1,"column-foot-top",124,471,141,9,0,"#979987",255},
    {1,"column-foot-side",195,487,17,31,0,"#424f50",255},
    {1,"broken-shaft",123,367,87,202,0,"#747f76",255},
    {1,"shaft-shadow",161,371,19,194,0,"#3e5053",255},
    {1,"shaft-lit-edge",82,367,7,200,0,"#a4a691",255},
    {1,"shaft-inset",117,372,30,172,0,"#536865",255},
    {1,"shaft-inner-line",107,374,3,163,0,"#a09b76",255},
    {3,"fracture-top",119,267,87,29,180,"#a3a58c",255},
    {3,"fracture-shadow",148,266,40,25,180,"#384d50",255},
    {1,"shaft-neck",118,281,96,13,0,"#8b9481",255},
    {1,"shaft-gold-crack-a",120.0,295.0,27.785,2,59.744,"#e3b866",255},
    {1,"shaft-gold-crack-b",122.0,316.0,20.591,2,119.055,"#e3b866",255},
    {1,"shaft-gold-crack-c",121.0,338.5,28.16,1.5,73.496,"#e3b866",255},
    {1,"shaft-joint-0",120,339,73,2,0,"#394e50",255},
    {1,"shaft-joint-1",120,403,73,2,0,"#394e50",255},
    {1,"shaft-joint-2",120,451,73,2,0,"#394e50",255},
    {1,"fallen-capital",34,450,100,38,-17,"#69766f",255},
    {1,"fallen-capital-face",39,457,87,20,-17,"#455952",255},
    {1,"fallen-capital-rim",31,432,112,9,-17,"#929a84",255},
    {1,"rubble-a",248,518,62,22,-12,"#465754",255},
    {1,"rubble-lit-a",246,509.2,55.18,3,-12,"#7e8675",255},
    {3,"rubble-shadow-a",269.7,518,21.7,22,78,"#2b4045",255},
    {1,"rubble-b",289,525,37,14,9,"#465754",255},
    {1,"rubble-lit-b",287,519.4,32.93,3,9,"#7e8675",255},
    {3,"rubble-shadow-b",301.95,525,12.95,14,99,"#2b4045",255},
    {1,"rubble-c",69,535,44,19,-5,"#465754",255},
    {1,"rubble-lit-c",67,527.4,39.16,3,-5,"#7e8675",255},
    {3,"rubble-shadow-c",84.4,535,15.4,19,85,"#2b4045",255},
    {1,"rubble-d",1188,537,93,31,8,"#465754",255},
    {1,"rubble-lit-d",1186,524.6,82.77,3,8,"#7e8675",255},
    {3,"rubble-shadow-d",1220.55,537,32.55,31,98,"#2b4045",255},
    {1,"rubble-e",1251,524,51,23,-13,"#465754",255},
    {1,"rubble-lit-e",1249,514.8,45.39,3,-13,"#7e8675",255},
    {3,"rubble-shadow-e",1268.85,524,17.85,23,77,"#2b4045",255},
    {2,"mote-halo-0",242,330,15,15,0,"#e3b866",15},
    {1,"mote-0",242,330,3,3,45,"#e3b866",210},
    {2,"mote-halo-1",322,401,10,10,0,"#e3b866",15},
    {1,"mote-1",322,401,2,2,45,"#e3b866",210},
    {2,"mote-halo-2",818,352,15,15,0,"#e3b866",15},
    {1,"mote-2",818,352,3,3,45,"#e3b866",210},
    {2,"mote-halo-3",1055,380,15,15,0,"#e3b866",15},
    {1,"mote-3",1055,380,3,3,45,"#e3b866",210},
    {2,"mote-halo-4",1170,298,10,10,0,"#e3b866",15},
    {1,"mote-4",1170,298,2,2,45,"#e3b866",210},
    {2,"mote-halo-5",191,435,15,15,0,"#e3b866",15},
    {1,"mote-5",191,435,3,3,45,"#e3b866",210},
    {2,"mote-halo-6",768,426,10,10,0,"#e3b866",15},
    {1,"mote-6",768,426,2,2,45,"#e3b866",210},
    {2,"mote-halo-7",936,238,10,10,0,"#e3b866",15},
    {1,"mote-7",936,238,2,2,45,"#e3b866",210},
  }},
}
local function activate(control)
  control:SetActive(true)
  control:SetVisible(true)
  control:SetAnchorMin(0.5, 0.5)
  control:SetAnchorMax(0.5, 0.5)
  control:SetPivot(0.5, 0.5)
  control:SetLocalScale(1, 1, 1)
  control:SetLocalRotation(0, 0, 0)
  control:SetAnchoredPosition(0, 0)
end
function M.new(root, hostTemplate, imageTemplate, options)
  assert(root and hostTemplate and imageTemplate, 'production-25d: root and template IDs required')
  local mode=(options and options.mode) or 'parallax'
  assert(mode=='static' or mode=='parallax', 'production-25d: mode must be static or parallax')
  local self = {hosts={}, phase=0, built=false, primitiveCount=0, containerCount=0, mode=mode}
  function self:clear()
    -- Runtime scene switches only. The engine owns destruction during OnDestroy.
    for i=#self.hosts,1,-1 do game.DestroyClientUIControl(self.hosts[i]) end
    self.hosts={}; self.built=false; self.phase=0
    self.primitiveCount=0; self.containerCount=0
  end
  function self:show()
    if self.built then return end
    local ok, err = pcall(function()
      for _, layer in ipairs(LAYERS) do
        local holder=assert(game.InstantiateClientUIControl(hostTemplate,root))
        self.hosts[#self.hosts+1]=holder
        activate(holder); holder:SetSizeDelta(1280,720)
        self.containerCount=self.containerCount+1
        local bucket
        for i,s in ipairs(layer.shapes) do
          -- Dynamic child containers keep each sibling group below 60 controls.
          if (i-1)%48==0 then
            bucket=assert(game.InstantiateClientUIControl(hostTemplate,holder))
            activate(bucket); bucket:SetSizeDelta(1280,720)
            self.containerCount=self.containerCount+1
          end
          local image=assert(game.InstantiateClientUIControl(imageTemplate,bucket))
          image:SetImage(Enum.ImageSource.StaticReference,100000+s[1])
          activate(image)
          image:SetSizeDelta(s[5],s[6])
          image:SetAnchoredPosition(s[3]-640,360-s[4])
          image:SetLocalRotation(0,0,-s[7])
          local c=s[8]
          image.imageColor=Color.FromRGBA(tonumber(c:sub(2,3),16),tonumber(c:sub(4,5),16),tonumber(c:sub(6,7),16),s[9])
          image:SetAsLastSibling()
          self.primitiveCount=self.primitiveCount+1
        end
      end
      self.built=true
    end)
    if not ok then self:clear(); error('production-25d build failed: '..tostring(err)) end
    print('PRODUCTION_25D_READY primitives='..self.primitiveCount..' containers='..self.containerCount..' layers='..#self.hosts..' mode='..self.mode)
  end
  function self:update(dt)
    if not self.built or self.mode=='static' then return end
    self.phase=self.phase+math.max(0,math.min(dt or 0,0.1))
    for i,h in ipairs(self.hosts) do
      local l=LAYERS[i]
      h:SetAnchoredPosition(math.sin(self.phase*l.speed)*l.drift,0)
    end
  end
  return self
end
return M
