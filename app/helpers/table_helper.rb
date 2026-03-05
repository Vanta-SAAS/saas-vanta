module TableHelper
  class Builder
    attr_reader :view, :records, :columns, :show_actions

    def initialize(view, records, columns, show_actions = true)
      @view = view
      @records = records
      @columns = columns
      @show_actions = show_actions
      @actions_block = nil
    end

    def td_class(align = :left)
      base = "px-5 py-3.5 whitespace-nowrap text-sm"
      align_class = case align
      when :center then "text-center"
      when :right then "text-right"
      else "text-left"
      end
      "#{base} #{align_class}"
    end

    def action_link(record, action, options = {})
      case action
      when :show
        view.link_to(
          view.polymorphic_path(record),
          class: "table-action-btn",
          title: options[:title] || "Ver"
        ) do
          icon(:eye)
        end
      when :edit
        view.link_to(
          view.polymorphic_path([ :edit, record ]),
          class: "table-action-btn",
          title: options[:title] || "Editar"
        ) do
          icon(:edit)
        end
      when :destroy
        view.button_to(
          view.polymorphic_path(record),
          method: :delete,
          class: "table-action-btn-danger",
          title: options[:title] || "Eliminar",
          data: { turbo_confirm: options[:confirm] || "¿Estás seguro?" }
        ) do
          icon(:trash)
        end
      end
    end

    def actions(&block)
      @actions_block = block
    end

    def render_actions(record)
      return "" unless @actions_block
      view.capture(record, &@actions_block)
    end

    private

    def icon(name)
      icons = {
        eye: '<svg class="w-4 h-4 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>',
        edit: '<svg class="w-4 h-4 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>',
        trash: '<svg class="w-4 h-4 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>'
      }
      icons[name].html_safe
    end
  end

  def table_cell(value, options = {})
    align = options[:align] || :left
    type = options[:type] || :text
    css_class = options[:class] || ""

    align_class = case align
    when :center then "text-center"
    when :right then "text-right"
    else "text-left"
    end

    base_class = "px-5 py-3.5 whitespace-nowrap text-sm #{align_class} #{css_class}"

    content = case type
    when :currency
      "S/ #{number_with_precision(value, precision: 2)}"
    when :date
      value&.strftime("%d/%m/%Y") || "-"
    when :datetime
      value&.strftime("%d/%m/%Y %H:%M") || "-"
    when :badge
      value
    else
      value.presence || "-"
    end

    content_tag(:td, content, class: base_class)
  end

  def table_cell_primary(title, subtitle = nil, link_path = nil)
    content_tag(:td, class: "px-5 py-3.5 whitespace-nowrap") do
      content_tag(:div, class: "flex items-center") do
        content_tag(:div) do
          title_content = if link_path
            link_to(title, link_path, class: "text-sm font-medium text-foreground hover:text-primary transition-colors")
          else
            content_tag(:div, title, class: "text-sm font-medium text-foreground")
          end

          subtitle_content = if subtitle.present?
            content_tag(:div, subtitle, class: "text-xs text-muted-foreground")
          else
            ""
          end

          title_content + subtitle_content
        end
      end
    end
  end

  def table_cell_stock(stock, unit)
    content_tag(:td, class: "px-5 py-3.5 whitespace-nowrap text-center") do
      if stock.present?
        badge_class = stock > 10 ? "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400" : "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
        content_tag(:span, "#{stock} #{unit}", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{badge_class}")
      else
        content_tag(:span, "-", class: "text-sm text-muted-foreground")
      end
    end
  end

  def table_cell_code(value)
    content_tag(:td, class: "px-5 py-3.5 whitespace-nowrap") do
      content_tag(:span, value.presence || "-", class: "text-sm text-muted-foreground font-mono")
    end
  end
end
