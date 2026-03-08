class Suggestion < ApplicationRecord
  belongs_to :enterprise
  belongs_to :user

  validates :body, presence: { message: "La sugerencia no puede estar vacia" }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "no es un correo valido" },
            allow_blank: true
end
