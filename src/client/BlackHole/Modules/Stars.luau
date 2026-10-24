--!native
--!optimize 2

local Config = require(script.Parent.Config)
local MeshUtil = require(script.Parent.MeshUtil)

local sin, cos, acos, sqrt = math.sin, math.cos, math.acos, math.sqrt
local min, clamp = math.min, math.clamp
local TAU = math.pi * 2

local D = Config.D
local sqrtF = Config.SqrtF

local SKY_RADIUS = 900

local Stars = {}

function Stars.new(folder, geo)
	local primary = Config.Stars
	local total = primary + Config.StarsB

	local dirX, dirY, dirZ, size = table.create(primary, 0), table.create(primary, 0), table.create(primary, 0), table.create(primary, 0)
	local baseColor = {}

	local rng = Random.new(77)
	for i = 1, primary do
		local z = rng:NextNumber() * 2 - 1
		local a = rng:NextNumber() * TAU
		local ring = sqrt(1 - z * z)
		dirX[i], dirY[i], dirZ[i] = ring * cos(a), z, ring * sin(a)

		local bright = rng:NextNumber()
		local tint = rng:NextNumber()
		size[i] = 0.9 * (0.7 + 1.8 * bright ^ 6)
		local lum = 0.25 + 0.75 * bright ^ 2
		baseColor[i] = Color3.new(lum * (0.62 + 0.38 * tint), lum * (0.76 + 0.02 * tint), lum * (1.0 - 0.45 * tint))
	end

	local mesh = MeshUtil.newMesh(1000)
	local positions = table.create(total * 3, Vector3.zero)
	local colors = table.create(total * 3, Color3.new())
	for q = 1, total do
		local n = (q - 1) * 3
		positions[n + 1], positions[n + 2], positions[n + 3] = Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
		local c = baseColor[q <= primary and q or q - primary]
		colors[n + 1], colors[n + 2], colors[n + 3] = c, c, c
	end

	local vertexIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	local faces = {}
	for q = 1, total do
		local n = (q - 1) * 3
		faces[q] = { vertexIds[n + 1], vertexIds[n + 2], vertexIds[n + 3] }
	end
	mesh:BatchAdd(Enum.MeshAttribute.Face, faces)

	mesh:BatchSetValues(MeshUtil.colorIdsOf(mesh, vertexIds), colors)

	return {
		mesh = mesh,
		vertexIds = vertexIds,
		positions = positions,
		escapeImpact = geo.escapeImpact,
		primary = primary,
		total = total,
		dirX = dirX,
		dirY = dirY,
		dirZ = dirZ,
		size = size,
		part = MeshUtil.makePart(mesh, folder, "LensedStars"),
	}
end

function Stars.update(stars, right, up, forward, toCam)
	local Rx, Ry, Rz = right.X, right.Y, right.Z
	local Ux, Uy, Uz = up.X, up.Y, up.Z
	local Fx, Fy, Fz = forward.X, forward.Y, forward.Z
	local cx, cy, cz = toCam.X, toCam.Y, toCam.Z

	local positions, escapeImpact, primary = stars.positions, stars.escapeImpact, stars.primary
	local dirX, dirY, dirZ, size = stars.dirX, stars.dirY, stars.dirZ, stars.size

	for q = 1, stars.total do
		local secondary = q > primary
		local si = secondary and q - primary or q
		local x, y, z = dirX[si], dirY[si], dirZ[si]

		local psi = acos(clamp(x * cx + y * cy + z * cz, -1, 1))
		local b = escapeImpact(secondary and (TAU - psi) or psi)
		local n = (q - 1) * 3

		if b then
			local px, py = x * Rx + y * Ry + z * Rz, x * Ux + y * Uy + z * Uz
			local len = sqrt(px * px + py * py)
			if len < 1e-6 then
				px, py, len = 1, 0, 1
			end
			px /= len
			py /= len
			if secondary then
				px, py = -px, -py
			end

			local sn = min(b * sqrtF / D, 0.999)
			local cs = sqrt(1 - sn * sn)
			local center = Vector3.new(
				(Fx * cs + (Rx * px + Ux * py) * sn) * SKY_RADIUS,
				(Fy * cs + (Ry * px + Uy * py) * sn) * SKY_RADIUS,
				(Fz * cs + (Rz * px + Uz * py) * sn) * SKY_RADIUS
			)

			local s = size[si] * (secondary and 0.7 or 1)
			positions[n + 1] = center - right * s - up * (0.6 * s)
			positions[n + 2] = center + right * s - up * (0.6 * s)
			positions[n + 3] = center + up * (1.1 * s)
		else
			positions[n + 1], positions[n + 2], positions[n + 3] = Vector3.zero, Vector3.zero, Vector3.zero
		end
	end

	stars.mesh:BatchSetValues(stars.vertexIds, positions)
end

return Stars
