local defaults = {

	codeCount = 100,

	codeLength = 25,

	minimapAngle = 235,

	framePos = {
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = 0,
	},

	path = {
		LLRCA_L_DEF_GOSSIP_1,
		LLRCA_L_DEF_GOSSIP_2,
		LLRCA_L_DEF_GOSSIP_3,
	},
}

LLRCA_DEFAULTS = defaults

LLRCA_DB = LLRCA_DB or {}

if not LLRCA_DB.codeCount then
	LLRCA_DB.codeCount = defaults.codeCount
end

if not LLRCA_DB.codeLength then
	LLRCA_DB.codeLength = defaults.codeLength
end

if not LLRCA_DB.path then
	LLRCA_DB.path = {}
end

if not LLRCA_DB.framePos then
	LLRCA_DB.framePos = defaults.framePos
end

if not LLRCA_DB.minimapAngle then
	LLRCA_DB.minimapAngle = defaults.minimapAngle
end

for i, v in ipairs(defaults.path)
 do
	if not LLRCA_DB.path[i] then
		LLRCA_DB.path[i] = v
	end
end
