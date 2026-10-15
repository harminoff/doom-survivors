// UI kit: the frames, bars, slots and hints every screen draws.  Art comes
// from tools/art/ui_art.py (DSUI* frames, DSIC* icons, the smallfont and
// bigfont folders).  Coordinates are the shared 640x400 virtual space
// (DSShellMenu.Scale/OffX/OffY); one texture pixel is one virtual unit.
// Presentation only: nothing here reads or changes game rules.

class DSUi ui
{
    // Virtual -> screen, rounded so neighbouring 9-slice pieces never seam.
    static int SX(double x) { return int(DSShellMenu.OffX() + x * DSShellMenu.Scale() + 0.5); }
    static int SY(double y) { return int(DSShellMenu.OffY() + y * DSShellMenu.Scale() + 0.5); }

    static void Part(TextureID tex, double sx, double sy, double sw, double sh, int x0, int y0, int x1, int y1, double alpha)
    {
        if (x1 <= x0 || y1 <= y0) return;
        Screen.DrawTexture(tex, false, x0, y0,
            DTA_SrcX, sx, DTA_SrcY, sy, DTA_SrcWidth, sw, DTA_SrcHeight, sh,
            DTA_DestWidthF, double(x1 - x0), DTA_DestHeightF, double(y1 - y0), DTA_Alpha, alpha);
    }

    // Draws texture `name` stretched over the box, corners `border` units
    // square and kept unscaled, edges and centre stretched.
    static void Slice9(String name, double x, double y, double w, double h, double border, double alpha = 1.0)
    {
        TextureID tex = TexMan.CheckForTexture(name, TexMan.Type_Any);
        if (!tex.IsValid()) return;
        Vector2 size = TexMan.GetScaledSize(tex);
        double b = min(border, min(w, h) / 2.0);
        double tw = size.x; double th = size.y;
        int x0 = SX(x); int x1 = SX(x + b); int x2 = SX(x + w - b); int x3 = SX(x + w);
        int y0 = SY(y); int y1 = SY(y + b); int y2 = SY(y + h - b); int y3 = SY(y + h);
        double m = tw - 2 * border; double n = th - 2 * border;
        Part(tex, 0, 0, border, border, x0, y0, x1, y1, alpha);
        Part(tex, border, 0, m, border, x1, y0, x2, y1, alpha);
        Part(tex, tw - border, 0, border, border, x2, y0, x3, y1, alpha);
        Part(tex, 0, border, border, n, x0, y1, x1, y2, alpha);
        Part(tex, border, border, m, n, x1, y1, x2, y2, alpha);
        Part(tex, tw - border, border, border, n, x2, y1, x3, y2, alpha);
        Part(tex, 0, th - border, border, border, x0, y2, x1, y3, alpha);
        Part(tex, border, th - border, m, border, x1, y2, x2, y3, alpha);
        Part(tex, tw - border, th - border, border, border, x2, y2, x3, y3, alpha);
    }

    // A riveted gunmetal panel; focused panels glow hellfire orange.
    static void Panel(double x, double y, double w, double h, bool focused = false, double alpha = 1.0)
    {
        Slice9(focused ? "DSUIPNLF" : "DSUIPNL", x, y, w, h, 8, alpha);
    }

    const BTN_NORMAL = 0;
    const BTN_FOCUS = 1;
    const BTN_OFF = 2;

    static void Button(double x, double y, double w, double h, int state)
    {
        Slice9(state == BTN_FOCUS ? "DSUIBTNF" : (state == BTN_OFF ? "DSUIBTND" : "DSUIBTN"), x, y, w, h, 4);
    }

    // List rows: alternating dark bands, the focused row as a lit button.
    static void Row(double x, double y, double w, double h, bool focused, bool odd)
    {
        if (focused) { Button(x, y, w, h, BTN_FOCUS); return; }
        Fill(odd ? Color(30, 24, 24) : Color(20, 16, 17), 0.9, x, y, w, h);
    }

    static void Slot(double x, double y, double size, bool gold = false)
    {
        Slice9(gold ? "DSUISLTG" : "DSUISLOT", x, y, size, size, 4);
    }

    static void Fill(Color c, double alpha, double x, double y, double w, double h)
    {
        int x0 = SX(x); int y0 = SY(y);
        Screen.Dim(c, alpha, x0, y0, SX(x + w) - x0, SY(y + h) - y0);
    }

    // Framed bar with a gradient fill (DSUIXP, DSUIHP); `trail` (> frac)
    // shows a pale strip that drains after a hit.
    static void Bar(double x, double y, double w, double h, double frac, String fill, double trail = -1)
    {
        Slice9("DSUIBAR", x, y, w, h, 3);
        double iw = w - 6;
        TextureID trailTex = TexMan.CheckForTexture("DSUITRL", TexMan.Type_Any);
        if (trail > frac && trailTex.IsValid())
            Screen.DrawTexture(trailTex, false, SX(x + 3), SY(y + 3), DTA_DestWidthF, double(SX(x + 3 + iw * clamp(trail, 0.0, 1.0)) - SX(x + 3)),
                DTA_DestHeightF, double(SY(y + h - 3) - SY(y + 3)), DTA_Alpha, 0.85);
        TextureID tex = TexMan.CheckForTexture(fill, TexMan.Type_Any);
        if (frac > 0 && tex.IsValid())
            Screen.DrawTexture(tex, false, SX(x + 3), SY(y + 3), DTA_DestWidthF, double(SX(x + 3 + iw * clamp(frac, 0.0, 1.0)) - SX(x + 3)),
                DTA_DestHeightF, double(SY(y + h - 3) - SY(y + 3)));
    }

    static void Pic(String name, double x, double y, double w, double h, double alpha = 1.0, bool grey = false)
    {
        TextureID tex = TexMan.CheckForTexture(name, TexMan.Type_Any);
        if (!tex.IsValid()) return;
        Screen.DrawTexture(tex, false, SX(x), SY(y), DTA_DestWidthF, double(SX(x + w) - SX(x)), DTA_DestHeightF, double(SY(y + h) - SY(y)),
            DTA_Alpha, alpha, DTA_Desaturate, grey ? 255 : 0);
    }

    // Item icon (HI<id>) inside a slot frame; `size` is the frame size.
    static void ItemSlot(int id, double x, double y, double size, bool gold = false, bool seen = true)
    {
        Slot(x, y, size, gold);
        TextureID icon = TexMan.CheckForTexture(String.Format("HI%03d", id), TexMan.Type_Any);
        double pad = max(2.0, size * 0.12);
        if (seen && icon.IsValid()) Pic(String.Format("HI%03d", id), x + pad, y + pad, size - pad * 2, size - pad * 2);
        else DSShellMenu.Text(SmallFont, Font.CR_DARKGRAY, x + size / 2 - 2, y + size / 2 - 5, "?");
    }

    // A two-tone horizontal rule (hot top line, dark bottom line).
    static void Rule(double x, double y, double w, Color hot)
    {
        Fill(hot, 0.95, x, y, w, 1);
        Fill(Color(40, 8, 6), 0.95, x, y + 1, w, 1);
    }

    // Big centred title with tapering rules either side.
    static void Header(double y, String text, int colour, double size = 1.0, double halfWidth = 300)
    {
        double tw = BigFont.StringWidth(text) * size;
        DSShellMenu.CenterText(BigFont, colour, y, text, size);
        double mid = y + BigFont.GetHeight() * size / 2.0 - 1;
        double gap = 10;
        double len = min(140.0, halfWidth - tw / 2.0 - gap - 14);
        if (len < 12) return;
        double left = (DSShellMenu.VW - tw) / 2.0 - gap;
        double right = (DSShellMenu.VW + tw) / 2.0 + gap;
        Rule(left - len, mid - 2, len, Color(230, 110, 30));
        Rule(right, mid - 2, len, Color(230, 110, 30));
        Rule(left - len * 0.6, mid + 2, len * 0.6, Color(150, 40, 20));
        Rule(right, mid + 2, len * 0.6, Color(150, 40, 20));
        Fill(Color(255, 200, 90), 1.0, left - 3, mid - 1, 3, 3);
        Fill(Color(255, 200, 90), 1.0, right, mid - 1, 3, 3);
    }

    // A keycap followed by its label; returns the width used.
    static double KeyHint(double x, double y, String key, String label, bool draw = true)
    {
        double kw = SmallFont.StringWidth(key) + 8;
        if (draw)
        {
            Button(x, y - 3, kw, 15, BTN_NORMAL);
            DSShellMenu.Text(SmallFont, Font.CR_GOLD, x + 4, y, key);
            DSShellMenu.Text(SmallFont, Font.CR_GREY, x + kw + 4, y, label);
        }
        return kw + 4 + SmallFont.StringWidth(label);
    }

    // Centred row of key hints, `spec` = "Key|Label;Key|Label".
    static void Hints(double y, String spec, double centre = 320)
    {
        Array<String> parts;
        spec.Split(parts, ";", TOK_SKIPEMPTY);
        double gap = 14;
        double total = 0;
        for (int i = 0; i < parts.Size(); i++)
        {
            Array<String> kv;
            parts[i].Split(kv, "|");
            total += KeyHint(0, 0, kv[0], kv.Size() > 1 ? kv[1] : "", false) + (i > 0 ? gap : 0);
        }
        double x = centre - total / 2.0;
        for (int i = 0; i < parts.Size(); i++)
        {
            Array<String> kv;
            parts[i].Split(kv, "|");
            x += KeyHint(x, y, kv[0], kv.Size() > 1 ? kv[1] : "") + gap;
        }
    }

    // Label on the left, value right-aligned at `right`.
    static void StatLine(double x, double right, double y, String label, String value, int valueColour, double size = 1.0)
    {
        DSShellMenu.Text(SmallFont, Font.CR_GREY, x, y, label, size);
        DSShellMenu.Text(SmallFont, valueColour, right - SmallFont.StringWidth(value) * size, y, value, size);
    }
}
