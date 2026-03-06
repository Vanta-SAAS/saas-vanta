module ApplicationHelper
  include Pagy::Frontend

  # Breadcrumbs
  def breadcrumb_items
    @breadcrumb_items || []
  end

  def add_breadcrumb(label, path = nil)
    @breadcrumb_items ||= []
    @breadcrumb_items << { label: label, path: path }
  end

  # Form helpers for inline field errors and required marks
  def form_field_class(object, field)
    object.errors[field].any? ? "form-input field-error" : "form-input"
  end

  def form_field_errors(object, field)
    return unless object.errors[field].any?
    content_tag(:p, object.errors[field].first, class: "field-error-message")
  end

  # Sidebar navigation link helper
  # @param name [String] The link text
  # @param path [String] The link path
  # @param icon [String] The Lucide icon name
  # @param sub [Boolean] Whether this is a sub-item (indented)
  def sidebar_link_to(name, path, icon:, sub: false)
    path_str = path.to_s
    uri = URI.parse(path_str) rescue nil
    base_path = uri&.path || path_str
    has_query = uri&.query.present?

    if has_query
      is_active = current_page?(path)
    else
      is_active = current_page?(path) || (path_str != root_path && request.path.start_with?(base_path) && !request.query_string.present?)
    end

    css = "sidebar-nav-item"
    css += " sidebar-nav-sub-item" if sub
    css += " active" if is_active

    link_to path, class: css do
      content_tag(:span, class: "sidebar-nav-icon") do
        sidebar_icon(icon, class: sub ? "w-4 h-4" : "w-5 h-5")
      end +
      content_tag(:span, name, class: "sidebar-nav-text", data: { sidebar_target: "collapsible" })
    end
  end

  def sidebar_nav_group(label, icon:, key:, &block)
    content_tag(:div, class: "nav-group", data: { controller: "nav-group", nav_group_key_value: key }) do
      button = content_tag(:button, type: "button", class: "sidebar-nav-item nav-group-toggle",
        aria: { expanded: "true" },
        data: { action: "click->nav-group#toggle", nav_group_target: "toggle" }) do
        content_tag(:span, class: "sidebar-nav-icon") { sidebar_icon(icon) } +
        content_tag(:span, label, class: "sidebar-nav-text nav-group-label", data: { sidebar_target: "collapsible" }) +
        content_tag(:span, class: "nav-group-chevron nav-group-chevron-open", data: { nav_group_target: "chevron", sidebar_target: "collapsible" }) do
          sidebar_icon("chevron-down", class: "w-3.5 h-3.5")
        end
      end
      items = content_tag(:div, class: "nav-group-items", data: { nav_group_target: "items" }) do
        capture(&block)
      end
      button + items
    end
  end

  # Render a Lucide icon as inline SVG — usable anywhere (sidebar, views, etc.)
  def app_icon(name, options = {})
    sidebar_icon(name, options)
  end

  # @param name [String] The icon name
  # @param options [Hash] Additional options (size, class, color)
  def sidebar_icon(name, options = {})
    icons = {
      "layout-dashboard" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3 3h7v9H3V3zm11 0h7v5h-7V3zm0 9h7v9h-7v-9zM3 16h7v5H3v-5z"/>',
      "package" => '<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 9.4l-9-5.19M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><path stroke-linecap="round" stroke-linejoin="round" d="M3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/>',
      "truck" => '<path stroke-linecap="round" stroke-linejoin="round" d="M1 3h15v13H1V3zm15 8h4l3 3v5h-7v-8zm3 8a2 2 0 100-4 2 2 0 000 4zm-12 0a2 2 0 100-4 2 2 0 000 4z"/>',
      "users" => '<path stroke-linecap="round" stroke-linejoin="round" d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zm14 10v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>',
      "building-2" => '<path stroke-linecap="round" stroke-linejoin="round" d="M6 22V4a2 2 0 012-2h8a2 2 0 012 2v18zm-6 0h24M10 6h4m-4 4h4m-4 4h4"/>',
      "settings" => '<circle cx="12" cy="12" r="3"/><path stroke-linecap="round" stroke-linejoin="round" d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/>',
      "moon" => '<path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/>',
      "sun" => '<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>',
      "log-out" => '<path stroke-linecap="round" stroke-linejoin="round" d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/>',
      "chevrons-left" => '<path stroke-linecap="round" stroke-linejoin="round" d="M11 17l-5-5 5-5M18 17l-5-5 5-5"/>',
      "chevrons-right" => '<path stroke-linecap="round" stroke-linejoin="round" d="M13 17l5-5-5-5M6 17l5-5-5-5"/>',
      "x" => '<path stroke-linecap="round" stroke-linejoin="round" d="M18 6L6 18M6 6l12 12"/>',
      "menu" => '<path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/>',
      "upload" => '<path stroke-linecap="round" stroke-linejoin="round" d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
      "file-text" => '<path stroke-linecap="round" stroke-linejoin="round" d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>',
      "shopping-cart" => '<circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path stroke-linecap="round" stroke-linejoin="round" d="M1 1h4l2.68 13.39a2 2 0 002 1.61h9.72a2 2 0 002-1.61L23 6H6"/>',
      "chevron-down" => '<polyline points="6 9 12 15 18 9"/>',
      "receipt" => '<path stroke-linecap="round" stroke-linejoin="round" d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1-2-1z"/><path d="M16 8h-6a2 2 0 100 4h4a2 2 0 110 4H8"/><path d="M12 17.5v-11"/>',
      "map" => '<polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"/><line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/>',
      "clipboard-list" => '<rect x="8" y="2" width="8" height="4" rx="1" ry="1"/><path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2"/><path d="M12 11h4M12 16h4M8 11h.01M8 16h.01"/>',
      "car" => '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10H1s2.4 1.3 3.6 2.4c.5.5.9 1 1.4 1.6M6 17h9"/><circle cx="17.5" cy="17.5" r="2.5"/><circle cx="8.5" cy="17.5" r="2.5"/>',
      "contact" => '<path d="M17 18a2 2 0 00-2-2H9a2 2 0 00-2 2"/><rect width="18" height="18" x="3" y="4" rx="2"/><circle cx="12" cy="10" r="2"/><line x1="8" x2="8" y1="2" y2="4"/><line x1="16" x2="16" y1="2" y2="4"/>',
      "search" => '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
      "plus" => '<path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/>',
      "eye" => '<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>',
      "pencil" => '<path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>',
      "trash" => '<path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>',
      "cloud-upload" => '<path stroke-linecap="round" stroke-linejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>'
    }

    css_class = options[:class] || "w-5 h-5"
    stroke_color = options[:stroke] || "currentColor"

    content_tag(:svg, icons[name]&.html_safe, class: css_class, fill: "none", viewBox: "0 0 24 24", stroke: stroke_color, stroke_width: "2")
  end
end
