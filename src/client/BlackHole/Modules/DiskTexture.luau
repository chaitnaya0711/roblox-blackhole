local Config = require(script.Parent.Config)

local clamp = math.clamp

local DiskTexture = {
	Rows = 64,
	Cols = 256,
	RowHeight = (Config.ROut - Config.RIn) / 64,
}

local LAYERS = {
	{ nx = 5, ny = 24, weight = 0.40, shear = 0.0 },
	{ nx = 12, ny = 16, weight = 0.30, shear = 0.9 },
	{ nx = 28, ny = 24, weight = 0.30, shear = 1.6 },
}

local function seedLattices(rng)
	for _, layer in ipairs(LAYERS) do
		layer.lattice = table.create(layer.nx * layer.ny, 0)
		for i = 1, layer.nx * layer.ny do
			layer.lattice[i] = rng:NextNumber()
		end
	end
end

local function sampleLayer(layer, a, s)
	local nx, ny, lat = layer.nx, layer.ny, layer.lattice
	local x = (a + layer.shear * s) * nx
	local y = s * (ny - 1)
	local x0, y0 = x // 1, y // 1
	local fx, fy = x - x0, y - y0
	fx = fx * fx * (3 - 2 * fx)
	fy = fy * fy * (3 - 2 * fy)

	local xa, xb = x0 % nx, (x0 + 1) % nx
	local yb = y0 + 1
	if y0 > ny - 1 then y0 = ny - 1 end
	if yb > ny - 1 then yb = ny - 1 end

	local v00, v10 = lat[y0 * nx + xa + 1], lat[y0 * nx + xb + 1]
	local v01, v11 = lat[yb * nx + xa + 1], lat[yb * nx + xb + 1]
	local top = v00 + (v10 - v00) * fx
	local bottom = v01 + (v11 - v01) * fx
	return top + (bottom - top) * fy
end

function DiskTexture.build()
	local rows, cols = DiskTexture.Rows, DiskTexture.Cols
	local data = table.create(rows * (cols + 1), 0)
	seedLattices(Random.new(1337))

	for ir = 0, rows - 1 do
		local s = (ir + 0.5) / rows
		for ia = 0, cols - 1 do
			local a = (ia + 0.5) / cols
			local n = 0
			for _, layer in ipairs(LAYERS) do
				n += layer.weight * sampleLayer(layer, a, s)
			end
			n = clamp((n - 0.5) * 2.8 + 0.5, 0, 1)
			data[ir * (cols + 1) + ia + 1] = 0.25 + 0.95 * n
		end
		data[ir * (cols + 1) + cols + 1] = data[ir * (cols + 1) + 1]
	end

	return data
end

return DiskTexture
