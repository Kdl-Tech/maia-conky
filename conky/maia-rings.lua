--[[ MAIA conky — jauges circulaires Cairo
     Dessine 3 anneaux (CPU / RAM / Disque) avec icône + % au centre.
     Robuste : tout est sous pcall, si Cairo échoue le texte conky reste affiché. ]]

require 'cairo'
pcall(require, 'cairo_xlib')

-- Compat conky récent : fournir cairo_xlib_surface_create si absent
if not pcall(function() return cairo_xlib_surface_create end) or cairo_xlib_surface_create == nil then
    -- certains builds exposent la fonction via le module cairo_xlib déjà chargé
end

local function hex(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255.,
           ((colour / 0x100) % 0x100) / 255.,
           (colour % 0x100) / 255., alpha
end

-- couleur dynamique : vert -> cyan -> magenta selon la charge
local function load_colour(pct)
    if pct < 0.55 then return 0x00FF99
    elseif pct < 0.80 then return 0x00E5FF
    else return 0xFF4FD8 end
end

-- centre un texte horizontalement autour de cx et l'écrit à la baseline cy
local function centered_text(cr, txt, cx, cy)
    local e = cairo_text_extents_t.create()
    cairo_text_extents(cr, txt, e)
    cairo_move_to(cr, cx - (e.width / 2 + e.x_bearing), cy)
    cairo_show_text(cr, txt)
end

local function draw_ring(cr, pct, r)
    -- piste de fond : cercle COMPLET (new_sub_path = pas de ligne parasite)
    cairo_set_line_width(cr, r.thickness)
    cairo_new_sub_path(cr)
    cairo_arc(cr, r.x, r.y, r.radius, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, hex(0x16252E, 0.90))
    cairo_stroke(cr)

    -- valeur : part du haut (midi), sens horaire, bout arrondi
    if pct > 0 then
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
        local a0 = -math.pi / 2
        cairo_new_sub_path(cr)
        cairo_arc(cr, r.x, r.y, r.radius, a0, a0 + pct * 2 * math.pi)
        cairo_set_source_rgba(cr, hex(load_colour(pct), 0.95))
        cairo_stroke(cr)
    end

    -- icône (Nerd Font) en haut du centre
    cairo_select_font_face(cr, "JetBrainsMono Nerd Font", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, 16)
    cairo_set_source_rgba(cr, hex(0xC7DCE0, 0.95))
    centered_text(cr, r.icon, r.x, r.y - 3)

    -- pourcentage sous l'icône
    cairo_select_font_face(cr, "JetBrainsMono Nerd Font", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 13)
    cairo_set_source_rgba(cr, hex(load_colour(pct), 1.0))
    centered_text(cr, string.format("%d%%", math.floor(pct * 100 + 0.5)), r.x, r.y + 15)

    -- label sous l'anneau
    cairo_select_font_face(cr, "JetBrainsMono Nerd Font", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, 10)
    cairo_set_source_rgba(cr, hex(0x6E8693, 1.0))
    centered_text(cr, r.label, r.x, r.y + r.radius + 17)
end

-- 3 anneaux : positions relatives à la fenêtre conky (largeur 360)
local rings = {
    { x = 64,  y = 150, radius = 32, thickness = 9,
      arg = "${cpu cpu0}", max = 100, icon = "\u{f4bc}", label = "CPU" },   -- cpu chip
    { x = 180, y = 150, radius = 32, thickness = 9,
      arg = "${memperc}",  max = 100, icon = "\u{efc5}", label = "RAM" },   -- memory
    { x = 296, y = 150, radius = 32, thickness = 9,
      arg = "${fs_used_perc /home}", max = 100, icon = "\u{f0a0}", label = "HOME" }, -- disk
}

function conky_main()
    if conky_window == nil then return end
    local ok, err = pcall(function()
        local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                             conky_window.visual, conky_window.width, conky_window.height)
        local cr = cairo_create(cs)
        local updates = tonumber(conky_parse('${updates}')) or 0
        if updates > 3 then
            for _, r in ipairs(rings) do
                local v = tonumber(conky_parse(r.arg)) or 0
                local pct = v / r.max
                if pct > 1 then pct = 1 elseif pct < 0 then pct = 0 end
                draw_ring(cr, pct, r)
            end
        end
        cairo_destroy(cr)
        cairo_surface_destroy(cs)
    end)
    -- en cas d'erreur Cairo, on ignore silencieusement (le texte conky reste)
end
