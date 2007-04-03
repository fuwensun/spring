--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    fonts.lua
--  brief:   font handler, uses texture atlases from BZFlag
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (fontHandler ~= nil) then
  return fontHandler
end


local DefaultFontName = "ProFont_12"
local DefaultFontName = "test"


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local fonts = {}
local activeFont  = nil
local defaultFont = nil

local fontDir = LUAUI_DIRNAME .. "Fonts/"

local timeStamp  = 0
local lastUpdate = 0

local debug = true
local origPrint = print
local print = function(...)
  if (debug) then
    origPrint(unpack(arg))
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function LoadFontSpecs(fontName)
  local filename = fontDir .. fontName .. ".fmt"

  local f = io.open(filename, "r")
  if (not f) then
    print("failed to open: " .. filename)
    return nil
  end

  local fontSpecs = {}
  fontSpecs.chars = {}
  fontSpecs.name = filename
  fontSpecs.xTexSize = -1
  fontSpecs.yTexSize = -1

  local currChar
  for line in f:lines() do
    if ((string.len(line) > 0) and (string.sub(line, 1, 1) ~= '#')) then
      local words = {}
      for w in string.gfind(line, "[^%s]+") do
        table.insert(words, w)
      end
      local cmd = words[1]
      table.remove(words, 1, 1)
      p1 = words[1]
      p2 = words[2]
      p3 = words[3]
      p4 = words[4]

      if (cmd == 'yStep:') then
        fontSpecs.yStep = tonumber(p1)
      elseif (cmd == 'height:') then
        fontSpecs.height = tonumber(p1)
      elseif (cmd == 'xTexSize:') then
        fontSpecs.xTexSize = tonumber(p1)
      elseif (cmd == 'yTexSize:') then
        fontSpecs.yTexSize = tonumber(p1)
      elseif (cmd == 'glyph:') then
        local c = tonumber(p1)
        if (currChar) then
          fontSpecs.chars[currChar.char] = currChar
        end
        currChar = { char = c }
      elseif (cmd == 'advance:') then
        currChar.adv = tonumber(p1)
      elseif (cmd == 'offsets:') then
        currChar.oxn = tonumber(p1)
        currChar.oyn = tonumber(p2)
        currChar.oxp = tonumber(p3)
        currChar.oyp = tonumber(p4)
      elseif (cmd == 'texcoords:') then
        currChar.txn = tonumber(p1)
        currChar.tyn = tonumber(p2)
        currChar.txp = tonumber(p3)
        currChar.typ = tonumber(p4)
      else
        print("Unknown font character parameter: " .. line)
      end
    end
  end

  if (currChar) then
    fontSpecs.chars[currChar.char] = currChar
  end

  print('fontSpecs.name     ', fontSpecs.name)
  print('fontSpecs.yStep    ', fontSpecs.yStep)
  print('fontSpecs.height   ', fontSpecs.height)
  print('fontSpecs.xTexSize ', fontSpecs.xTexSize)
  print('fontSpecs.yTexSize ', fontSpecs.yTexSize)
--[[
  for _,c in pairs(fontSpecs.chars) do
    print("glyph = " .. c.char .. " '" .. string.char(c.char) .. "'")
    print("  advance   " .. c.adv)
    print("  offsets   " .. c.oxn .." "..c.oyn.." "..c.oxp.." "..c.oyp)
    print("  texcoords " .. c.txn .." "..c.tyn.." "..c.txp.." "..c.typ)
  end
--]]

  f:close()

  return fontSpecs
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function MakeDisplayLists(fontSpecs)
  local lists = {}
  local xs = fontSpecs.xTexSize
  local ys = fontSpecs.yTexSize
  for _,gi in pairs(fontSpecs.chars) do
    local list = gl.ListCreate(function ()
      gl.TexRect(gi.oxn, gi.oyn, gi.oxp, gi.oyp,
                 gi.txn / xs, 1.0 - (gi.tyn / ys),
                 gi.txp / xs, 1.0 - (gi.typ / ys))
      gl.Translate(gi.adv, 0, 0)
    end)
    lists[gi.char] = list
  end
  return lists
end


local function MakeOutlineDisplayLists(fontSpecs)
  local lists = {}
  local tw = fontSpecs.xTexSize
  local th = fontSpecs.yTexSize

  for _,gi in pairs(fontSpecs.chars) do
    local w = gi.xmax - gi.xmin
    local h = gi.ymax - gi.ymin
    local txn = gi.xmin / tw
    local tyn = gi.ymax / th
    local txp = gi.xmax / tw
    local typ = gi.ymin / th
    
    local list = gl.ListCreate(function ()
      gl.Translate(gi.initDist, 0, 0)

      gl.Color(0, 0, 0, 0.75)
      local o = 2
      gl.TexRect( o,  o, w, h, txn, tyn, txp, typ)
      gl.TexRect(-o,  o, w, h, txn, tyn, txp, typ)
      gl.TexRect( o,  0, w, h, txn, tyn, txp, typ)
      gl.TexRect(-o,  0, w, h, txn, tyn, txp, typ)
      gl.TexRect( o, -o, w, h, txn, tyn, txp, typ)
      gl.TexRect(-o, -o, w, h, txn, tyn, txp, typ)
      gl.TexRect( 0,  o, w, h, txn, tyn, txp, typ)
      gl.TexRect( 0, -o, w, h, txn, tyn, txp, typ)

      gl.Color(1, 1, 1, 1)
      gl.TexRect( 0,  0, w, h, txn, tyn, txp, typ)

      gl.Translate(gi.width + gi.whitespace, 0, 0)
    end)

    lists[gi.char] = list
  end
  return lists
end


--------------------------------------------------------------------------------

local function CalcTextWidth(text)
  local specs = activeFont.specs
  local w = 0
  for i = 1, string.len(text) do
    local c = string.byte(text, i)
    local glyphInfo = specs.chars[c]
    if (not glyphInfo) then
      glyphInfo = specs.chars[32]
    end
    if (glyphInfo) then
      w = w + glyphInfo.adv
    end
  end
  return w
end


local function CalcTextHeight(text)
end


--------------------------------------------------------------------------------

local function RawDraw(text)
  local lists = activeFont.lists
  gl.Texture(activeFont.image)
  for i = 1, string.len(text) do
    local c = string.byte(text, i)
    local list = lists[c]
    if (list) then
      gl.ListRun(list)
    else
      gl.ListRun(lists[string.byte(" ", 1)])
    end
  end
end


local function DrawNoCache(text, x, y, size, opts)
--local function Draw(text, x, y, size, opts) -- FIXME
  if (not x) then
    RawDraw(text)
  else
    gl.PushMatrix()
    gl.Translate(x, y, 0)
    RawDraw(text)
    gl.PopMatrix()
  end
end


local function Draw(text, x, y, size, opts) -- FIXME
  local cacheTextData = activeFont.cache[text]
  if (not cacheTextData) then
    local textList = gl.ListCreate(function() RawDraw(text) end)
    cacheTextData = { textList, timeStamp }
    activeFont.cache[text] = cacheTextData
  else
    cacheTextData[2] = timeStamp  --  refresh the timeStamp
  end
  if (not x) then
    gl.ListRun(cacheTextData[1])
  else
    gl.PushMatrix()
    gl.Translate(x, y, 0)
    gl.ListRun(cacheTextData[1])
    gl.PopMatrix()
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function LoadFont(fontName)
  if (fonts[fontName]) then
    return nil  -- already loaded
  end

  local baseName = fontName
  local _,_,options,bn = string.find(fontName, "(:.-:)(.*)")
  if (options) then
    baseName = bn
  else
    options = ""
  end

  local fontSpecs = LoadFontSpecs(baseName)
  if (not fontSpecs) then
    return nil  -- bad specs
  end

  local fontLists
  if (string.find(options, "o")) then
    fontLists = MakeOutlineDisplayLists(fontSpecs)
  else
    fontLists = MakeDisplayLists(fontSpecs)
  end
  if (not fontLists) then
    return nil  -- bad display lists
  end

  local font = {}
  font.name  = fontName
  font.base  = baseName
  font.opts  = options
  font.specs = fontSpecs
  font.lists = fontLists
  font.cache = {}
  font.image = options .. fontDir .. baseName .. ".png"
  font.size  = 12.0  -- FIXME

  return font
end


local function SetFont(fontName)
  local font = fonts[fontName]
  if (font) then
    activeFont = font
    return
  end

  font = LoadFont(fontName)
  if (font) then
    print("Loaded font: " .. fontName)
    activeFont = font
    fonts[fontName] = font
    return
  end
end


local function SetDefaultFont()
  activeFont = defaultFont
end


--------------------------------------------------------------------------------

local function FreeCache(fontName)
  local font = fonts[fontName]
  if (not font) then
    return
  end
  for text,data in pairs(font.cache) do
    gl.ListDelete(data[1])
  end
end


local function FreeFont(fontName)
  local font = fonts[fontName]
  if (not font) then
    return
  end

  for _,list in pairs(font.lists) do
    gl.ListDelete(list)
  end
  for text,data in pairs(font.cache) do
    gl.ListDelete(data[1])
  end
  gl.FreeTexture(font.image)

  fonts[font.name] = nil
end


local function FreeFonts()
  for fontName in pairs(fonts) do
    FreeFont(fontName)
  end
end


local function Update(time)
  timeStamp = time
  if (timeStamp < (lastUpdate + 3)) then
    return  -- only update every 3 seconds
  end

  local killTime = (time - 30)
  for fontName, font in pairs(fonts) do
    local killList = {}
    for text,data in pairs(font.cache) do
      if (data[2] < killTime) then
        gl.ListDelete(data[1])
        table.insert(killList, text)
        print(fontName .. " removed string list(" .. data[1] .. ") " .. text)
      end
    end
    for _,text in ipairs(killList) do
      font.cache[text] = nil
    end
  end
  lastUpdate = timeStamp
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

SetFont(DefaultFontName)
defaultFont = activeFont


local FH = {}

FH.Update = Update

FH.SetFont        = SetFont
FH.SetDefaultFont = SetDefaultFont

FH.FreeFont  = FreeFont
FH.FreeFonts = FreeFonts
FH.FreeCache = FreeCache

FH.Draw        = Draw
FH.DrawNoCache = DrawNoCache

FH.CalcTextWidth  = CalcTextWidth
FH.CalcTextHeight = CalcTextHeight

fontHandler = FH  -- make it global

return FH

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
