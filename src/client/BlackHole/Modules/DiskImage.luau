--!native
--!optimize 2

local Config = require(script.Parent.Config)
local Color = require(script.Parent.Color)
local DiskTexture = require(script.Parent.DiskTexture)
local MeshUtil = require(script.Parent.MeshUtil)
local Geodesics = require(script.Parent.Geodesics)

local sin, cos, acos, sqrt = math.sin, math.cos, math.acos, math.sqrt
local max, min, clamp = math.max, math.min, math.clamp
local TAU = math.pi * 2

local D = Config.D
local R_IN, R_OUT = Config.RIn, Config.ROut
local BRIGHT, FALLOFF = Config.Brightness, Config.BrightnessFalloff
local BEAM, COLOR_SHIFT = Config.DopplerBeaming, Config.DopplerColor
local TEMP_INNER = Config.DiskTempInner
local LOOP, INNER_REVS = Config.LoopSeconds, Config.InnerRevolutions

local NRG = Geodesics.NRG
local TEX_ROWS, TEX_COLS, ROW_H = DiskTexture.Rows, DiskTexture.Cols, DiskTexture.RowHeight
local TEMP_MIN, TEMP_MAX, TEMP_STEPS = Color.TempMin, Color.TempMax, Color.Steps
local TONE_SCALE, TONE_MAX = Color.ToneScale, Color.ToneMax

local DiskImage = {}

function DiskImage.new(ctx, k, rings, cols, offset)
	local mesh = MeshUtil.newMesh(24)
	local count = rings * cols

	local init = table.create(count, Vector3.zero)
	for ir = 0, rings - 1 do
		for ia = 0, cols - 1 do
			local a = ia / cols * TAU
			init[ir * cols + ia + 1] = Vector3.new(cos(a) * (1 + ir) * 0.3, sin(a) * (1 + ir) * 0.3, 0)
		end
	end
	local vertexIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, init)
	mesh:BatchAdd(Enum.MeshAttribute.Face, MeshUtil.gridFaces(vertexIds, rings, cols))

	local img = {
		k = k,
		mesh = mesh,
		rings = rings,
		cols = cols,
		count = count,
		vertexIds = vertexIds,
		colorIds = MeshUtil.colorIdsOf(mesh, vertexIds),
		offset = offset,
		scale = (D - offset) / D,
		geo = ctx.geo,
		tex = ctx.tex,

		positions = table.create(count, Vector3.zero),
		colors = table.create(count, Color3.new()),
		lightR = table.create(count, 0),
		lightG = table.create(count, 0),
		lightB = table.create(count, 0),

		radiusIndex = {},
		omega = {},
		redshift = {},
		intensity = {},
		temp = {},

		sinA = {},
		cosA = {},

		startCol = table.create(count, 0),
		speed = table.create(count, 0),
		texRow = table.create(count, 0),
	}

	for ia = 0, cols - 1 do
		local a = ia / cols * TAU
		img.sinA[ia + 1], img.cosA[ia + 1] = sin(a), cos(a)
	end

	for ir = 0, rings - 1 do
		local r = R_IN + (R_OUT - R_IN) * (ir / (rings - 1)) ^ 1.7

		local fadeIn = clamp((r - R_IN) / 0.7, 0, 1)
		fadeIn = fadeIn * fadeIn * (3 - 2 * fadeIn)
		local fadeOut = clamp((R_OUT - r) / 4, 0, 1)
		fadeOut = fadeOut * fadeOut * (3 - 2 * fadeOut)

		img.radiusIndex[ir + 1] = (r - R_IN) / (R_OUT - R_IN) * NRG
		img.omega[ir + 1] = r ^ -1.5
		img.redshift[ir + 1] = sqrt(1 - 3 / r)
		img.intensity[ir + 1] = BRIGHT * (R_IN / r) ^ FALLOFF * 0.95 * fadeIn * fadeOut
		img.temp[ir + 1] = TEMP_INNER * (R_IN / r) ^ 0.75

		local texRow = min(((r - R_IN) / ROW_H) // 1, TEX_ROWS - 1)
		local rowRadius = R_IN + (texRow + 0.5) * ROW_H
		local revs = max(1, (INNER_REVS * (R_IN / rowRadius) ^ 1.5 + 0.5) // 1)

		for ia = 0, cols - 1 do
			local i = ir * cols + ia + 1
			img.startCol[i] = (ia / cols) * TEX_COLS
			img.speed[i] = revs * TEX_COLS / LOOP
			img.texRow[i] = texRow * (TEX_COLS + 1) + 1
		end
	end

	mesh:BatchSetValues(img.colorIds, img.colors)
	img.part = MeshUtil.makePart(mesh, ctx.folder, "DiskImage" .. k)
	return img
end

local SAMPLES = 384
local sampleRings = { NRG * 0.05, NRG * 0.35, NRG * 0.8 }
local sampleX = table.create((SAMPLES + 1) * 3, 0)
local sampleY = table.create((SAMPLES + 1) * 3, 0)
local cumulative = table.create(SAMPLES + 1, 0)
local segLen = {}

local function redistribute(img, cosE, sinE)
	local diskImpact = img.geo.diskImpact
	local odd = img.k % 2 == 1
	local base = (img.k // 2) * TAU
	local cols, rings = img.cols, img.rings

	for j = 0, SAMPLES do
		local a = j / SAMPLES * TAU
		local sa, ca = sin(a), cos(a)
		local psi = acos(clamp(cosE * sa, -1, 1))
		local phi = odd and (base + TAU - psi) or (base + psi)

		local sx, sy = ca, -sinE * sa
		local len = sqrt(sx * sx + sy * sy)
		if len < 1e-6 then
			sx, sy, len = 1, 0, 1
		end
		sx /= len
		sy /= len
		if odd then
			sx, sy = -sx, -sy
		end

		for q = 1, 3 do
			local rp = MeshUtil.planeRadius(diskImpact(phi, sampleRings[q]))
			sampleX[j * 3 + q], sampleY[j * 3 + q] = sx * rp, sy * rp
		end
	end

	local total = 0
	cumulative[0] = 0
	for j = 0, SAMPLES - 1 do
		local s = 0
		for q = 1, 3 do
			local dx = sampleX[(j + 1) * 3 + q] - sampleX[j * 3 + q]
			local dy = sampleY[(j + 1) * 3 + q] - sampleY[j * 3 + q]
			s += sqrt(dx * dx + dy * dy)
		end
		segLen[j] = s
		total += s
	end

	local minWeight = 0.12 * total / SAMPLES
	local acc = 0
	for j = 0, SAMPLES - 1 do
		acc += segLen[j] + minWeight
		cumulative[j + 1] = acc
	end

	local sinA, cosA, startCol = img.sinA, img.cosA, img.startCol
	local j = 0
	for ia = 0, cols - 1 do
		local target = ia / cols * acc
		while j < SAMPLES - 1 and cumulative[j + 1] < target do
			j += 1
		end
		local span = cumulative[j + 1] - cumulative[j]
		local f = span > 1e-9 and (target - cumulative[j]) / span or 0
		local a = (j + f) / SAMPLES * TAU
		sinA[ia + 1], cosA[ia + 1] = sin(a), cos(a)

		local col = (a / TAU) * TEX_COLS
		for ir = 0, rings - 1 do
			startCol[ir * cols + ia + 1] = col
		end
	end
end

function DiskImage.project(img, cosE, sinE)
	redistribute(img, cosE, sinE)

	local diskImpact = img.geo.diskImpact
	local rings, cols = img.rings, img.cols
	local odd = img.k % 2 == 1
	local base = (img.k // 2) * TAU
	local positions, lightR, lightG, lightB = img.positions, img.lightR, img.lightG, img.lightB
	local sinA, cosA, scale = img.sinA, img.cosA, img.scale
	local lutR, lutG, lutB = Color.lutR, Color.lutG, Color.lutB

	local n = 0
	for ir = 1, rings do
		local radiusIndex, omega, redshift = img.radiusIndex[ir], img.omega[ir], img.redshift[ir]
		local i0, t0 = img.intensity[ir], img.temp[ir]

		for ia = 1, cols do
			n += 1
			local sa = sinA[ia]
			local psi = acos(clamp(cosE * sa, -1, 1))
			local b = diskImpact(odd and (base + TAU - psi) or (base + psi), radiusIndex)

			local sx, sy = cosA[ia], -sinE * sa
			local len = sqrt(sx * sx + sy * sy)
			if len < 1e-6 then
				sx, sy, len = 1, 0, 1
			end
			sx /= len
			sy /= len
			if odd then
				sx, sy = -sx, -sy
			end

			local rp = MeshUtil.planeRadius(b) * scale
			positions[n] = Vector3.new(sx * rp, sy * rp, 0)

			local denom = 1 + omega * b * cosE * sx
			if denom < 0.15 then
				denom = 0.15
			end
			local g = redshift / denom
			local inten = i0 * g ^ BEAM

			local ti = ((t0 * (1 + (g - 1) * COLOR_SHIFT) - TEMP_MIN) / (TEMP_MAX - TEMP_MIN) * (TEMP_STEPS - 1) + 0.5) // 1
			if ti < 0 then
				ti = 0
			elseif ti > TEMP_STEPS - 1 then
				ti = TEMP_STEPS - 1
			end
			ti += 1

			lightR[n], lightG[n], lightB[n] = lutR[ti] * inten, lutG[ti] * inten, lutB[ti] * inten
		end
	end

	img.mesh:BatchSetValues(img.vertexIds, positions)
end

function DiskImage.animate(img, t, azimuth)
	local lightR, lightG, lightB = img.lightR, img.lightG, img.lightB
	local startCol, speed, texRow, colors, tex = img.startCol, img.speed, img.texRow, img.colors, img.tex
	local toneTable = Color.toneTable
	local shift = -azimuth * TEX_COLS / TAU

	for i = 1, img.count do
		local col = (startCol[i] + shift + speed[i] * t) % TEX_COLS
		local c0 = col // 1
		local idx = texRow[i] + c0
		local d0 = tex[idx]
		local d = d0 + (tex[idx + 1] - d0) * (col - c0)
		local lum = d * (0.6 + 0.8 * d)

		local ri = lightR[i] * lum * TONE_SCALE // 1
		local gi = lightG[i] * lum * TONE_SCALE // 1
		local bi = lightB[i] * lum * TONE_SCALE // 1
		if ri > TONE_MAX then ri = TONE_MAX end
		if gi > TONE_MAX then gi = TONE_MAX end
		if bi > TONE_MAX then bi = TONE_MAX end

		colors[i] = Color3.new(toneTable[ri + 1], toneTable[gi + 1], toneTable[bi + 1])
	end

	img.mesh:BatchSetValues(img.colorIds, colors)
end

return DiskImage
