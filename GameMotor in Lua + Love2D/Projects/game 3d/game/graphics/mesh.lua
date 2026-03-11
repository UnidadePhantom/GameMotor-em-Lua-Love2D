local mesh = {}
mesh.__index = mesh

function mesh.new(vertices, faces)
    local self = setmetatable({}, mesh)
    self.vertices = vertices or {}
    self.faces = faces or {}
    self.polygons = {}
    return self
end

function mesh.cube(size)
    local h = (size or 1) * 0.5
    local vertices = {
        { x = -h, y = -h, z = -h },
        { x = h, y = -h, z = -h },
        { x = h, y = h, z = -h },
        { x = -h, y = h, z = -h },
        { x = -h, y = -h, z = h },
        { x = h, y = -h, z = h },
        { x = h, y = h, z = h },
        { x = -h, y = h, z = h }
    }

    local faces = {
        { 1, 2, 3 }, { 1, 3, 4 },
        { 5, 7, 6 }, { 5, 8, 7 },
        { 1, 4, 8 }, { 1, 8, 5 },
        { 2, 6, 7 }, { 2, 7, 3 },
        { 4, 3, 7 }, { 4, 7, 8 },
        { 1, 5, 6 }, { 1, 6, 2 }
    }

    local out = mesh.new(vertices, faces)
    out.polygons = {
        { 1, 2, 3, 4 },
        { 5, 6, 7, 8 },
        { 1, 5, 6, 2 },
        { 2, 6, 7, 3 },
        { 3, 7, 8, 4 },
        { 4, 8, 5, 1 }
    }
    return out
end

function mesh.plane(size, y)
    local h = (size or 10) * 0.5
    local py = y or 0
    local vertices = {
        { x = -h, y = py, z = -h },
        { x = h, y = py, z = -h },
        { x = h, y = py, z = h },
        { x = -h, y = py, z = h }
    }

    local faces = {
        { 1, 2, 3 },
        { 1, 3, 4 }
    }

    local out = mesh.new(vertices, faces)
    out.polygons = { { 1, 2, 3, 4 } }
    return out
end

return mesh
