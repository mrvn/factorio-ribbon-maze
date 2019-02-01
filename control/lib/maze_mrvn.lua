Maze = { }

local block_size = 64

function Maze.new()
   log("Maze.new()")
   local o = {
      blocks = {}
      
   }
   return o
end

Block = { }

function gen_seed(a, b, c)
   return (a + b * 1024 + c * 1024 * 1024) % 4294967291
end

neighbors = {
   {x= 1, y= 0},
   {x= 0, y= 1},
   {x=-1, y= 0},
   {x= 0, y=-1},
}
--[[
neighbors = {
   {x= -1, y= -1},
   {x=  0, y= -1},
   {x=  1, y= -1},
   {x=  1, y= 0},
   {x=  1, y= 1},
   {x=  0, y= 1},
   {x= -1, y= 1},
   {x= -1, y= 0},
}
]]--
function add_neighbors(free_cells, cells, x, y)
   local d
   for _, d in ipairs(neighbors) do
      if not cells[x + d.x .. "_" .. y + d.y] then
         table.insert(free_cells, {x=x + d.x, y=y + d.y})
      end
   end
end

function count_neighbors(cells, x, y)
   local res = 0
   for _, d in ipairs(neighbors) do
      if cells[x + d.x .. "_" .. y + d.y] then
         res = res + 1
      end
   end
   return res
end

function set(free_cells, cells, x, y)
   cells[x .. "_" .. y] = true
   if cells[x .. "_" .. y] then
      add_neighbors(free_cells, cells, x, y)
   end
end

function maybe_set(free_cells, rng, cells, x, y)
   if rng(-1, 1) > 0 then
      set(free_cells, cells, x, y)
   end
end

function Maze.get_block(maze, x, y)
   --log("Maze.get_block(maze, " .. x .. ", " .. y .. ")")
   local block = maze.blocks[x .. "_" .. y]
   if block == nil then
      local seed = gen_seed(game.default_map_gen_settings.seed, x, y)
      log("generate(" .. x .. ", " .. y .. ") seed=" .. seed)
      local rng = game.create_random_generator(seed)
      local r = block_size / 2
      local i
      block = { }
      block.rng = rng
      maze.blocks[x .. "_" .. y] = block
      -- generate border wall
      local seed_top    = gen_seed(seed, x, y - 1)
      local rng_top = game.create_random_generator(seed_top)
      local seed_bottom = gen_seed(seed, x, y + 1)
      local rng_bottom = game.create_random_generator(seed_bottom)
      local seed_left   = gen_seed(seed, x - 1, y)
      local rng_left = game.create_random_generator(seed_left)
      local seed_right  = gen_seed(seed, x + 1, y)
      local rng_right = game.create_random_generator(seed_right)
      local free = {}
      -- build safety wall around block
      for i = -r - 1, r + 2  do
         block[i .. "_" .. -r - 1] = true
         block[i .. "_" ..  r + 1] = true
         block[-r - 1 .. "_" .. i] = true
         block[ r + 1 .. "_" .. i] = true
      end
      -- block corners
      set(free, block, -r, -r)
      set(free, block,  r, -r)
      set(free, block, -r,  r)
      set(free, block,  r,  r)
      -- random walls on the outside
      for i = -r + 1, r - 1 do
         maybe_set(free, rng_top   , block,  i, -r)
         maybe_set(free, rng_bottom, block,  i,  r)
         maybe_set(free, rng_left  , block, -r,  i)
         maybe_set(free, rng_right , block,  r,  i)
      end
      -- free space in the center
      block[0 .. "_" .. 0] = true
      -- generate inside
      while #free > 0 do
         log(#free .. " free cells")
         local index = rng(#free)
         log("index = " .. index)
         local p = free[index]
         table.remove(free, index)
         log("Trying cell " .. p.x .. ", " .. p.y)
         if count_neighbors(block, p.x, p.y) <= 1 then
            block[p.x .. "_" .. p.y] = true
            add_neighbors(free, block, p.x, p.y)
         end
      end
      -- clear free space in the center
      block[0 .. "_" .. 0] = nil
   end
   return block
end

function Maze.wallTileAt(maze, x, y)
   log("Maze.wallTileAt(maze, " .. x .. ", " .. y .. ")")
   local bx = math.floor(x / block_size + 0.5)
   local by = math.floor(y / block_size + 0.5)
   local block = Maze.get_block(maze, bx, by)
   local dx = x - bx * block_size
   local dy = y - by * block_size
   log("  inside block (" .. dx .. ", " .. dy ..")")
   return block[dx .. "_" .. dy]
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
        return Maze.checkCorridor_(maze, x, y, direction, y, 2)
    else
        return {corridorLength = 0, yHighest = y}
    end
end

