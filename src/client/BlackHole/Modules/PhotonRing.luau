local Config = require(script.Parent.Config)
local Color = require(script.Parent.Color)
local MeshUtil = require(script.Parent.MeshUtil)

local sin, cos = math.sin, math.cos
local TAU = math.pi * 2

local D = Config.D
local B_CRIT = Config.BCrit
local GLOW = Config.RingGlow

local OFFSET = 0.5
local SEGMENTS = 160
local BANDS = 3
local BAND_IMPACT = { 1.0, 1.025, 1.09 }
local BAND_LIGHT = { 1.0, 0.45, 0.0 }

local PhotonRing = {
	Offset = OFFSET,
}

function PhotonRing.new(folder)
	local mesh = MeshUtil.newMesh(22)

	local positions = {}
	for j = 1, BANDS do
		local radius = MeshUtil.planeRadius(B_CRIT * BAND_IMPACT[j]) * (D - OFFSET) / D
		for ia = 0, SEGMENTS - 1 do
			local a = ia / SEGMENTS * TAU
			positions[(j - 1) * SEGMENTS + ia + 1] = Vector3.new(cos(a) * radius, sin(a) * radius, 0)
		end
	end

	local vertexIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	mesh:BatchAdd(Enum.MeshAttribute.Face, MeshUtil.gridFaces(vertexIds, BANDS, SEGMENTS))

	local colorIds = MeshUtil.colorIdsOf(mesh, vertexIds)
	local colors = table.create(BANDS * SEGMENTS, Color3.new())
	mesh:BatchSetValues(colorIds, colors)

	return {
		mesh = mesh,
		colorIds = colorIds,
		colors = colors,
		part = MeshUtil.makePart(mesh, folder, "PhotonRing"),
	}
end

function PhotonRing.update(ring, cosE)
	local tone = Color.tone
	for j = 1, BANDS do
		for ia = 0, SEGMENTS - 1 do
			local f = GLOW * BAND_LIGHT[j] * (1 - 0.4 * cosE * cos(ia / SEGMENTS * TAU))
			ring.colors[(j - 1) * SEGMENTS + ia + 1] = Color3.new(tone(f), tone(f * 0.78), tone(f * 0.5))
		end
	end
	ring.mesh:BatchSetValues(ring.colorIds, ring.colors)
end

return PhotonRing
