local AssetService = game:GetService("AssetService")

local Config = require(script.Parent.Config)

local D = Config.D
local sqrtF = Config.SqrtF

local MeshUtil = {}

function MeshUtil.newMesh(extent)
	local mesh = AssetService:CreateEditableMesh()
	local v = mesh:BatchAdd(Enum.MeshAttribute.Vertex, {
		Vector3.new(-extent, -extent, -0.05),
		Vector3.new(extent, extent, 0.05),
		Vector3.new(extent + 0.01, extent, 0.05),
		Vector3.new(-extent, extent, 0.05),
		Vector3.new(extent, -extent, -0.05),
		Vector3.new(extent + 0.01, -extent, -0.05),
	})
	mesh:BatchAdd(Enum.MeshAttribute.Face, { { v[1], v[2], v[3] }, { v[4], v[5], v[6] } })
	return mesh
end

function MeshUtil.gridFaces(vertexIds, rows, cols)
	local faces = {}
	for ir = 0, rows - 2 do
		for ia = 0, cols - 1 do
			local wrap = (ia + 1) % cols
			local a = vertexIds[ir * cols + ia + 1]
			local b = vertexIds[ir * cols + wrap + 1]
			local c = vertexIds[(ir + 1) * cols + wrap + 1]
			local d = vertexIds[(ir + 1) * cols + ia + 1]
			faces[#faces + 1] = { a, b, c }
			faces[#faces + 1] = { a, c, d }
		end
	end
	return faces
end

function MeshUtil.colorIdsOf(mesh, vertexIds)
	local attrs = mesh:BatchGetVertexAttributes(Enum.MeshAttribute.Color, vertexIds)
	local ids = table.create(#vertexIds, 0)
	for i = 1, #vertexIds do
		ids[i] = attrs[i][1]
	end
	return ids
end

function MeshUtil.makePart(mesh, folder, name, color)
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.new(1, 1, 1)
	part.DoubleSided = true
	part.Parent = folder
	return part
end

function MeshUtil.planeRadius(b)
	local x = b * sqrtF / D
	if x > 0.98 then
		x = 0.98
	end
	return D * x / math.sqrt(1 - x * x)
end

return MeshUtil
