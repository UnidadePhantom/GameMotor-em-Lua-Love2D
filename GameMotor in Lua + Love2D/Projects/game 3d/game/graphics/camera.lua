local okVec3, vec3 = pcall(require, "game.math.vec3")
if not okVec3 then
    vec3 = require("Engine.Template3D.game.math.vec3")
end

local okMat4, mat4 = pcall(require, "game.math.mat4")
if not okMat4 then
    mat4 = require("Engine.Template3D.game.math.mat4")
end

local camera = {}
camera.__index = camera

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function camera.new(config)
    local self = setmetatable({}, camera)
    config = config or {}

    self.position = vec3.new(0, 0, 4)
    self.yaw = config.yaw or (-math.pi * 0.5)
    self.pitch = config.pitch or 0.0
    self.speed = config.speed or 3.0
    self.sensitivity = config.sensitivity or 0.0025
    self.fov = config.fov or math.rad(70)
    self.near = config.near or 0.05
    self.far = config.far or 100.0

    return self
end

function camera:getForward()
    local cp = math.cos(self.pitch)
    local sp = math.sin(self.pitch)
    local cy = math.cos(self.yaw)
    local sy = math.sin(self.yaw)
    return vec3.normalize(vec3.new(cp * cy, sp, cp * sy))
end

function camera:getRight()
    local worldUp = vec3.new(0, 1, 0)
    return vec3.normalize(vec3.cross(self:getForward(), worldUp))
end

function camera:getViewMatrix()
    local target = vec3.add(self.position, self:getForward())
    return mat4.lookAt(self.position, target, vec3.new(0, 1, 0))
end

function camera:getProjectionMatrix(width, height)
    local aspect = width / height
    return mat4.perspective(self.fov, aspect, self.near, self.far)
end

function camera:onMouseMoved(dx, dy)
    self.yaw = self.yaw + dx * self.sensitivity
    self.pitch = clamp(self.pitch - dy * self.sensitivity, -1.55, 1.55)
end

function camera:update(dt)
    local move = vec3.new(0, 0, 0)
    local forward = self:getForward()
    local right = self:getRight()

    if love.keyboard.isDown("w") then
        move = vec3.add(move, forward)
    end
    if love.keyboard.isDown("s") then
        move = vec3.sub(move, forward)
    end
    if love.keyboard.isDown("d") then
        move = vec3.add(move, right)
    end
    if love.keyboard.isDown("a") then
        move = vec3.sub(move, right)
    end
    if love.keyboard.isDown("space") then
        move = vec3.add(move, vec3.new(0, 1, 0))
    end
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        move = vec3.add(move, vec3.new(0, -1, 0))
    end

    local len = vec3.length(move)
    if len > 0 then
        local velocity = self.speed * dt
        self.position = vec3.add(self.position, vec3.scale(vec3.normalize(move), velocity))
    end
end

return camera
