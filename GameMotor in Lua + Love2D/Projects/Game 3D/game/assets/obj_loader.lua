local okMesh, mesh = pcall(require, "game.graphics.mesh")
if not okMesh then
    mesh = require("Engine.Template3D.game.graphics.mesh")
end

local obj_loader = {}

local function parseFaceIndex(token)
    local value = token:match("^(%-?%d+)")
    if not value then
        return nil
    end
    return tonumber(value)
end

function obj_loader.load(path)
    local data, err = love.filesystem.read(path)
    if not data then
        return nil, ("Falha ao ler OBJ '%s': %s"):format(path, tostring(err))
    end

    local vertices = {}
    local faces = {}
    local polygons = {}

    for rawLine in data:gmatch("[^\r\n]+") do
        local line = rawLine:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local values = {}
            for token in line:gmatch("%S+") do
                values[#values + 1] = token
            end

            local command = values[1]
            if command == "v" and #values >= 4 then
                vertices[#vertices + 1] = {
                    x = tonumber(values[2]) or 0,
                    y = tonumber(values[3]) or 0,
                    z = tonumber(values[4]) or 0
                }
            elseif command == "f" and #values >= 4 then
                local polygon = {}
                for i = 2, #values do
                    local idx = parseFaceIndex(values[i])
                    if idx then
                        if idx < 0 then
                            idx = #vertices + idx + 1
                        end
                        polygon[#polygon + 1] = idx
                    end
                end

                -- Triangulacao em fan para faces com 4+ vertices.
                for i = 2, #polygon - 1 do
                    faces[#faces + 1] = { polygon[1], polygon[i], polygon[i + 1] }
                end
                if #polygon >= 3 then
                    polygons[#polygons + 1] = polygon
                end
            end
        end
    end

    local out = mesh.new(vertices, faces)
    out.polygons = polygons
    return out
end

return obj_loader
