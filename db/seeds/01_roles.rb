roles = [
    {
        name: 'Administrador',
        slug: 'admin',
        description: 'Acceso completo a todas las funcionalidades de la empresa, no puede editar roles superiores'
    },
    {
        name: 'Super Administrador',
        slug: 'super_admin',
        description: 'Acceso completo a todas las funcionalidades de la empresa'
    },
    {
        name: 'Vendedor',
        slug: 'seller',
        description: 'Acceso a ver sus propias ventas'
    },
    {
        name: 'Conductor',
        slug: 'driver',
        description: 'Puede ser asignado como conductor en guias de remision'
    }
]

roles.each do |role|
  next if Role.exists?(slug: role[:slug])

  Role.create!(role)
end
