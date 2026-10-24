local Config = require(script.Parent.Config)

local exp, log, clamp = math.exp, math.log, math.clamp

local STEPS = 256
local TEMP_MIN, TEMP_MAX = 900, 14000
local TONE_SCALE, TONE_MAX = 256, 2047

local Color = {
	Steps = STEPS,
	TempMin = TEMP_MIN,
	TempMax = TEMP_MAX,
	ToneScale = TONE_SCALE,
	ToneMax = TONE_MAX,
}

local lutR, lutG, lutB = table.create(STEPS, 0), table.create(STEPS, 0), table.create(STEPS, 0)
for i = 0, STEPS - 1 do
	local t = (TEMP_MIN + (TEMP_MAX - TEMP_MIN) * (i / (STEPS - 1))) / 100
	local r, g, b

	if t <= 66 then
		r = 255
		g = 99.4708025861 * log(t) - 161.1195681661
	else
		r = 329.698727446 * (t - 60) ^ -0.1332047592
		g = 288.1221695283 * (t - 60) ^ -0.0755148492
	end

	if t >= 66 then
		b = 255
	elseif t <= 19 then
		b = 0
	else
		b = 138.5177312231 * log(t - 10) - 305.0447927307
	end

	lutR[i + 1] = (clamp(r, 0, 255) / 255) ^ 2.2
	lutG[i + 1] = (clamp(g, 0, 255) / 255) ^ 2.2
	lutB[i + 1] = (clamp(b, 0, 255) / 255) ^ 2.2
end
Color.lutR, Color.lutG, Color.lutB = lutR, lutG, lutB

local toneTable = table.create(TONE_MAX + 1, 0)
for i = 0, TONE_MAX do
	toneTable[i + 1] = (1 - exp(-(i / TONE_SCALE) * Config.Exposure)) ^ (1 / 2.2)
end
Color.toneTable = toneTable

function Color.tone(v)
	local i = v * TONE_SCALE // 1
	if i > TONE_MAX then
		i = TONE_MAX
	elseif i < 0 then
		i = 0
	end
	return toneTable[i + 1]
end

return Color
