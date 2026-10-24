local Config = require(script.Parent.Config)
local MeshUtil = require(script.Parent.MeshUtil)

local sin, cos = math.sin, math.cos
local TAU = math.pi * 2

local D = Config.D
local B_CRIT = Config.BCrit

local OFFSET = 0.2
local SEGMENTS = 96

local Shadow = {
	Offset = OFFSET,
}

function Shadow.new(folder)
	local mesh = MeshUtil.newMesh(22)
	local radius = MeshUtil.planeRadius(B_CRIT * 0.998) * (D - OFFSET) / D

	local positions = { Vector3.zero }
	for i = 0, SEGMENTS - 1 do
		local a = i / SEGMENTS * TAU
		positions[#positions + 1] = Vector3.new(cos(a) * radius, sin(a) * radius, 0)
	end

	local v = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	local faces = {}
	for i = 1, SEGMENTS do
		faces[i] = { v[1], v[i + 1], v[i % SEGMENTS + 2] }
	end
	mesh:BatchAdd(Enum.MeshAttribute.Face, faces)

	return MeshUtil.makePart(mesh, folder, "Shadow", Color3.new(0, 0, 0))
end

return Shadow
