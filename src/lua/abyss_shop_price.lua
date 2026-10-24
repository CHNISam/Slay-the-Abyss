-- Merchant card arithmetic promoted from the tested TASK-13.1 candidate.
-- Conditional source contract: docs/reviews/TASK-13.1-shop-card-price-evidence.md.
local Price = {}
local floor = math.floor

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- Exact binary32 rounding for this pipeline, not a general float library.
-- Domain: zero or positive normal values in [2^-32, 256]. No subnormals,
-- negative values, infinities or NaN. Power-of-two scaling is exact in binary64.
-- A binary32 product has at most 48 significant bits, so its intermediate is
-- exact in binary64 before this nearest-even rounding. No integer bit shifts,
-- string.pack, frexp or log: compatible with Fengari's 32-bit integer model.
function Price.roundPositiveBinary32(value)
    assert(finite(value) and value >= 0 and value <= 256
        and (value == 0 or value >= 2.0^-32), 'Invalid bounded binary32 value')
    if value == 0 then return 0.0 end
    local scaled, power = value / 1.0, 1.0
    while scaled >= 2.0 do scaled = scaled / 2.0; power = power * 2.0 end
    while scaled < 1.0 do scaled = scaled * 2.0; power = power / 2.0 end
    local significand = scaled * 8388608.0
    local integer = floor(significand)
    local remainder = significand - integer
    if remainder > 0.5 or (remainder == 0.5 and integer % 2 ~= 0) then
        integer = integer + 1
    end
    return integer * (power / 8388608.0)
end

local f32 = Price.roundPositiveBinary32
local function multiply(left, right) return f32(f32(left) * f32(right)) end
local low, high = f32(0.9), f32(1.1)
local bases = { common = 50, uncommon = 75, rare = 150 }
local fields = { rarity=true, multiplier=true, phase=true, color=true,
    sale=true, courier=true, membership=true }

-- Conditional 24-bit grid mapping only, never a seed or random-number API.
function Price.multiplierFromUint24(sample)
    assert(finite(sample) and sample == floor(sample) and sample >= 0 and sample < 16777216,
        'Invalid uint24 sample')
    return f32(low + multiply(sample / 16777216.0, f32(high - low)))
end

local function default(value, fallback)
    if value == nil then return fallback end
    return value
end

function Price.quoteCard(options)
    assert(type(options) == 'table' and getmetatable(options) == nil, 'Invalid quote options')
    for key in pairs(options) do assert(fields[key], 'Unsupported quote option') end
    local rarity, multiplier = options.rarity, options.multiplier
    local phase, color = default(options.phase, 'initial'), default(options.color, 'colored')
    local sale, courier, membership = default(options.sale, false), default(options.courier, false), default(options.membership, false)
    assert(bases[rarity], 'Unsupported rarity')
    assert(phase == 'initial' or phase == 'restock', 'Unsupported phase')
    assert(color == 'colored' or color == 'colorless', 'Unsupported color')
    assert(type(sale) == 'boolean' and type(courier) == 'boolean' and type(membership) == 'boolean',
        'Invalid discount flag')
    assert(not (color == 'colorless' and (rarity == 'common' or sale)), 'Unsupported colorless rarity or sale')
    assert(not (phase == 'restock' and (not courier or sale)), 'Unsupported restock')
    assert(finite(multiplier) and multiplier >= low and multiplier <= high, 'Invalid merchant multiplier')
    local price = multiply(bases[rarity], multiplier)
    if color == 'colorless' then price = multiply(price, 1.2) end
    if phase == 'restock' then
        price = multiply(price, 0.8)
        if membership then price = multiply(price, 0.5) end
        return floor(price)
    end
    price = floor(price)
    if sale then price = floor(price / 2.0) end
    if courier then price = floor(multiply(price, 0.8) + 0.5) end
    if membership then price = floor(multiply(price, 0.5) + 0.5) end
    return price
end

function Price.discountExistingPrice(price)
    assert(finite(price) and price == floor(price) and price >= 0 and price <= 198,
        'Invalid existing card price')
    return floor(multiply(price, 0.5) + 0.5)
end

return Price
