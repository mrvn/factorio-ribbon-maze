Maze = {
   blocks = {},
   neighbors = {
      {x= 1, y= 0},
      {x= 0, y= 1},
      {x=-1, y= 0},
      {x= 0, y=-1},
   },
   resources = {},
}

local block_size = 16

function get(arr, x, y)
   return arr[x .. "_" .. y]
end

function set(arr, x, y, v)
   arr[x .. "_" .. y] = v
end

function gen_seed(a, b, c)
   return (a + b * 1024 + c * 1024 * 1024) % 4294967291
end

function Maze.add_neighbors(self, free, cells, x, y)
   for _, d in ipairs(self.neighbors) do
      if (not get(cells, x + d.x, y + d.y)) and (not get(cells, x + 2 * d.x, y + 2 * d.y)) then
         table.insert(free, {x=x + d.x, y=y + d.y, x2=x + 2 * d.x, y2=y + 2 * d.y})
      end
   end
end

function Maze.count_neighbors(self, cells, x, y)
   local res = 0
   for _, d in ipairs(Maze.neighbors) do
      if get(cells, x + d.x, y + d.y) then
         res = res + 1
      end
   end
   return res
end

Block = { }

function Block.get(self, x, y)
   return get(self.cells, x, y)
end

function Block.set(self, x, y, v)
   set(self.cells, x, y, v)
end

function Block.new(maze, x, y)
   log("Block.new(" .. x .. ", " .. y .. ")")
   local seed = gen_seed(game.default_map_gen_settings.seed, x, y)
   local o = {
      rng = game.create_random_generator(seed),
      cells = {},
      seed = seed,
   }
   Block.init(o, maze, x, y)
   log("Block.new(" .. x .. ", " .. y .. "): done")
   return o
end

function Block.init(self, maze, x, y)
   log("Block.init(" .. x .. ", " .. y .. ")")
   local free = {}
   -- get blocks to ensure there never is an 'O' constelation
   if x > 0 then
      Maze.get_create(maze, x - 1, y)
   else
      if x < 0 then
         Maze.get_create(maze, x + 1, y)
      else
         if y > 0 then
            Maze.get_create(maze, x, y - 1)
         else
            if y < 0 then
               Maze.get_create(maze, x, y + 1)
            else
               -- start with one cell at the origin
               Block.set(self, 0, 0, true)
               Maze.add_neighbors(maze, free, self.cells, 0, 0)
            end
         end
      end
   end
   log("Block.init(" .. x .. ", " .. y .. "): wall")
   -- border wall so nothing escapes
   local r = block_size / 2
   for i = -r - 2, r + 2 do
      Block.set(self, i, -r - 2, true)
      Block.set(self, i,  r + 2, true)
      Block.set(self, -r - 2, i, true)
      Block.set(self,  r + 2, i, true)
   end
   log("Block.init(" .. x .. ", " .. y .. "): existing")
   -- fill in existing blocks
   for _, d in ipairs(Maze.neighbors) do
      local block = Maze.get(maze, x + d.x, y + d.y)
      if block then
         for i = -r, r do
            if Block.get(block, d.y * i - d.x * r, d.x * i - d.y * r) then
               Block.set(self, d.y * i + d.x * r, d.x * i + d.y * r, true)
               if (i % 2 == 0) then
                  Maze.add_neighbors(maze, free, self.cells, d.y * i + d.x * r, d.x * i + d.y * r)
               end
            end            
         end
      end
   end
   --[[
   local block
   block = Maze.get(maze, x + 1, y)
   if block then
      for i = -r, r do
         if Block.get(block, -r, i) then
            Block.set(self, r, i, true)
         end
      end
   end
   block = Maze.get(maze, x - 1, y)
   if block then
      for i = -r, r do
         if Block.get(block, r, i) then
            Block.set(self, -r, i, true)
         end
      end
   end
   block = Maze.get(maze, x, y + 1)
   if block then
      for i = -r, r do
         if Block.get(block, i, -r) then
            Block.set(self, i, r, true)
         end
      end
   end
   block = Maze.get(maze, x, y - 1)
   if block then
      for i = -r, r do
         if Block.get(block, i, r) then
            Block.set(self, i, -r, true)
         end
      end
   end
   ]]--
   --if (x == 0) and (y == 0) then
   log("Block.init(" .. x .. ", " .. y .. "): grow")
   -- grow maze from existing seeds
   while #free > 0 do
      log(#free .. " free cells")
      local index = self.rng(#free)
      log("index = " .. index)
      local p = free[index]
      log("Trying cell (" .. p.x .. ", " .. p.y .. ") [" .. p.x2 .. ", " .. p.y2 .. "]")
      table.remove(free, index)
      if (not Block.get(self, p.x, p.y)) and (not Block.get(self, p.x2, p.y2)) then
         log("  taking")
         Block.set(self, p.x, p.y, true)
         Block.set(self, p.x2, p.y2, true)
         Maze.add_neighbors(maze, free, self.cells, p.x2, p.y2)
      end
   end
   --end
   log("Block.init(" .. x .. ", " .. y .. "): resources")
   -- palce resources in dead ends
   log("maze.resource_sum = " .. maze.resource_sum)
   for py = -r + 2, r - 2, 2 do
      for px = -r + 2, r - 2, 2 do
         log(px .. ", " .. py .. " = " .. Maze.count_neighbors(self, self.cells, px, py))
         if Maze.count_neighbors(self, self.cells, px, py) == 1 then
            local t = self.rng(0, maze.resource_sum)
            local sum = 0
            local resource
            log(t .. " " .. maze.resource_sum)
            for name, spec in pairs(maze.resources) do
               sum = sum + spec.coverage * 1000000000
               if t <= sum then
                  log("resource at " .. px .. ", " .. py .. ": " .. name)
                  local distance = (math.abs(x * block_size + px) + math.abs(y * block_size + py)) / ribbonMazeConfig().resourceStretchFactor
                  local resource = {
                     rng = Cmwc.withSeed(gen_seed(self.seed, px, py)),
                     resourceName = name,
                     minRand = 0.5,
                  }
                  if distance > 400 then
                     resource.resourceAmount = 400 * 400 * 400
                  elseif distance >= 7 then
                     resource.resourceAmount = 4 * distance * distance * distance
                  else
                     resource.resourceAmount = 40 * distance * distance
                  end
                  Block.set(self, px, py, resource)
                  break
               end
            end
         end
      end
   end
   log("Block.init(" .. x .. ", " .. y .. "): done")
end

function Maze.get(self, x, y)
   --log("Maze.get(" .. x .. ", " .. y .. ")")
   return get(self.blocks, x, y)
end

function Maze.get_create(self, x, y)
   --log("Maze.get_create(" .. x .. ", " .. y .. ")")
   local block = Maze.get(self, x, y)
   if block == nil then
      block = Block.new(self, x, y)
      set(self.blocks, x, y, block)
   end
   return block
end

function Maze.map_to_maze(self, x, y)
   local sep = 0 -- set to 4 to debug tiles seperately
   local bx = math.floor(x / (block_size + sep) + 0.5)
   local by = math.floor(y / (block_size + sep) + 0.5)
   local dx = x - bx * (block_size + sep)
   local dy = y - by * (block_size + sep)
   return bx, by, dx, dy
end

function Maze.resourceAt(self, x, y)
   local bx, by, dx, dy = Maze.map_to_maze(self, x, y)
   local block = Maze.get_create(self, bx, by)
   local resource = Block.get(block, dx, dy)
   if resource == nil then
      return nil
   end
   if resource and resource ~= true then
      log("Maze.resourceAt(" .. x .. ", " .. y .. ") = " .. resource.resourceName)
      return resource
   else
      return nil
   end
end

function Maze.wallTileAt(self, x, y)
   --log("Maze.wallTileAt(" .. x .. ", " .. y .. ")")
   local bx, by, dx, dy = Maze.map_to_maze(self, x, y)
   local block = Maze.get_create(self, bx, by)
   if Block.get(block, dx, dy) then
      return false
   else
      return true
   end
end

function Maze.deadEnd(maze, x, y)
    local neighbouringWallTiles = 0;
    local direction;

    if Maze.wallTileAt(maze, x, y+1) then
        neighbouringWallTiles = neighbouringWallTiles + 1
    else
        direction = NORTH
    end
    if Maze.wallTileAt(maze, x, y-1) then
        neighbouringWallTiles = neighbouringWallTiles + 1
    else
        direction = SOUTH
    end
    if Maze.wallTileAt(maze, x+1, y) then
        neighbouringWallTiles = neighbouringWallTiles + 1
    else
        direction = EAST
    end
    if Maze.wallTileAt(maze, x-1, y) then
        neighbouringWallTiles = neighbouringWallTiles + 1
    else
        direction = WEST
    end

    if neighbouringWallTiles == 4 then
        error("maze algorithm bug: 4 neighbouring wall tiles at " .. x .. "," .. y)
    end

    if neighbouringWallTiles == 3 then
        return true
    else
        return false
    end
end

function Maze.new()
   log("Maze.new()")
   local sum = 0
   for name, proto in pairs(game.entity_prototypes) do
      local spec = proto.autoplace_specification
      if spec and spec.force == "neutral" and spec.coverage > 0 and spec.control then
         log("adding resource " .. name .. ": " .. spec.coverage)
         --log("adding resource " .. name .. ": " .. serpent.block(spec))
         Maze.resources[name] = spec
         sum = sum + spec.coverage * 1000000000
      end
   end
   local water_coverage = 0.00033333333333333
   Maze.resources["water_"] = {
      coverage = water_coverage
   }
   sum = sum + water_coverage * 1000000000
   Maze.resource_sum = sum
   return Maze
end
