---
name: billing-microservice
description: Use when working with SUNAT electronic invoicing integration, the billing microservice API, or any code in app/services/sunat/. Covers invoices, boletas, credit notes, dispatch guides, payment conditions, correlativos, retry logic, and all API endpoints.
---

# Billing Microservice — SUNAT Electronic Invoicing

This skill provides complete context about the external billing microservice that this Rails app consumes for Peruvian electronic invoicing (facturacion electronica).

## When to Use This Skill

- Writing or modifying code in `app/services/sunat/`
- Building integration with the billing microservice API
- Handling SUNAT document creation (invoices, boletas, credit notes, dispatch guides)
- Debugging SUNAT-related errors or retry logic
- Working with correlativos, series, or payment conditions

---

## Microservice Overview

**Vanta Billing** is a standalone FastAPI microservice that manages clients, generates UBL 2.1 XML documents (invoices, boletas, credit notes, dispatch guides), signs them with digital certificates, and submits to SUNAT.

**Base URL:** Configured via `BILLING_BASE_URL` env var (default: `http://localhost:8000/api/v1`)
**Auth:** Bearer token (the client's API key) on all business endpoints.

---

## API Endpoints Reference

### Client Setup

1. **Register client:** `POST /api/v1/clients` with `{ ruc, razon_social, ... }` -> returns `api_key` (shown only once)
2. **Upload certificate:** `POST /api/v1/clients/me/certificate` with `.pfx` file + password
3. **Configure SOL credentials:** `PUT /api/v1/clients/me` with `{ sol_user, sol_password }`
4. **Configure SUNAT REST credentials (for dispatch guides):** `PUT /api/v1/clients/me` with `{ sunat_client_id, sunat_client_secret }` — each client registers in SUNAT SOL -> Menu -> Empresa -> API REST. Falls back to global env vars if not set per-client.
5. **Set default series:** `PUT /api/v1/clients/me` with `{ serie_factura, serie_boleta, serie_grr, serie_grt, serie_nota_credito_factura, serie_nota_credito_boleta }`

### Document Creation

All `POST` creation endpoints create, sign, and send to SUNAT in a single call.

```
# Invoices (Facturas) -- Contado, with unit_price_without_tax (recommended)
POST /api/v1/invoices
Authorization: Bearer <api_key>
{ "customer_doc_type": "ruc", "customer_doc_number": "20123456789",
  "customer_name": "...", "items": [{ "description": "...", "quantity": 1,
  "item_type": "product", "unit_price": 118.00,
  "unit_price_without_tax": 100.00, "tax_type": "gravado" }] }

# Invoices (Facturas) -- Contado, backward compatible (no unit_price_without_tax)
POST /api/v1/invoices
Authorization: Bearer <api_key>
{ "customer_doc_type": "ruc", "customer_doc_number": "20123456789",
  "customer_name": "...", "items": [{ "description": "...", "quantity": 1,
  "item_type": "product", "unit_price": 118.00, "tax_type": "gravado" }] }

# Invoices (Facturas) -- Credito con cuotas
POST /api/v1/invoices
Authorization: Bearer <api_key>
{ "customer_doc_type": "ruc", "customer_doc_number": "20123456789",
  "customer_name": "...",
  "payment_condition": "credito",
  "installments": [
    { "amount": 59.00, "due_date": "2026-04-09" },
    { "amount": 59.00, "due_date": "2026-05-09" }
  ],
  "items": [{ "description": "...", "quantity": 1,
  "item_type": "product", "unit_price": 118.00,
  "unit_price_without_tax": 100.00, "tax_type": "gravado" }] }

# Receipts (Boletas)
POST /api/v1/receipts  (same structure, customer_doc_type defaults to "dni")
# Receipts also support payment_condition + installments, same as invoices.

# Dispatch Guides -- Remitente (GRR)
POST /api/v1/dispatch-guides/remitente
{ "transfer_reason": "venta", "transport_modality": "private",
  "transfer_date": "2026-03-05", "gross_weight": "150",
  "departure_address": "...", "departure_ubigeo": "150101",
  "arrival_address": "...", "arrival_ubigeo": "150201",
  "recipient_doc_type": "ruc", "recipient_doc_number": "20123456789",
  "recipient_name": "...", "vehicle_plate": "ABC-123",
  "driver_doc_type": "dni", "driver_doc_number": "12345678",
  "driver_name": "...", "driver_license": "Q12345678",
  "related_document_id": "uuid-of-invoice (optional)",
  "items": [{ "description": "Producto X", "quantity": 10, "unit_code": "NIU" }] }

# Dispatch Guides -- Transportista (GRT)
POST /api/v1/dispatch-guides/transportista
(same as GRR but requires shipper_* fields and always requires vehicle/driver)
# Both GRR and GRT accept optional "related_document_id" to link to an existing invoice/receipt.

# Credit Notes (Notas de Credito) -- para Facturas
POST /api/v1/credit-notes
Authorization: Bearer <api_key>
{ "reference_document_id": "uuid-of-the-original-invoice",
  "reason_code": "anulacion_de_la_operacion",
  "description": "Anulacion por montos incorrectos",
  "items": [{ "description": "...", "quantity": 1,
  "item_type": "product", "unit_price": 5900.00,
  "unit_price_without_tax": 5000.00, "tax_type": "gravado" }] }

# Credit Notes (Notas de Credito) -- para Boletas
POST /api/v1/credit-notes
Authorization: Bearer <api_key>
{ "reference_document_id": "uuid-of-the-original-boleta",
  "reason_code": "devolucion_total",
  "description": "Devolucion total del producto",
  "items": [{ "description": "...", "quantity": 1,
  "item_type": "product", "unit_price": 118.00,
  "unit_price_without_tax": 100.00, "tax_type": "gravado" }] }
# series is OPTIONAL -- auto-resolved from client config based on referenced document type
# Customer info and currency are inherited from the referenced document
# Credit notes can reference a subset of items
# A single invoice/boleta can have multiple credit notes
```

### Querying & Retry

```
GET  /api/v1/documents                        # List invoices/receipts
GET  /api/v1/documents/{id}                   # Detail with XML, CDR, items
GET  /api/v1/documents/{id}/status            # Query SUNAT live status
POST /api/v1/documents/{id}/retry             # Retry failed submission

GET  /api/v1/credit-notes                     # List credit notes
GET  /api/v1/credit-notes/{id}               # Detail with XML, CDR, items
POST /api/v1/credit-notes/{id}/retry         # Retry failed submission

GET  /api/v1/dispatch-guides                  # List dispatch guides
GET  /api/v1/dispatch-guides/{id}             # Detail
GET  /api/v1/dispatch-guides/{id}/status      # Query SUNAT live status
POST /api/v1/dispatch-guides/{id}/retry       # Retry failed submission
```

---

## Document Flows

### Invoice/Receipt Flow
1. Client sends data to `POST /api/v1/invoices` or `/receipts`
2. Microservice translates item types to SUNAT codes, extracts base price, calculates IGV
3. Document + items (+ installments if credit) persisted with auto-incrementing correlative per series
4. UBL 2.1 XML built with payment terms, signed with certificate, QR generated
5. Signed XML sent to SUNAT via SOAP; CDR response stored
6. Failed documents retried via `POST /documents/{id}/retry`

### Credit Note Flow
1. `POST /api/v1/credit-notes` with `reference_document_id` (UUID of original invoice/receipt). `series` is optional -- auto-resolved from client config based on referenced document type (factura -> `serie_nota_credito_factura`, boleta -> `serie_nota_credito_boleta`).
2. Validates reference document exists, belongs to client, is type "01" (factura) or "03" (boleta)
3. Customer info and currency inherited from referenced document
4. Items calculated with same IGV-extraction logic
5. CreditNote UBL 2.1 XML built (with `DiscrepancyResponse` + `BillingReference`), signed, QR generated
6. Sent to SUNAT via SOAP (document type "07"); CDR stored
7. Retry via `POST /credit-notes/{id}/retry`

**Series config:** `serie_nota_credito_factura` (e.g. FC01), `serie_nota_credito_boleta` (e.g. BC01) via `PUT /api/v1/clients/me`.
**Partial credit notes:** Can include subset of items. Multiple credit notes can reference same invoice/boleta.

### Dispatch Guide Flow (Guias de Remision)
1. `POST /api/v1/dispatch-guides/remitente` (GRR, type "09", series T) or `/transportista` (GRT, type "31", series V)
2. Translates enums to SUNAT catalog codes (no tax calculation)
3. If `related_document_id` provided, related invoice/receipt resolved and included in XML as `<cac:AdditionalDocumentReference>`
4. DispatchGuide + items persisted with auto-incrementing correlative
5. DespatchAdvice-2 UBL XML built, signed, QR generated
6. Sent to SUNAT via REST API (OAuth2 token + POST document + poll ticket); CDR stored
7. Retry via `POST /dispatch-guides/{id}/retry`

**GRR (Remitente):** Requires transport modality -- `public` needs carrier RUC/name, `private` needs vehicle plate + driver info.
**GRT (Transportista):** Always requires vehicle plate, driver info, and shipper (remitente) info.

---

## Pricing: unit_price + unit_price_without_tax (IMPORTANT)

Items support two pricing fields:

- **`unit_price`** (required): Price **WITH IGV** (precio de venta al publico). Always sent.
- **`unit_price_without_tax`** (optional, nullable): Explicit base price **WITHOUT IGV**, sent with **full precision** (no truncation). When provided, the microservice uses it directly.

**When `unit_price_without_tax` IS provided (recommended):**
The caller sends the raw result of `unit_price / 1.18` without truncation (e.g., `3.10 / 1.18 = 2.6271186440677966...`). Both sides compute identical totals: `line_ext = round(qty * base, 2)`, `igv = round(line_ext * 0.18, 2)`.

Example: `unit_price: 3.10, unit_price_without_tax: 2.6271186440677966, tax_type: "gravado"` -> `line_ext = round(100 * 2.6271186..., 2) = 262.71`, `igv = 47.29`, `total = 310.00`.

**When `unit_price_without_tax` is NOT provided (backward compatible):**
Falls back to `unit_price / 1.18` rounded to 2 decimals. Can cause rounding discrepancies with high quantities.

- **Gravado items:** `base_price = unit_price_without_tax ?? round(unit_price / 1.18, 2)`
- **Exonerado/Inafecto items:** `base_price = unit_price_without_tax ?? unit_price` -- no IGV component.

---

## Payment Conditions (Condicion de Venta)

- **`"contado"`** (default): Cash sale. No installments. Default when omitted.
- **`"credito"`**: Credit sale. Requires `installments` array with at least one entry.

**Installment rules:**
- Each has `amount` (Decimal, > 0) and `due_date` (date, `YYYY-MM-DD`)
- Sum of amounts **must equal** the document's `total_amount` (total with IGV)
- Numbered automatically (`Cuota001`, `Cuota002`, ...) in XML
- `contado` + `installments` = validation error
- `credito` without `installments` = validation error

**XML structure (Resolucion 193-2020/SUNAT):**
```xml
<!-- Credito: bloque principal con monto pendiente total -->
<cac:PaymentTerms>
  <cbc:ID>FormaPago</cbc:ID>
  <cbc:PaymentMeansID>Credito</cbc:PaymentMeansID>
  <cbc:Amount currencyID="PEN">118.00</cbc:Amount>
</cac:PaymentTerms>
<!-- Un bloque por cada cuota -->
<cac:PaymentTerms>
  <cbc:ID>FormaPago</cbc:ID>
  <cbc:PaymentMeansID>Cuota001</cbc:PaymentMeansID>
  <cbc:Amount currencyID="PEN">59.00</cbc:Amount>
  <cbc:PaymentDueDate>2026-04-09</cbc:PaymentDueDate>
</cac:PaymentTerms>
```

---

## Correlativos y Reintentos (CRITICAL for Rails Integration)

The microservice protects correlativos to avoid gaps in SUNAT numbering. Behavior varies by **where** the error occurs:

**Pre-SUNAT failure (XML build, signing):** Complete rollback. No document persisted, no correlativo consumed. Safe to retry with `POST /invoices` (or `/receipts`, `/dispatch-guides/*`).

**SUNAT submission failure (network error, rejection):** Document persisted with status `ERROR` or `REJECTED` with signed XML. Correlativo **IS consumed** because document was already built and potentially sent.

**HTTP 502 response (SUNAT error):** The microservice returns HTTP 502 with the **same schema** as a successful 201 response (`DocumentDetail`/`CreditNoteDetail`/`DispatchGuideDetail`), but with `status: "ERROR"`. The body includes `id`, `series`, `correlative`, and all normal fields:
```json
{
  "id": "uuid-del-documento",
  "document_type": "01",
  "series": "F001",
  "correlative": 123,
  "status": "ERROR",
  "total_amount": "118.00",
  ...
}
```
This allows the caller to parse the response identically to a 201 -- only the HTTP status code and `status` field differ.

### Correct Flow for the Caller (Rails)

```
1. POST /api/v1/invoices -> HTTP 201 (status: ACCEPTED)
   OK. Save body["id"] and data.

2. POST /api/v1/invoices -> HTTP 500 (XML build/sign error)
   No correlativo consumed. No document created.
   -> Fix data and call POST /invoices again.

3. POST /api/v1/invoices -> HTTP 502 (SUNAT error)
   Correlativo consumed. Document exists with status ERROR.
   -> Body has the SAME structure as a 201 -- read body["id"] and SAVE IT.
   -> To retry: POST /documents/{id}/retry (DO NOT create new document).
   -> Retry resends the SAME XML with the SAME correlativo.
```

**Rails example:**
```ruby
response = billing_client.create_invoice(payload)

case response.status
when 201, 502
  # Both return the same schema -- always save
  save_document(response.body)
  # If status is ERROR, schedule retry:
  if response.body["status"] == "ERROR"
    schedule_retry(document_id: response.body["id"])
  end
when 500
  # Pre-SUNAT error -- no document created, can retry creating a new one
  log_error(response.body["detail"])
end
```

**Key rule:** On HTTP 502, the body is identical to a 201 (same schema, with `id` at top level). The caller **MUST** save the `id` and use the `/retry` endpoint instead of creating a new document. Creating a new document would burn an additional correlativo.

Same retry endpoints exist for dispatch guides (`POST /dispatch-guides/{id}/retry`) and credit notes (`POST /credit-notes/{id}/retry`). All return the same schema on 502.

**Important:** The microservice response field is `id` (not `uuid`). The `id` contains a UUID string, but the field name is always `id`.

---

## Client Series Configuration

Series stored in `clients` table, configured via `PUT /api/v1/clients/me`:

| Field | Example | Document Type |
|---|---|---|
| `serie_factura` | `F001` | Facturas (01) |
| `serie_boleta` | `B001` | Boletas (03) |
| `serie_nota_credito_factura` | `FC01` | NC de Facturas (07) |
| `serie_nota_credito_boleta` | `BC01` | NC de Boletas (07) |
| `serie_grr` | `T001` | GR Remitente (09) |
| `serie_grt` | `V001` | GR Transportista (31) |

Each series has its own independent correlative counter (auto-incrementing, managed in `document_series` table).

---

## Credit Note Reason Codes (Catalogo 09)

| Value in API | SUNAT Code | Description |
|---|---|---|
| `anulacion_de_la_operacion` | 01 | Anulacion de la operacion |
| `anulacion_por_error_en_el_ruc` | 02 | Anulacion por error en el RUC |
| `correccion_por_error_en_la_descripcion` | 03 | Correccion por error en la descripcion |
| `descuento_global` | 04 | Descuento global |
| `descuento_por_item` | 05 | Descuento por item |
| `devolucion_total` | 06 | Devolucion total |
| `devolucion_por_item` | 07 | Devolucion por item |
| `bonificacion` | 08 | Bonificacion |
| `disminucion_en_el_valor` | 09 | Disminucion en el valor |
| `otros_conceptos` | 10 | Otros conceptos |
| `ajustes_de_operaciones_de_exportacion` | 11 | Ajustes de operaciones de exportacion |
| `ajustes_afectos_al_ivap` | 12 | Ajustes afectos al IVAP |
| `correccion_del_monto_neto_pendiente_de_pago` | 13 | Correccion del monto neto pendiente de pago / cuotas |

The `description` field is **required by SUNAT** (free text explaining the reason).

---

## Response Status Values

`CREATED` -> `SIGNED` -> `SENT` -> `ACCEPTED` / `REJECTED` / `ERROR`

---

## SUNAT Catalog Quick Reference

- **Document types:** `01` Factura, `03` Boleta, `07` Nota de Credito, `09` GR Remitente, `31` GR Transportista
- **Series prefixes:** `F` Factura, `B` Boleta, `FC` NC Factura, `BC` NC Boleta, `T` GR Remitente, `V` GR Transportista
- **Payment condition:** `contado` (cash), `credito` (credit with installments) -- Resolucion 193-2020/SUNAT
- **Transport modality (Cat. 18):** `public` (carrier handles transport), `private` (own vehicle)
- **Transfer reasons (Cat. 20):** `venta`, `compra`, `traslado_entre_establecimientos`, `importacion`, `exportacion`, `otros`
- **Tax types (Cat. 07):** `gravado` (18% IGV), `exonerado`, `inafecto`
- **Item types:** `product` (NIU), `service` (ZZ)
- **Credit note reasons (Cat. 09):** `anulacion_de_la_operacion`, `anulacion_por_error_en_el_ruc`, `correccion_por_error_en_la_descripcion`, `descuento_global`, `descuento_por_item`, `devolucion_total`, `devolucion_por_item`, `bonificacion`, `disminucion_en_el_valor`, `otros_conceptos`, `correccion_del_monto_neto_pendiente_de_pago`
