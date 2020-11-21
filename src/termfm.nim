import os, strutils, times, osproc, tables, posix, algorithm
import types, xresources, lscolors
import imlib2
import x11 / [x, xlib, xutil]

converter intToCint(x: int): cint = x.cint
converter intToCuint(x: int): cuint = x.cuint
converter pintToPcint(x: ptr int): ptr cint = cast[ptr cint](x)
converter boolToXBool(x: bool): XBool = x.XBool
converter xboolToBool(x: XBool): bool = x.bool

type Entry = object
  name: string
  path: string
  icon: string
  directory: bool
  color: Color

var
  disp: PDisplay
  vis: PVisual
  cm: Colormap
  depth: int
  ev: XEvent
  vinfo: XVisualInfo
  updates: ImlibUpdates
  width = 200
  height = 200
  winId = parseInt(paramStr(1))
  currentPath = getCurrentDir()
  offset = 0
  entries: seq[Entry]

disp  = XOpenDisplay(nil)
vis   = DefaultVisual(disp, DefaultScreen(disp))
depth = DefaultDepth(disp, DefaultScreen(disp))
cm    = DefaultColormap(disp, DefaultScreen(disp))

# Prepare common window attributes
discard XMatchVisualInfo(disp, DefaultScreen(disp), 32, TrueColor, vinfo.addr) == 1 or
        XMatchVisualInfo(disp, DefaultScreen(disp), 24, TrueColor, vinfo.addr) == 1 or
        XMatchVisualInfo(disp, DefaultScreen(disp), 16, DirectColor, vinfo.addr) == 1 or
        XMatchVisualInfo(disp, DefaultScreen(disp), 8, PseudoColor, vinfo.addr) == 1

var wa: XSetWindowAttributes
wa.overrideRedirect = true
wa.backgroundPixmap = None
wa.backgroundPixel = 0
wa.borderPixel = 0 #((args.border.a shl 24) or (args.border.r shl 16) or (args.border.g shl 8) or args.border.b).uint
wa.colormap = XCreateColormap(disp, DefaultRootWindow(disp), vinfo.visual, AllocNone)
wa.eventMask =
    ExposureMask or KeyPressMask or VisibilityChangeMask or
    ButtonReleaseMask or FocusChangeMask or StructureNotifyMask

# Set up Imlib stuff
let homedir = getEnv("HOME")
if homedir.len != 0:
  imlib_add_path_to_font_path(homedir & "/.local/share/fonts")
  imlib_add_path_to_font_path(homedir & "/.fonts")
imlib_add_path_to_font_path("/usr/local/share/fonts")
imlib_add_path_to_font_path("/usr/share/fonts/truetype")
imlib_add_path_to_font_path("/usr/share/fonts/truetype/dejavu")
imlib_add_path_to_font_path("/usr/share/fonts/TTF")
imlib_set_cache_size(2048 * 1024)
imlib_set_font_cache_size(512 * 1024)
imlib_set_color_usage(128)
imlib_context_set_dither(1)
imlib_context_set_display(disp)
imlib_context_set_visual(vinfo.visual)
imlib_context_set_colormap(wa.colormap)

var
  folderIcon = getAppDir() / "icons/folder.png"
  fileIcon =  getAppDir() / "icons/file.png"
  fontName = "JetBrains Mono Medium Nerd Font Complete Mono/10"
  #bg = Color(r: 40, g: 42, b: 52, a: 255)
  #text = Color(r: 80, g: 250, b: 23, a: 255)

var
  win = XCreateWindow(disp, DefaultRootWindow(disp), 0, 0, width, height, 0,
    vinfo.depth, InputOutput, vinfo.visual,
    CWBackPixmap or CWBackPixel or CWBorderPixel or
    CWColormap or CWEventMask, wa.addr)
  deleteAtom = XInternAtom(disp, "WM_DELETE_WINDOW", true)
  customFolder = XInternAtom(disp, "_CUSTOM_FOLDER", true)
  resources = loadColors()
  colors = resources.loadColors()

discard XSetWMProtocols(disp, win, deleteAtom.addr, 1)
discard XSelectInput(disp, win, KeyPressMask or ButtonPressMask or ButtonReleaseMask or
            PointerMotionMask or ExposureMask or StructureNotifyMask)
discard XSelectInput(disp, winId.Window, PropertyChangeMask)
discard XMapWindow(disp, win)

proc getProperty(window: Window, name: Atom): string =
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    nitemsReturn: culong
    bytesAfterReturn: culong
    propReturn: cstring
  discard XGetWindowProperty(disp, window,
    name, 0, clong.high, false, XInternAtom(disp, "STRING", false),
    actual_type_return.addr, actual_format_return.addr, nitems_return.addr,
    bytes_after_return.addr, cast[PPcuchar](prop_return.addr))
  doAssert nitemsReturn > 0.culong
  result = $prop_return
  discard XFree(prop_return)

proc updateEntries() =
  entries = @[Entry(name: "..", path: currentPath & "/..", icon: folderIcon, directory: true, color: colors.directory)]
  for fullPath in walkPattern(currentPath & "/*"):
    let
      relPath = fullPath.relativePath(currentPath)
      extension = relPath.splitFile()[2]
    var s: Stat
    discard lstat(fullPath, s)
    let mode = s.st_mode
    entries.add Entry(name: relPath, path: fullPath, directory: false)
    case mode.cint and S_IFMT:
    of S_IFDIR:
      entries[^1].color = colors.directory
      entries[^1].directory = true
      entries[^1].icon = folderIcon
    of S_IFREG:
      entries[^1].color = colors.extensions.getOrDefault(extension, colors.file)
      entries[^1].icon = fileIcon
    of S_IFLNK:
      entries[^1].color = if fullPath.fileExists(): colors.link else: colors.orphan
      entries[^1].icon = fileIcon
    of S_IFCHR:
      entries[^1].color = colors.charDevice
      entries[^1].icon = fileIcon
    of S_IFBLK:
      entries[^1].color = colors.blockDevice
      entries[^1].icon = fileIcon
    of S_IFIFO:
      entries[^1].color = colors.pipe
      entries[^1].icon = fileIcon
    else:
      entries[^1].color = colors.normal
      entries[^1].icon = fileIcon
    if (mode.cint and (S_IXUSR or S_IXGRP or S_IXOTH)) != 0 and not S_ISLNK(mode) and not S_ISDIR(mode):
      entries[^1].color = colors.executable
  entries.sort proc (x, y: Entry): int =
    if x.directory == y.directory:
      cmp(x.name, y.name)
    else:
      if x.directory: -1
      else: 1

updateEntries()
while true:
  while updates == nil or XPending(disp) > 0:
    discard XNextEvent(disp, ev.addr)
    case ev.theType:
    of Expose:
      updates = imlib_update_append_rect(
        updates,
        ev.xexpose.x, ev.xexpose.y,
        ev.xexpose.width, ev.xexpose.height)
    of ConfigureNotify:
      updates = imlib_update_append_rect(
        updates,
        0, 0, width, height)
      width = ev.xconfigure.width
      height = ev.xconfigure.height
      updates = imlib_update_append_rect(
        updates,
        0, 0, width, height)
    of ClientMessage:
      if ev.xclient.data.l[0] == deleteAtom.clong:
        quit 0
    of ButtonRelease:
      case ev.xbutton.button:
      of 1:
        var
          x = 32
          y = 32 - offset * 64
        for entry in entries:
          if not entry.directory: break
          var
            font = imlib_load_font(fontName)
            tw = 0
            th = 0
          imlib_context_set_font(font)
          imlib_get_text_size(entry.name[0].unsafeAddr, tw.addr, th.addr)
          if ev.xbutton.x > x and ev.xbutton.x < x + 64 and ev.xbutton.y > y and ev.xbutton.y < y + 64 + th:
            discard execCmd("xdotool type --delay 0 --window " & $winId & " \" cd " & entry.path & "\n\"")
          x += 64 + 32
          if x + 64 + 32 > width:
            y += 64 + 32 + th
            x = 32
      of 4: dec offset
      of 5: inc offset
      else:
        discard
      if offset < 0: offset = 0
      updates = imlib_update_append_rect(
        updates,
        0, 0, width, height)
    of PropertyNotify:
      if ev.xproperty.atom == customFolder:
        let newPath = getProperty(winId.Window, customFolder)
        if newPath != currentPath:
          offset = 0
          currentPath = newPath
        updateEntries()
        updates = imlib_update_append_rect(
          updates,
          0, 0, width, height)
    of KeyPress:
      discard
    else:
      discard

  updates = imlib_updates_merge_for_rendering(updates, width, height)
  var currentUpdate = updates
  while currentUpdate != nil:
    imlib_context_set_drawable(win)
    var up_x, up_y, up_w, up_h: int

    # find out where the first update is
    imlib_updates_get_coordinates(currentUpdate,
                                  up_x.addr, up_y.addr, up_w.addr, up_h.addr);

    # create our buffer image for rendering this update
    var buffer = imlib_create_image(up_w, up_h);
    imlib_context_set_image(buffer)
    imlib_image_set_has_alpha(1)
    imlib_context_set_blend(1)
    imlib_image_clear()
    imlib_context_set_color(resources.background.r, resources.background.g, resources.background.b, resources.background.a)
    imlib_image_fill_rectangle(-upX, -upY, width, height)
    imlib_context_set_blend(1)
    var
      x = -upX + 32
      y = -upY + 32 - offset * 64
    for entry in entries:
      let image = imlib_load_image(entry.icon)
      imlib_context_set_image(buffer)
      imlib_blend_image_onto_image(image, 255, 0, 0,
        64, 64, x, y, 64, 64)
      imlib_context_set_image(image)
      imlib_free_image()
      var
        font = imlib_load_font(fontName)
        tw = 0
        th = 0
      imlib_context_set_font(font)
      imlib_get_text_size(entry.name[0].unsafeAddr, tw.addr, th.addr)
      var textBuffer = imlib_create_image(96, th)
      imlib_context_set_image(textBuffer)
      imlib_image_set_has_alpha(1)
      imlib_image_clear()
      imlib_context_set_color(entry.color.r, entry.color.g, entry.color.b, entry.color.a)
      imlib_text_draw((96 div 2) - (min(tw, 96) div 2), 0, entry.name[0].unsafeAddr)
      imlib_free_font()
      imlib_context_set_image(buffer)
      imlib_context_set_blend(1)
      imlib_blend_image_onto_image(textBuffer, 255, 0, 0, 96, th, x - 16, y + 64, 96, th)
      imlib_context_set_image(textBuffer)
      imlib_free_image()
      x += 64 + 32
      if x + 64 + 32 > width:
        y += 64 + 32 + th
        x = 32
    imlib_context_set_blend(0)
    # set the buffer image as our current image
    imlib_context_set_image(buffer)
    # render the image at 0, 0
    imlib_render_image_on_drawable(up_x, up_y)
    # don't need that temporary buffer image anymore
    imlib_free_image()
    currentUpdate = imlib_updates_get_next(currentUpdate)

  # if we had updates - free them
  if updates != nil:
    imlib_updates_free(updates)
    updates = nil
