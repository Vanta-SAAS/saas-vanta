module Sunat
  class ApiClient
    BASE_URL = ENV.fetch("BILLING_BASE_URL", "http://localhost:8000/api/v1")
    PAYMENT_CONDITION_MAP = { "cash" => "contado", "credit" => "credito" }.freeze

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class ValidationError < Error; end
    class NotFoundError < Error; end
    class ConflictError < Error; end

    # Error que incluye datos del documento creado por el microservicio
    # Se usa cuando SUNAT falla (502) pero el documento ya fue persistido con correlativo
    class ServerErrorWithDocument < Error
      attr_reader :document_data

      def initialize(message, document_data)
        super(message)
        @document_data = document_data
      end
    end

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

    # --- Notas de Credito ---

    def create_credit_note(credit_note)
      request do
        connection(authenticated: true).post("credit-notes") do |req|
          req.body = build_credit_note_payload(credit_note)
        end
      end
    end

    def retry_credit_note(uuid)
      request { connection(authenticated: true).post("credit-notes/#{uuid}/retry") }
    end

    def list_documents
      request { connection(authenticated: true).get("documents") }
    end

    # --- Guias de Remision ---

    # Emitir guia de remision remitente (tipo 09)
    def create_dispatch_guide_remitente(guide)
      request do
        connection(authenticated: true).post("dispatch-guides/remitente") do |req|
          req.body = build_dispatch_guide_payload(guide)
        end
      end
    end

    # Emitir guia de remision transportista (tipo 31)
    def create_dispatch_guide_transportista(guide)
      request do
        connection(authenticated: true).post("dispatch-guides/transportista") do |req|
          req.body = build_dispatch_guide_payload(guide)
        end
      end
    end

    def get_dispatch_guide(uuid)
      request { connection(authenticated: true).get("dispatch-guides/#{uuid}") }
    end

    def get_dispatch_guide_status(uuid)
      request { connection(authenticated: true).get("dispatch-guides/#{uuid}/status") }
    end

    def retry_dispatch_guide(uuid)
      request { connection(authenticated: true).post("dispatch-guides/#{uuid}/retry") }
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

      payload = {
        customer_doc_type: customer.tax_id_type == "ruc" ? "ruc" : "dni",
        customer_doc_number: customer.tax_id.to_s,
        customer_name: customer.name,
        customer_address: customer.address,
        currency: "PEN",
        payment_condition: PAYMENT_CONDITION_MAP[sale.payment_condition],
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

      if sale.credit?
        payload[:installments] = sale.installments.order(:installment_number).map do |installment|
          {
            amount: installment.amount.to_f,
            due_date: installment.due_date.iso8601
          }
        end
      end

      payload
    end

    def build_credit_note_payload(credit_note)
      sale = credit_note.sale
      sale_doc = sale.current_sunat_document

      {
        reference_document_id: sale_doc&.sunat_uuid,
        reason_code: credit_note.reason_code,
        description: credit_note.description,
        items: credit_note.items.map do |item|
          {
            description: item.description,
            quantity: item.quantity.to_f,
            item_type: item.item_type || "product",
            unit_price: item.unit_price.to_f,
            tax_type: item.tax_type || "gravado"
          }
        end
      }
    end

    def build_dispatch_guide_payload(guide)
      payload = {
        transfer_reason: guide.transfer_reason,
        transport_modality: guide.transport_modality == "private" ? "private" : "public",
        transfer_date: guide.transfer_date.to_s,
        gross_weight: guide.gross_weight.to_s,
        departure_address: guide.departure_address,
        departure_ubigeo: guide.departure_ubigeo&.code || "150101",
        arrival_address: guide.arrival_address,
        arrival_ubigeo: guide.arrival_ubigeo&.code || "150101",
        recipient_doc_type: guide.recipient_doc_type,
        recipient_doc_number: guide.recipient_doc_number,
        recipient_name: guide.recipient_name,
        items: guide.items.map do |item|
          {
            description: item.description,
            quantity: item.quantity.to_f,
            unit_code: item.unit_code
          }
        end
      }

      # Transporte privado: vehiculo + conductor
      if guide.private_transport?
        payload[:vehicle_plate] = guide.vehicle&.plate
        if guide.driver.present?
          payload[:driver_doc_type] = guide.driver.doc_type_for_sunat
          payload[:driver_doc_number] = guide.driver.doc_number_for_sunat
          payload[:driver_name] = guide.driver.full_name
          payload[:driver_license] = guide.driver.driving_license_number
        end
      end

      # Transporte publico: datos del transportista
      if guide.public_transport?
        payload[:carrier_ruc] = guide.carrier_ruc
        payload[:carrier_name] = guide.carrier_name
      end

      # GRT: datos del remitente
      if guide.grt?
        payload[:shipper_doc_type] = guide.shipper_doc_type
        payload[:shipper_doc_number] = guide.shipper_doc_number
        payload[:shipper_name] = guide.shipper_name
      end

      # Documento relacionado (factura/boleta vinculada)
      if guide.sourceable.is_a?(Sale) && guide.sourceable.sunat_uuid.present?
        payload[:related_document_id] = guide.sourceable.sunat_uuid
      end

      payload
    end

    def request
      response = yield
      response.body
    rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
      raise AuthenticationError, "Error de autenticacion con el servicio SUNAT: #{extract_error_message(e)}"
    rescue Faraday::UnprocessableEntityError => e
      raise ValidationError, extract_error_message(e)
    rescue Faraday::ResourceNotFound => e
      raise NotFoundError, extract_error_message(e)
    rescue Faraday::ConflictError => e
      raise ConflictError, extract_error_message(e)
    rescue Faraday::BadRequestError => e
      raise Error, extract_error_message(e)
    rescue Faraday::ConnectionFailed
      raise Error, "No se pudo conectar al servicio de facturacion. Verifique que este activo."
    rescue Faraday::ServerError => e
      body = e.response&.dig(:body)
      if body.is_a?(Hash) && (body["uuid"] || body["id"]).present?
        raise ServerErrorWithDocument.new(
          "Error en SUNAT: #{extract_error_message(e)}",
          body
        )
      end
      raise Error, "Error en SUNAT: #{extract_error_message(e)}"
    rescue Faraday::Error => e
      raise Error, "Error al comunicarse con el servicio SUNAT: #{e.message}"
    end

    def extract_error_message(error)
      body = error.response&.dig(:body)
      return error.message unless body

      if body.is_a?(Hash)
        detail = body["detail"]
        if detail.is_a?(Array)
          detail.map { |d| d["msg"] }.compact.join(". ")
        elsif detail.is_a?(String)
          detail
        else
          body["error"] || body["message"] || body.to_s
        end
      else
        text = body.to_s
        if text.include?("<!DOCTYPE") || text.include?("<html")
          "El servicio de SUNAT no está disponible, intente nuevamente más tarde."
        else
          text.truncate(200)
        end
      end
    end
  end
end
