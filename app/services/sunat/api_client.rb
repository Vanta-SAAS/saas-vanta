module Sunat
  class ApiClient
    BASE_URL = ENV.fetch("BILLING_BASE_URL", "http://localhost:8000/api/v1")

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class ValidationError < Error; end

    def initialize(api_key: nil)
      @api_key = api_key
    end

    # Paso 1 — Registro del cliente (onboarding)
    def register_client(enterprise)
      request do
        connection(authenticated: false).post("clients") do |req|
          req.body = {
            ruc: enterprise.tax_id.to_s,
            razon_social: enterprise.social_reason,
            nombre_comercial: enterprise.comercial_name,
            direccion: enterprise.address,
            ubigeo: enterprise.ubigeo&.code || "150101",
            sol_user: enterprise.settings&.sunat_sol_user,
            sol_password: enterprise.settings&.sunat_sol_password
          }
        end
      end
    end

    # Actualizar datos del cliente (credenciales SOL, etc.)
    def update_client(params)
      request do
        connection(authenticated: true).put("clients/me") do |req|
          req.body = params
        end
      end
    end

    # Paso 2 — Subir certificado digital (.pfx o .p12)
    def upload_certificate(file, password)
      request do
        connection(authenticated: true, json: false).post("clients/me/certificate") do |req|
          req.params["password"] = password
          req.body = {
            file: Faraday::Multipart::FilePart.new(file, "application/x-pkcs12")
          }
        end
      end
    end

    # Paso 3 — Emitir factura (tipo 01)
    def create_invoice(sale)
      request do
        connection(authenticated: true).post("invoices") do |req|
          req.body = build_document_payload(sale, series_type: :factura)
        end
      end
    end

    # Paso 3 — Emitir boleta (tipo 03)
    def create_receipt(sale)
      request do
        connection(authenticated: true).post("receipts") do |req|
          req.body = build_document_payload(sale, series_type: :boleta)
        end
      end
    end

    # Paso 4 — Consultar estado
    def get_document(uuid)
      request { connection(authenticated: true).get("documents/#{uuid}") }
    end

    def get_document_status(uuid)
      request { connection(authenticated: true).get("documents/#{uuid}/status") }
    end

    def retry_document(uuid)
      request { connection(authenticated: true).post("documents/#{uuid}/retry") }
    end

    def list_documents
      request { connection(authenticated: true).get("documents") }
    end

    private

    def connection(authenticated: true, json: true)
      Faraday.new(url: BASE_URL) do |f|
        if json
          f.request :json
        else
          f.request :multipart
          f.request :url_encoded
        end
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.adapter Faraday.default_adapter

        if authenticated && @api_key.present?
          f.headers["Authorization"] = "Bearer #{@api_key}"
        end
      end
    end

    def build_document_payload(sale, series_type:)
      customer = sale.customer

      {
        customer_doc_type: customer.tax_id_type == "ruc" ? "ruc" : "dni",
        customer_doc_number: customer.tax_id.to_s,
        customer_name: customer.name,
        customer_address: customer.address,
        currency: "PEN",
        items: sale.items.includes(:product).map do |item|
          {
            description: item.product.name,
            quantity: item.quantity.to_f,
            item_type: "product",
            unit_price: item.unit_price.to_f,
            tax_type: "gravado"
          }
        end
      }
    end

    def request
      response = yield
      response.body
    rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
      raise AuthenticationError, "Error de autenticacion con el servicio SUNAT: #{e.message}"
    rescue Faraday::UnprocessableEntityError => e
      body = e.response&.dig(:body)
      message = body.is_a?(Hash) ? (body["error"] || body["message"] || body.to_s) : body.to_s
      raise ValidationError, message
    rescue Faraday::ConnectionFailed
      raise Error, "No se pudo conectar al servicio de facturacion. Verifique que este activo."
    rescue Faraday::Error => e
      raise Error, "Error al comunicarse con el servicio SUNAT: #{e.message}"
    end
  end
end
