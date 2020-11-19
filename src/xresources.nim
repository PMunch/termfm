import osproc, strutils
import types

type
  XResources* = object
    background*: Color
    colors*: array[16, Color]
    cursorColor*: Color
    foreground*: Color

proc parseColor(hex: string): Color =
  result.r = parseHexInt(hex[1..2])
  result.g = parseHexInt(hex[3..4])
  result.b = parseHexInt(hex[5..6])
  result.a = 255

proc loadColors*(): XResources =
  for line in execProcess("xrdb -query").splitLines:
    let pair = line.split ":\t"
    if pair.len != 2: continue
    let
      key = pair[0]
      value = pair[1]
    case key:
    of "*.background": result.background = parseColor(value)
    of "*.color0": result.colors[0] = parseColor(value)
    of "*.color1": result.colors[1] = parseColor(value)
    of "*.color10": result.colors[10] = parseColor(value)
    of "*.color11": result.colors[11] = parseColor(value)
    of "*.color12": result.colors[12] = parseColor(value)
    of "*.color13": result.colors[13] = parseColor(value)
    of "*.color14": result.colors[14] = parseColor(value)
    of "*.color15": result.colors[15] = parseColor(value)
    of "*.color2": result.colors[2] = parseColor(value)
    of "*.color3": result.colors[3] = parseColor(value)
    of "*.color4": result.colors[4] = parseColor(value)
    of "*.color5": result.colors[5] = parseColor(value)
    of "*.color6": result.colors[6] = parseColor(value)
    of "*.color7": result.colors[7] = parseColor(value)
    of "*.color8": result.colors[8] = parseColor(value)
    of "*.color9": result.colors[9] = parseColor(value)
    of "*.cursorColor": result.cursorColor = parseColor(value)
    of "*.foreground": result.foreground = parseColor(value)
    else: discard

when isMainModule:
  echo loadColors()

