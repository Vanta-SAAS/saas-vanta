# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_04_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bulk_imports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "enterprise_id", null: false
    t.integer "failed_rows", default: 0
    t.string "original_filename"
    t.string "resource_type", null: false
    t.jsonb "results", default: {}
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "successful_rows", default: 0
    t.integer "total_rows", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["enterprise_id", "resource_type"], name: "index_bulk_imports_on_enterprise_id_and_resource_type"
    t.index ["enterprise_id"], name: "index_bulk_imports_on_enterprise_id"
    t.index ["resource_type"], name: "index_bulk_imports_on_resource_type"
    t.index ["status"], name: "index_bulk_imports_on_status"
    t.index ["user_id"], name: "index_bulk_imports_on_user_id"
  end

  create_table "carriers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "enterprise_id", null: false
    t.string "name", null: false
    t.string "ruc", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["enterprise_id", "ruc"], name: "index_carriers_on_enterprise_id_and_ruc", unique: true
    t.index ["enterprise_id"], name: "index_carriers_on_enterprise_id"
  end

  create_table "customer_quote_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_quote_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["customer_quote_id", "product_id"], name: "index_customer_quote_items_on_customer_quote_id_and_product_id", unique: true
    t.index ["customer_quote_id"], name: "index_customer_quote_items_on_customer_quote_id"
    t.index ["product_id"], name: "index_customer_quote_items_on_product_id"
  end

  create_table "customer_quotes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "destination_id"
    t.bigint "enterprise_id", null: false
    t.date "expiration_date"
    t.date "issue_date", null: false
    t.text "notes"
    t.bigint "seller_id", null: false
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "tax", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_customer_quotes_on_created_by_id"
    t.index ["customer_id"], name: "index_customer_quotes_on_customer_id"
    t.index ["destination_id"], name: "index_customer_quotes_on_destination_id"
    t.index ["enterprise_id", "code"], name: "index_customer_quotes_on_enterprise_id_and_code", unique: true
    t.index ["enterprise_id"], name: "index_customer_quotes_on_enterprise_id"
    t.index ["issue_date"], name: "index_customer_quotes_on_issue_date"
    t.index ["seller_id"], name: "index_customer_quotes_on_seller_id"
    t.index ["status"], name: "index_customer_quotes_on_status"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 10, scale: 2, default: "0.0", null: false
    t.string "email"
    t.bigint "enterprise_id", null: false
    t.string "name", null: false
    t.integer "payment_terms", default: 0, null: false
    t.string "phone_number"
    t.string "tax_id"
    t.string "tax_id_type", default: "ruc", null: false
    t.bigint "ubigeo_id"
    t.datetime "updated_at", null: false
    t.index ["enterprise_id", "tax_id"], name: "idx_customers_on_tax_id_unq_not_null", unique: true, where: "(tax_id IS NOT NULL)"
    t.index ["enterprise_id"], name: "index_customers_on_enterprise_id"
    t.index ["ubigeo_id"], name: "index_customers_on_ubigeo_id"
  end

  create_table "dispatch_guide_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "dispatch_guide_id", null: false
    t.bigint "product_id"
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.string "unit_code", default: "NIU", null: false
    t.datetime "updated_at", null: false
    t.index ["dispatch_guide_id"], name: "index_dispatch_guide_items_on_dispatch_guide_id"
    t.index ["product_id"], name: "index_dispatch_guide_items_on_product_id"
  end

  create_table "dispatch_guides", force: :cascade do |t|
    t.string "arrival_address"
    t.bigint "arrival_ubigeo_id"
    t.bigint "carrier_id"
    t.string "carrier_name"
    t.string "carrier_ruc"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "departure_address"
    t.bigint "departure_ubigeo_id"
    t.bigint "driver_id"
    t.bigint "enterprise_id", null: false
    t.decimal "gross_weight", precision: 10, scale: 2
    t.string "guide_type", null: false
    t.date "issue_date", null: false
    t.text "notes"
    t.string "recipient_doc_number"
    t.string "recipient_doc_type"
    t.string "recipient_name"
    t.string "shipper_doc_number"
    t.string "shipper_doc_type"
    t.string "shipper_name"
    t.bigint "sourceable_id"
    t.string "sourceable_type"
    t.string "status", default: "draft", null: false
    t.string "sunat_cdr_code"
    t.text "sunat_cdr_description"
    t.string "sunat_document_type"
    t.string "sunat_hash"
    t.integer "sunat_number"
    t.text "sunat_qr_image"
    t.jsonb "sunat_response_data"
    t.string "sunat_series"
    t.string "sunat_status"
    t.string "sunat_uuid"
    t.text "sunat_xml"
    t.date "transfer_date", null: false
    t.string "transfer_reason", null: false
    t.string "transport_modality", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id"
    t.index ["arrival_ubigeo_id"], name: "index_dispatch_guides_on_arrival_ubigeo_id"
    t.index ["carrier_id"], name: "index_dispatch_guides_on_carrier_id"
    t.index ["created_by_id"], name: "index_dispatch_guides_on_created_by_id"
    t.index ["departure_ubigeo_id"], name: "index_dispatch_guides_on_departure_ubigeo_id"
    t.index ["driver_id"], name: "index_dispatch_guides_on_driver_id"
    t.index ["enterprise_id", "code"], name: "index_dispatch_guides_on_enterprise_id_and_code", unique: true
    t.index ["enterprise_id"], name: "index_dispatch_guides_on_enterprise_id"
    t.index ["sourceable_type", "sourceable_id"], name: "index_dispatch_guides_on_sourceable"
    t.index ["status"], name: "index_dispatch_guides_on_status"
    t.index ["sunat_uuid"], name: "index_dispatch_guides_on_sunat_uuid", unique: true, where: "(sunat_uuid IS NOT NULL)"
    t.index ["vehicle_id"], name: "index_dispatch_guides_on_vehicle_id"
  end

  create_table "enterprise_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "dropshipping_enabled", default: false, null: false
    t.bigint "enterprise_id", null: false
    t.string "sunat_api_key"
    t.boolean "sunat_certificate_uploaded", default: false, null: false
    t.integer "sunat_next_boleta_number"
    t.string "sunat_next_boleta_series"
    t.integer "sunat_next_factura_number"
    t.string "sunat_next_factura_series"
    t.integer "sunat_next_grr_number"
    t.string "sunat_next_grr_series"
    t.integer "sunat_next_grt_number"
    t.string "sunat_next_grt_series"
    t.string "sunat_series_boleta", default: "B001"
    t.string "sunat_series_factura", default: "F001"
    t.string "sunat_series_grr", default: "T001"
    t.string "sunat_series_grt", default: "V001"
    t.string "sunat_sol_password"
    t.string "sunat_sol_user"
    t.datetime "updated_at", null: false
    t.boolean "use_stock", default: true
    t.index ["enterprise_id"], name: "index_enterprise_settings_on_enterprise_id", unique: true
  end

  create_table "enterprises", force: :cascade do |t|
    t.string "address"
    t.string "comercial_name", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "enterprise_type", null: false
    t.string "logo"
    t.string "phone_number"
    t.string "social_reason"
    t.string "status", null: false
    t.string "subdomain", null: false
    t.bigint "tax_id"
    t.bigint "ubigeo_id"
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_enterprises_on_status"
    t.index ["subdomain"], name: "index_enterprises_on_subdomain", unique: true
    t.index ["tax_id"], name: "idx_enterprises_on_tax_id_unq_not_null", unique: true, where: "(tax_id IS NOT NULL)"
    t.index ["ubigeo_id"], name: "index_enterprises_on_ubigeo_id"
  end

  create_table "products", force: :cascade do |t|
    t.decimal "buy_price", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "enterprise_id", null: false
    t.string "name", null: false
    t.bigint "provider_id"
    t.decimal "sell_cash_price", null: false
    t.decimal "sell_credit_price", null: false
    t.string "sku"
    t.string "source_type", null: false
    t.string "status", null: false
    t.integer "stock"
    t.string "unit", null: false
    t.decimal "units_per_package"
    t.datetime "updated_at", null: false
    t.index ["enterprise_id", "sku"], name: "idx_products_on_sku_unq_not_null", unique: true, where: "(sku IS NOT NULL)"
    t.index ["enterprise_id"], name: "index_products_on_enterprise_id"
    t.index ["provider_id"], name: "index_products_on_provider_id"
    t.index ["status"], name: "index_products_on_status"
  end

  create_table "providers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "enterprise_id", null: false
    t.string "name", null: false
    t.string "phone_number"
    t.string "tax_id"
    t.bigint "ubigeo_id"
    t.datetime "updated_at", null: false
    t.index ["enterprise_id", "tax_id"], name: "idx_providers_on_tax_id_unq_not_null", unique: true, where: "(tax_id IS NOT NULL)"
    t.index ["enterprise_id"], name: "index_providers_on_enterprise_id"
    t.index ["ubigeo_id"], name: "index_providers_on_ubigeo_id"
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "purchase_order_id", null: false
    t.integer "quantity", null: false
    t.decimal "total", precision: 10, scale: 2, null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_order_items_on_product_id"
    t.index ["purchase_order_id", "product_id"], name: "idx_po_items_on_po_and_product", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "delivery_address"
    t.bigint "destination_id"
    t.bigint "enterprise_id", null: false
    t.date "expected_date"
    t.date "issue_date", null: false
    t.text "notes"
    t.bigint "provider_id", null: false
    t.bigint "sourceable_id"
    t.string "sourceable_type"
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "tax", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_purchase_orders_on_created_by_id"
    t.index ["destination_id"], name: "index_purchase_orders_on_destination_id"
    t.index ["enterprise_id", "code"], name: "index_purchase_orders_on_enterprise_id_and_code", unique: true
    t.index ["enterprise_id"], name: "index_purchase_orders_on_enterprise_id"
    t.index ["issue_date"], name: "index_purchase_orders_on_issue_date"
    t.index ["provider_id"], name: "index_purchase_orders_on_provider_id"
    t.index ["sourceable_type", "sourceable_id"], name: "index_purchase_orders_on_sourceable"
    t.index ["status"], name: "index_purchase_orders_on_status"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "sale_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "0.0"
    t.bigint "sale_id", null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_sale_items_on_product_id"
    t.index ["sale_id", "product_id"], name: "index_sale_items_on_sale_id_and_product_id", unique: true
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "destination_id"
    t.bigint "enterprise_id", null: false
    t.date "issue_date", null: false
    t.text "notes"
    t.bigint "seller_id", null: false
    t.bigint "sourceable_id"
    t.string "sourceable_type"
    t.string "status", default: "pending", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.string "sunat_cdr_code"
    t.text "sunat_cdr_description"
    t.string "sunat_document_type"
    t.string "sunat_hash"
    t.integer "sunat_number"
    t.text "sunat_qr_image"
    t.jsonb "sunat_response_data"
    t.string "sunat_series"
    t.string "sunat_status"
    t.string "sunat_uuid"
    t.text "sunat_xml"
    t.decimal "tax", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_sales_on_created_by_id"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
    t.index ["destination_id"], name: "index_sales_on_destination_id"
    t.index ["enterprise_id", "code"], name: "index_sales_on_enterprise_id_and_code", unique: true
    t.index ["enterprise_id"], name: "index_sales_on_enterprise_id"
    t.index ["issue_date"], name: "index_sales_on_issue_date"
    t.index ["seller_id"], name: "index_sales_on_seller_id"
    t.index ["sourceable_type", "sourceable_id"], name: "index_sales_on_sourceable"
    t.index ["status"], name: "index_sales_on_status"
    t.index ["sunat_status"], name: "index_sales_on_sunat_status"
    t.index ["sunat_uuid"], name: "index_sales_on_sunat_uuid", unique: true, where: "(sunat_uuid IS NOT NULL)"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "enterprise_id"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["enterprise_id"], name: "index_sessions_on_enterprise_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "ubigeos", force: :cascade do |t|
    t.string "code", limit: 6, null: false
    t.datetime "created_at", null: false
    t.string "level", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_ubigeos_on_code", unique: true
    t.index ["level", "parent_id"], name: "index_ubigeos_on_level_and_parent_id"
    t.index ["level"], name: "index_ubigeos_on_level"
    t.index ["parent_id"], name: "index_ubigeos_on_parent_id"
  end

  create_table "user_enterprise_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_enterprise_id", null: false
    t.index ["role_id"], name: "index_user_enterprise_roles_on_role_id"
    t.index ["user_enterprise_id", "role_id"], name: "index_uer_on_ue_id_and_role_id", unique: true
    t.index ["user_enterprise_id"], name: "index_user_enterprise_roles_on_user_enterprise_id"
  end

  create_table "user_enterprises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "enterprise_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["enterprise_id"], name: "index_user_enterprises_on_enterprise_id"
    t.index ["user_id", "enterprise_id"], name: "index_user_enterprises_on_user_id_and_enterprise_id", unique: true
    t.index ["user_id"], name: "index_user_enterprises_on_user_id"
  end

  create_table "user_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "value", null: false
    t.index ["user_id", "field_type"], name: "index_user_fields_on_user_id_and_field_type", unique: true
    t.index ["user_id"], name: "index_user_fields_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "first_last_name", null: false
    t.string "first_name", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.string "password_digest"
    t.string "phone_number"
    t.string "platform_role", null: false
    t.string "second_last_name"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["platform_role"], name: "index_users_on_platform_role"
    t.index ["status"], name: "index_users_on_status"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "brand"
    t.datetime "created_at", null: false
    t.bigint "enterprise_id", null: false
    t.string "model"
    t.string "plate", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["enterprise_id", "plate"], name: "index_vehicles_on_enterprise_id_and_plate", unique: true
    t.index ["enterprise_id"], name: "index_vehicles_on_enterprise_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bulk_imports", "enterprises"
  add_foreign_key "bulk_imports", "users"
  add_foreign_key "carriers", "enterprises"
  add_foreign_key "customer_quote_items", "customer_quotes"
  add_foreign_key "customer_quote_items", "products"
  add_foreign_key "customer_quotes", "customers"
  add_foreign_key "customer_quotes", "enterprises"
  add_foreign_key "customer_quotes", "ubigeos", column: "destination_id"
  add_foreign_key "customer_quotes", "users", column: "created_by_id"
  add_foreign_key "customer_quotes", "users", column: "seller_id"
  add_foreign_key "customers", "enterprises"
  add_foreign_key "customers", "ubigeos"
  add_foreign_key "dispatch_guide_items", "dispatch_guides"
  add_foreign_key "dispatch_guide_items", "products"
  add_foreign_key "dispatch_guides", "carriers"
  add_foreign_key "dispatch_guides", "enterprises"
  add_foreign_key "dispatch_guides", "ubigeos", column: "arrival_ubigeo_id"
  add_foreign_key "dispatch_guides", "ubigeos", column: "departure_ubigeo_id"
  add_foreign_key "dispatch_guides", "users", column: "created_by_id"
  add_foreign_key "dispatch_guides", "users", column: "driver_id"
  add_foreign_key "dispatch_guides", "vehicles"
  add_foreign_key "enterprise_settings", "enterprises"
  add_foreign_key "enterprises", "ubigeos"
  add_foreign_key "products", "enterprises"
  add_foreign_key "products", "providers"
  add_foreign_key "providers", "enterprises"
  add_foreign_key "providers", "ubigeos"
  add_foreign_key "purchase_order_items", "products"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_orders", "enterprises"
  add_foreign_key "purchase_orders", "providers"
  add_foreign_key "purchase_orders", "ubigeos", column: "destination_id"
  add_foreign_key "purchase_orders", "users", column: "created_by_id"
  add_foreign_key "sale_items", "products"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "enterprises"
  add_foreign_key "sales", "ubigeos", column: "destination_id"
  add_foreign_key "sales", "users", column: "created_by_id"
  add_foreign_key "sales", "users", column: "seller_id"
  add_foreign_key "sessions", "enterprises"
  add_foreign_key "sessions", "users"
  add_foreign_key "ubigeos", "ubigeos", column: "parent_id"
  add_foreign_key "user_enterprise_roles", "roles"
  add_foreign_key "user_enterprise_roles", "user_enterprises"
  add_foreign_key "user_enterprises", "enterprises"
  add_foreign_key "user_enterprises", "users"
  add_foreign_key "user_fields", "users"
  add_foreign_key "vehicles", "enterprises"
end
