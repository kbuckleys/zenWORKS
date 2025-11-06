-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

return {
  {
    "nvim-mini/mini.hipatterns",
    opts = function()
      local hipatterns = require("mini.hipatterns")

      local rgba_color = function(_, match)
        local r, g, b, a = match:match("rgba%((%d+),%s*(%d+),%s*(%d+),%s*(%d*%.?%d+)%)")
        a = tonumber(a)
        if not a or a < 0 or a > 1 then
          return false
        end
        r, g, b = math.floor(r * a), math.floor(g * a), math.floor(b * a)
        local hex = string.format("#%02x%02x%02x", r, g, b)
        return hipatterns.compute_hex_color_group(hex, "bg")
      end

      local hex_alpha_color = function(_, match)
        local hex = match
        if not hex:match("^#") then
          hex = "#" .. hex
        end
        local a, r, g, b = hex:sub(2, 3), hex:sub(4, 5), hex:sub(6, 7), hex:sub(8, 9)
        local alpha = tonumber(a, 16) / 255
        local red = tonumber(r, 16)
        local green = tonumber(g, 16)
        local blue = tonumber(b, 16)
        red = math.floor(red * alpha)
        green = math.floor(green * alpha)
        blue = math.floor(blue * alpha)
        local hex_color = string.format("#%02x%02x%02x", red, green, blue)
        return hipatterns.compute_hex_color_group(hex_color, "bg")
      end

      return {
        highlighters = {
          hex_color = hipatterns.gen_highlighter.hex_color({ priority = 2000, group = "bg" }),
          rgba_color = {
            pattern = "rgba%(%d+, ?%d+, ?%d+, ?%d*%.?%d*%)",
            group = rgba_color,
          },
          hex_alpha = {
            pattern = "#?%x%x%x%x%x%x%x%x",
            group = hex_alpha_color,
          },
        },
      }
    end,
    config = function(_, opts)
      require("mini.hipatterns").setup(opts)
    end,
  },
}
