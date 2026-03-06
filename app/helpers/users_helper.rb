module UsersHelper
  # Render a badge for user status
  def render_user_status_badge(status, size: :md)
    classes = case status.to_s
    when "active"
      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
    when "pending"
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
    when "inactive"
      "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
    end

    size_classes = size == :lg ? "px-3 py-1 text-sm" : "px-2.5 py-0.5 text-xs"

    label = case status.to_s
    when "active" then "Activo"
    when "pending" then "Pendiente"
    when "inactive" then "Inactivo"
    else status.to_s.humanize
    end

    content_tag(:span, label, class: "inline-flex items-center rounded-full font-medium #{classes} #{size_classes}")
  end

  # Get badge class for role
  def role_badge_class(role_slug)
    case role_slug.to_s
    when "super_admin"
      "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400"
    when "admin"
      "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"
    when "seller"
      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
    when "driver"
      "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
    end
  end

  # Get description for role
  def role_description(role_slug)
    case role_slug.to_s
    when "super_admin" then "Acceso total a la plataforma y todas las empresas"
    when "admin" then "Acceso completo a la gestion de la empresa"
    when "seller" then "Acceso a cotizaciones, ventas y clientes"
    when "driver" then "Acceso a guias de remision y despacho"
    else ""
    end
  end

  # Get label for role
  def role_label(role_slug)
    case role_slug.to_s
    when "super_admin" then "Super Admin"
    when "admin" then "Administrador"
    when "seller" then "Vendedor"
    when "driver" then "Conductor"
    else role_slug.to_s.humanize
    end
  end
end
