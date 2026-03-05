module EnterpriseColorsHelper
  def enterprise_custom_colors_tag
    settings = current_enterprise&.settings
    return unless settings

    primary = settings.primary_color.presence
    secondary = settings.secondary_color.presence
    return unless primary || secondary

    css = ":root {\n"

    if primary
      css += "  --primary: #{primary};\n"
      css += "  --primary-light: #{lighten_color(primary, 0.85)};\n"
      css += "  --primary-muted: #{lighten_color(primary, 0.92)};\n"
      css += "  --ring: #{primary};\n"
      css += "  --success: #{primary};\n"
      css += "  --success-light: #{lighten_color(primary, 0.85)};\n"
      css += "  --sidebar-icon-active: #{primary};\n"
      css += "  --sidebar-active-bg: #{lighten_color(primary, 0.92)};\n"
    end

    if secondary
      css += "  --secondary: #{secondary};\n"
    end

    css += "}\n"

    # Dark mode variants
    if primary
      css += ".dark {\n"
      css += "  --primary: #{lighten_color(primary, 0.2)};\n"
      css += "  --primary-light: #{darken_color(primary, 0.7)};\n"
      css += "  --primary-muted: #{darken_color(primary, 0.85)};\n"
      css += "  --ring: #{lighten_color(primary, 0.2)};\n"
      css += "  --success: #{lighten_color(primary, 0.2)};\n"
      css += "  --success-light: #{darken_color(primary, 0.7)};\n"
      css += "  --sidebar-icon-active: #{lighten_color(primary, 0.2)};\n"
      css += "  --sidebar-active-bg: #{darken_color(primary, 0.85)};\n"

      if secondary
        css += "  --secondary: #{lighten_color(secondary, 0.6)};\n"
      end

      css += "}\n"
    end

    tag.style(css.html_safe, nonce: true)
  end

  def enterprise_pdf_primary_color
    current_enterprise&.settings&.primary_color.presence || "#059669"
  end

  def enterprise_pdf_secondary_color
    current_enterprise&.settings&.secondary_color.presence || "#374151"
  end

  private

  def hex_to_rgb(hex)
    hex = hex.delete("#")
    [ hex[0..1], hex[2..3], hex[4..5] ].map { |c| c.to_i(16) }
  end

  def rgb_to_hex(r, g, b)
    "#%02x%02x%02x" % [ r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255) ]
  end

  def lighten_color(hex, amount)
    r, g, b = hex_to_rgb(hex)
    rgb_to_hex(
      (r + (255 - r) * amount).round,
      (g + (255 - g) * amount).round,
      (b + (255 - b) * amount).round
    )
  end

  def darken_color(hex, amount)
    r, g, b = hex_to_rgb(hex)
    rgb_to_hex(
      (r * (1 - amount)).round,
      (g * (1 - amount)).round,
      (b * (1 - amount)).round
    )
  end
end
