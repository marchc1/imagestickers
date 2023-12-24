local shrinkwrap = {}
local Bytestream = ImageStickers.Bytestream

-- Some notes about the shrinkwrapping functions:
-- The positions are stored as 16-bit numbers, and the normals are stored as 8-bit numbers.
-- Therefore, the maximum range for a sticker to "stick" to something is 327.68 source units.
-- This seemed like a good range to not be annoying to work with, while still allowing for pretty good pointfile sizes.
-- The max size of a pointfile will be around 910 bytes, given a 10x10 grid.

-- The wrap calculations are done on the client who performs the recalculation, the result of which is passed through a function that converts the points into
-- the network-efficient format, which is then sent to the server to both store for dupes and send to the rest of the clients. The gizmo uses a rough approximation
-- (just the raw util.TraceLine result), while the full ralculation uses an experimental method that traces the actual visual meshes of entities rather than 
-- just the physical. Both methods are significantly slow, slow enough where they cannot be ran real-time, hence the need for compilation down to a file.



if SERVER then
    util.AddNetworkString("imagestickers.shrinkwrap_recalculate")
    util.AddNetworkString("imagestickers.ask_shrinkwrap")
end

local magicnumber = ImageStickers.SizeMagicNumber

if CLIENT then
    net.Receive("imagestickers.shrinkwrap_recalculate", function()
        local ent = net.ReadEntity()
        ent:InvalidateShrinkwrap()
    end)
end

-- might need a better function for this
function shrinkwrap.IntersectLineWithTriangle(start, direction, v1, v2, v3)
    local EPSILON = 1e-6

    local edge1 = v2 - v1
    local edge2 = v3 - v1
    local h = direction:Cross(edge2)
    local a = edge1:Dot(h)

    if a > -EPSILON and a < EPSILON then
        return nil
    end

    local f = 1 / a
    local s = start - v1
    local u = f * s:Dot(h)

    if u < 0 or u > 1 then
        return nil
    end

    local q = s:Cross(edge1)
    local v = f * direction:Dot(q)

    if v < 0 or u + v > 1 then
        return nil
    end

    local t = f * edge2:Dot(q)

    if t > EPSILON then
        local intersectionPoint = start + direction * t
        return intersectionPoint
    end

    return nil
end

local function worldTriangle(self, v1, v2, v3)
    return {
        self:LocalToWorld(v1.pos),
        self:LocalToWorld(v2.pos),
        self:LocalToWorld(v3.pos)
    }
end

local SHRINKWRAP_ACCURACY_PHYSMESH = 1
local SHRINKWRAP_ACCURACY_VISMESH = 2

function shrinkwrap.RecalculatePoints(self, xpoints, ypoints, offset, accuracy, throwawaynonhits)
    accuracy = accuracy or SHRINKWRAP_ACCURACY_VISMESH
    throwawaynonhits = throwawaynonhits or false
    if SERVER then return end
    
    local meshes = {}

    local function cacheEnt(ent)
        if meshes[ent] then
            return meshes[ent]
        end

        -- meshes[ent] = {triangles = {}}

        local fullModelMesh = shrinkwrap.GetEntityMeshInWorldspace(ent)
        meshes[ent] = fullModelMesh

        --[[debugoverlay.Cross(ent:GetPos(), 64, 10, Color(90, 90, 235), true)
        for k, modelMesh in ipairs(modelMeshes) do
            for i = 1, #modelMesh.triangles, 3 do
                local vs = worldTriangle(ent, modelMesh.triangles[i], modelMesh.triangles[i+1], modelMesh.triangles[i+2])
                table.insert(meshes[ent].triangles, vs)

                --debugoverlay.Line(vs[1], vs[2], 5, color_white, true)
                --debugoverlay.Line(vs[2], vs[3], 5, color_white, true)
                --debugoverlay.Line(vs[3], vs[1], 5, color_white, true)
            end
        end]]

        return meshes[ent]
    end

    local function trace(tracedata)
        local t = util.TraceLine(tracedata)

        local ent = t.Entity
        if not IsValid(ent) or accuracy < SHRINKWRAP_ACCURACY_VISMESH then return t end

        local hitTriangle = false
        local lastDistance = 2^20
        local lastHit = Vector(2^15,2^15,2^15)
        local mesh = cacheEnt(ent)
        
        for i = 1, #mesh, 3 do
            local v1, v2, v3 = mesh[i].pos, mesh[i + 1].pos, mesh[i + 2].pos
            local intersectionPoint = shrinkwrap.IntersectLineWithTriangle(tracedata.start, (tracedata.endpos - tracedata.start):GetNormalized(), v1, v2, v3)
            if intersectionPoint ~= nil then
                local distanceCheck = tracedata.start:Distance(intersectionPoint)
                if distanceCheck < lastDistance then
                    lastDistance = distanceCheck
                    lastHit = intersectionPoint
                    hitTriangle = true
                end
            end
        end
        
        if not hitTriangle then
            local newfilter = table.Copy(tracedata.filter or {})
            table.insert(newfilter, t.Entity)
            return trace{
                start = tracedata.start,
                endpos = tracedata.endpos,
                filter = newfilter 
            }
        end

        t.HitPos = lastHit
        --.Cross(t.HitPos, 2, 10, Color(45,255,0), false)
        --debugoverlay.Line(tracedata.start, t.HitPos, 10, Color(45,255,0), false)
        return t
    end

    xpoints = xpoints or 10
    ypoints = ypoints or 10
    if not self.image or not self.image:readytodraw() then return {points={},resX=xpoints,resY=ypoints} end

    offset = offset or 3
    local w, h = self.Smoothing.ScaleX.y/magicnumber, self.Smoothing.ScaleY.y/magicnumber

    render.SetColorMaterial()
    local points = {}
    for y = 1, ypoints do points[y] = {} for x = 1, xpoints do
        local posX, posY = math.Remap(x, 1, xpoints, -w/2, w/2), math.Remap(y, 1, ypoints, -h/2, h/2)
        local xv = Vector(1,1,1)

        local pos = self:LocalToWorld(Vector(posY, posX, -4))
        local trace = trace{start = pos, endpos = pos + (self:GetUp() * -323.69)}
        points[y][x] = {
            x = x,
            y = y,
            xfrac = math.Remap(x, 1, xpoints, 0, 1),
            yfrac = math.Remap(y, 1, ypoints, 0, 1),
            start = pos,
            hitpos = self:WorldToLocal(trace.HitPos + (trace.HitNormal * offset)),
            normal = self:WorldToLocal(trace.HitNormal),
            --trace = trace,
            --color = Color(Lerp(x/xpoints,0,255), Lerp(y/ypoints,0,255), 0) --debugging
        }

        if trace.Hit == false and throwawaynonhits then
            points[y][x].hitpos = Vector(0,0,0)
        end
    end end

    return {
        points = points,
        resX = xpoints,
        resY = ypoints
    }
end
local band = bit.band

local function fromCompressedNumber(n)
    return n / 100
end
local function toCompressedNumber(n)
    return math.Round(math.Clamp(n * 100, -2^15, 2^15), 0)
end

local function fromCompressedNormal(n)
    local flipped = band(n, 128) == 128
    local n = band(n, 127)
    return (n / 100) * (flipped and -1 or 1)
end

local function toCompressedNormal(n)
    n = math.Clamp(n, -1, 1)
    local flipped = n < 0
    local to = math.abs(n) * 100
    
    local ret = (flipped and 128 or 0) + math.Round(to)
    return ret
end

local function trickMeshPosition(v)
    return Vector(
        fromCompressedNumber(toCompressedNumber(v.x)),
        fromCompressedNumber(toCompressedNumber(v.y)),
        fromCompressedNumber(toCompressedNumber(v.z))
    )
end

local function networkEfficientReadPos(bs)
    local ux, uy, uz = bs:readInt(16), bs:readInt(16), bs:readInt(16)
    local x,y,z = fromCompressedNumber(ux), fromCompressedNumber(uy), fromCompressedNumber(uz)
    return Vector(x,y,z)
end

local function networkEfficientWritePos(bs, v)
    local x, y, z = toCompressedNumber(v.x), toCompressedNumber(v.y), toCompressedNumber(v.z)
    bs:writeInt(x, 16)
    bs:writeInt(y, 16)
    bs:writeInt(z, 16)
end

local function networkEfficientReadNormal(bs)
    return Vector(fromCompressedNormal(bs:readUInt(8)), fromCompressedNormal(bs:readUInt(8)), fromCompressedNormal(bs:readUInt(8)))
end

local function networkEfficientWriteNormal(bs, v)
    bs:writeUInt(toCompressedNormal(v.x), 8)
    bs:writeUInt(toCompressedNormal(v.y), 8)
    bs:writeUInt(toCompressedNormal(v.z), 8)
end

local function trickMeshNormal(v)
    return Vector(
        fromCompressedNormal(toCompressedNormal(v.x)),
        fromCompressedNormal(toCompressedNormal(v.y)),
        fromCompressedNormal(toCompressedNormal(v.z))
    )
end

local function vert(self, triangles, v)
    print(v.normal)
    table.insert(triangles, {
        pos = trickMeshPosition(v.hitpos), 
        normal = trickMeshNormal(v.normal),
        u = Lerp(v.xfrac, 0, 1),
        v = Lerp(v.yfrac, 0, 1)
    })
end

local function tri(self, triangles, v1, v2, v3)
    vert(self, triangles, v1) 
    vert(self, triangles, v2) 
    vert(self, triangles, v3)
end

-- Point positions that had no hit are saved as zero length vectors, this confirms if the triangle  actually hit the full mesh or not
function shrinkwrap.IsTriangleLegitimate(v1, v2, v3)
    return v1.hitpos:LengthSqr() > 0 and v2.hitpos:LengthSqr() > 0 and v3.hitpos:LengthSqr() > 0
end
function shrinkwrap.IsQuadLegitimate(v1, v2, v3, v4)
    return v1.hitpos:LengthSqr() > 0 and v2.hitpos:LengthSqr() > 0 and v3.hitpos:LengthSqr() > 0 and v4.hitpos:LengthSqr() > 0
end

function shrinkwrap.RecalculateMesh(self, pointsstruct)
    if SERVER then return end
    local points = pointsstruct.points
    if self.ShrinkwrapMesh then
        self.ShrinkwrapMesh:Destroy()
    end
    self.ShrinkwrapMesh = Mesh()

    local triangles = {}
    for y = 1, #points - 1 do
        local row = points[y]
        for x = 1, #row - 1 do
            local v1, v2, v3, v4 = points[y][x], points[y][x + 1], points[y + 1][x + 1], points[y + 1][x]
            if shrinkwrap.IsTriangleLegitimate(v1, v2, v3) then
                tri(self, triangles, v1, v2, v3)
            end
            if shrinkwrap.IsTriangleLegitimate(v3, v4, v1) then
                tri(self, triangles, v3, v4, v1)
            end
        end
    end

    self.ShrinkwrapMesh:BuildFromTriangles(triangles)
end

-- Thank you https://github.com/Derpius/VisTrace/blob/master/source/objects/AccelStruct.cpp#L34 for saving me from more matrix math
-- This function takes into account everything with regards to transformations that the object could have and returns the worldspace
-- model mesh (as viewed by the player right now) for use with the triangle intersection algorithm for precise wrapping
function shrinkwrap.GetEntityMeshInWorldspace(ent)
    if not IsValid(ent) then return end
    
    local model = ent:GetModel()
    local modelMesh, modelBind = util.GetModelMeshes(model, 0) -- LOD zero

    if not modelMesh then return end

    local mesh = {}
    for _, objectPart in ipairs(modelMesh) do
        for _, v in ipairs(objectPart.triangles) do
            local vertex = Matrix()
            vertex:SetTranslation(v.pos)

            local vertex_weights = v.weights

            local final = Vector()

            for _, boneVertexData in ipairs(vertex_weights) do
                local add = (
                    ent:GetBoneMatrix(boneVertexData.bone) * 
                    modelBind[boneVertexData.bone].matrix * 
                    vertex 
                )
                local addV = add:GetTranslation()
                final = final + (addV * boneVertexData.weight)
            end
            
            local newTri = {}
            for k, v in pairs(v) do newTri[k] = v end
            newTri.pos = final
            table.insert(mesh, newTri)
        end
    end
    return mesh
end

local SHRINKWRAP_STORE_HEADER  = "ISSW"
local SHRINKWRAP_STORE_VERSION = 1
local SHRINKWRAP_STORE_VERSION1_MAXRES = 10

-- backwards compatibility just in case
local shrinkwrap_parsers = {
    [1] = {
        header = function(self, bs)
            return bs:readByte(), bs:readByte()
        end,
        read = function(self, bs)
            local points = {}
            local resX, resY = self:header(bs)
            
            if resX > SHRINKWRAP_STORE_VERSION1_MAXRES or resY > SHRINKWRAP_STORE_VERSION1_MAXRES then
                error("refusing to parse further: resolution > max (" .. SHRINKWRAP_STORE_VERSION1_MAXRES .. ")")
            end

            for y = 1, resY do
                local row = {}
                for x = 1, resX do
                    local p = networkEfficientReadPos(bs)
                    local n = networkEfficientReadNormal(bs)
                    row[x] = {
                        x = x,
                        y = y,
                        xfrac = math.Remap(x, 1, resX, 0, 1),
                        yfrac = math.Remap(y, 1, resY, 0, 1),
                        hitpos = p,
                        normal = n
                    }
                end
                points[y] = row
            end
            
            local check = bs:readByte()
            if check == 0xAB and bs:eof() then
                return {
                    points = points,
                    resX = resX,
                    resY = resY
                }
            else
                error("shrinkwrap parser v1: last byte ~= 0xAB (check = " .. check .. ", eof = " .. self:eof() .. ")")
            end
        end
    }
}

function shrinkwrap.ReadPoints(data)
    local bs = Bytestream(data)
    
    local header = bs:readString()
    if header ~= "ISSW" then error("shrinkwrap.ReadPoints parse failure: malformed header") end

    local version = bs:readUInt(16)
    local reader = shrinkwrap_parsers[version]
    if reader == nil then error("shrinkwrap.ReadPoints parse failure: no reader exists for version " .. version) end

    return shrinkwrap_parsers[version]:read(bs)
end

function shrinkwrap.IsValidPointfile(data)
    local success, rets = xpcall(shrinkwrap.ReadPoints, function(err) print("error! " .. err) end, data)
    return success
end

-- writes 10 + ((resX * resY) * (6 + 3)) bytes
-- 10 bytes for header info and EOF, 9 bytes per point (6 for position vector, 3 for normal vector)
function shrinkwrap.WritePoints(pointsstruct)
    local bs = Bytestream()
    local points = pointsstruct.points

    bs:writeString("ISSW")
    bs:writeUInt(SHRINKWRAP_STORE_VERSION, 16)
    bs:writeByte(pointsstruct.resX)
    bs:writeByte(pointsstruct.resY)

    for y = 1, pointsstruct.resY do
        local row = points[y]
        for x = 1, pointsstruct.resX do
            local point = row[x]
            --print(x, y, point.hitpos)
            networkEfficientWritePos(bs, point.hitpos)
            networkEfficientWriteNormal(bs, point.normal)
        end
    end

    bs:writeByte(0xAB)

    return bs:dump()
end

function shrinkwrap.UpdateShrinkwrap(ent, pointfile, ply)
    if not shrinkwrap.IsValidPointfile(pointfile) then
        print("refusing to upload image-sticker pointfile: likely too large")
        return
    end

    ent.pointfile = pointfile

    net.Start("march.imagestickers.shrinkwrapmesh")
    net.WriteEntity(ent)
    net.WriteUInt(#pointfile, 16)
    net.WriteData(pointfile, #pointfile)
    if CLIENT then
        net.SendToServer()
        return
    end
    
    if ply == nil then
        net.Broadcast()
    else
        net.Send(ply)
    end
end

function shrinkwrap.AskShrinkwrap(ent)
    if SERVER then return print("tried to call shrinkwrap.AskShrinkwrap on server??") end

    net.Start("march.imagestickers.ask_shrinkwrap")
    net.WriteEntity(ent)
    net.SendToServer()
end

ImageStickers.Shrinkwrap = shrinkwrap