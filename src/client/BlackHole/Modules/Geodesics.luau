--!native
--!optimize 2

local Config = require(script.Parent.Config)
local Loading = require(script.Parent.Loading)

local floor, sqrt, max, min = math.floor, math.sqrt, math.max, math.min
local PI = math.pi

local D = Config.D
local sqrtF = Config.SqrtF
local R_IN, R_OUT = Config.RIn, Config.ROut
local B_CRIT = Config.BCrit

local PHI_STEP = 0.025
local PHI_MAX = 3 * PI + 0.3
local STEPS = floor(PHI_MAX / PHI_STEP) + 2
local U_FAR = 1 / 800

local INV_PHI_STEP = 0.05
local RADIUS_SAMPLES = 64

local Geodesics = {
	NRG = RADIUS_SAMPLES,
}

local function buildImpactParams()
	local bMax = D / sqrtF * 0.9999
	local below = {}
	local step = 2e-4
	while B_CRIT - step > 0.05 do
		below[#below + 1] = B_CRIT - step
		step *= 1.03
	end

	local list = { 0.02 }
	for i = #below, 1, -1 do
		list[#list + 1] = below[i]
	end

	step = 2e-4
	while B_CRIT + step < bMax - 0.05 do
		list[#list + 1] = B_CRIT + step
		step *= 1.03
	end
	list[#list + 1] = bMax
	return list
end

local function accel(u)
	return -u + 3 * u * u
end

local function traceRays(params)
	local count = #params
	local radii = buffer.create(count * STEPS * 4)
	local state = table.create(count, 2)
	local phiOut = table.create(count, 0)
	local h = PHI_STEP

	for ib = 1, count do
		local b = params[ib]
		local u = 1 / D
		local v = sqrt(max(1 / (b * b) - u * u * (1 - 2 * u), 0))
		local base = (ib - 1) * STEPS * 4
		buffer.writef32(radii, base, D)

		local k = 1
		while k < STEPS do
			local k1u = v
			local k1v = accel(u)
			local k2u = v + 0.5 * h * k1v
			local k2v = accel(u + 0.5 * h * k1u)
			local k3u = v + 0.5 * h * k2v
			local k3v = accel(u + 0.5 * h * k2u)
			local k4u = v + h * k3v
			local k4v = accel(u + h * k3u)

			local nu = u + h / 6 * (k1u + 2 * k2u + 2 * k3u + k4u)
			local nv = v + h / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)

			if nu >= 0.5 then
				state[ib] = 0
				break
			elseif nu <= U_FAR and nv < 0 then
				state[ib] = 1
				local frac = (u - U_FAR) / (u - nu)
				phiOut[ib] = (k - 1 + frac) * h + math.asin(min(1, b * U_FAR))
				for q = k, STEPS - 1 do
					buffer.writef32(radii, base + q * 4, 1e9)
				end
				break
			end

			u, v = nu, nv
			buffer.writef32(radii, base + k * 4, 1 / nu)
			k += 1
		end

		if ib % 8 == 0 then
			Loading.progress(ib / count * 0.25)
			Loading.yieldIfSlow()
		end
	end

	return radii, state, phiOut
end

local function buildEscapeLookup(params, state, phiOut)
	local impact, angle = {}, {}
	for ib = 1, #params do
		if state[ib] == 1 then
			impact[#impact + 1] = params[ib]
			angle[#angle + 1] = phiOut[ib]
		end
	end
	local n = #impact

	return function(phi)
		if phi > angle[1] or phi < angle[n] then
			return nil
		end
		local lo, hi = 1, n
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if angle[mid] >= phi then
				lo = mid
			else
				hi = mid
			end
		end
		local p0, p1 = angle[lo], angle[hi]
		local t = (p0 - p1) > 1e-9 and (p0 - phi) / (p0 - p1) or 0
		return impact[lo] + (impact[hi] - impact[lo]) * t
	end
end

local function buildDiskLookup(params, radii)
	local count = #params
	local phiRows = (STEPS - 1) // 2
	local rowStride = (RADIUS_SAMPLES + 1) * 4
	local grid = buffer.create((phiRows + 1) * (RADIUS_SAMPLES + 1) * 4)

	local function radiusAt(ib, ip)
		return buffer.readf32(radii, ((ib - 1) * STEPS + ip) * 4)
	end

	for j = 1, phiRows do
		local ip = j * 2
		for q = 0, RADIUS_SAMPLES do
			local target = R_IN + (R_OUT - R_IN) * q / RADIUS_SAMPLES
			local lo, hi = 1, count
			while hi - lo > 1 do
				local mid = (lo + hi) // 2
				if radiusAt(mid, ip) >= target then
					hi = mid
				else
					lo = mid
				end
			end

			local rl, rh = radiusAt(lo, ip), radiusAt(hi, ip)
			local b
			if rl > 0 and rh < 1e8 and rh > rl then
				b = params[lo] + (target - rl) / (rh - rl) * (params[hi] - params[lo])
			elseif rh < 1e8 then
				b = params[hi]
			else
				b = 0.5 * (params[lo] + params[hi])
			end
			buffer.writef32(grid, (j * (RADIUS_SAMPLES + 1) + q) * 4, b)
		end

		if j % 6 == 0 then
			Loading.progress(0.25 + j / phiRows * 0.10)
			Loading.yieldIfSlow()
		end
	end

	return function(phi, radiusIndex)
		local fj = phi / INV_PHI_STEP
		if fj < 1 then
			fj = 1
		elseif fj > phiRows - 0.001 then
			fj = phiRows - 0.001
		end
		local j0 = fj // 1
		local tj = fj - j0

		local q0 = radiusIndex // 1
		if q0 > RADIUS_SAMPLES - 1 then
			q0 = RADIUS_SAMPLES - 1
		end
		local tq = radiusIndex - q0

		local at = (j0 * (RADIUS_SAMPLES + 1) + q0) * 4
		local b00 = buffer.readf32(grid, at)
		local b01 = buffer.readf32(grid, at + 4)
		local b10 = buffer.readf32(grid, at + rowStride)
		local b11 = buffer.readf32(grid, at + rowStride + 4)

		local x0 = b00 + (b01 - b00) * tq
		local x1 = b10 + (b11 - b10) * tq
		return x0 + (x1 - x0) * tj
	end
end

function Geodesics.build()
	local params = buildImpactParams()
	local radii, state, phiOut = traceRays(params)

	return {
		NRG = RADIUS_SAMPLES,
		escapeImpact = buildEscapeLookup(params, state, phiOut),
		diskImpact = buildDiskLookup(params, radii),
	}
end

return Geodesics
