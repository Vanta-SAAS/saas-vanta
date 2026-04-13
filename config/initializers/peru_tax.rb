require "bigdecimal"
require "bigdecimal/util"

module PeruTax
  IGV_RATE = BigDecimal("0.18")
  IGV_DIVISOR = BigDecimal("1") + IGV_RATE

  # Obtiene la base imponible (sin IGV) de un monto que ya lo incluye
  def self.base_amount(total_with_igv)
    (to_bd(total_with_igv) / IGV_DIVISOR).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # Extrae el IGV de un monto que ya lo incluye
  def self.extract_igv(total_with_igv)
    (to_bd(total_with_igv) - base_amount(total_with_igv)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # Base unitaria sin IGV con precision completa (sin redondear)
  def self.base_unit_price(unit_price_with_igv, tax_type: "gravado")
    price = to_bd(unit_price_with_igv)
    tax_type.to_s == "gravado" ? price / IGV_DIVISOR : price
  end

  # Devuelve los montos de una linea calculados igual que el microservicio:
  # line_ext = round(quantity * base_unit, 2)
  # line_igv = round(line_ext * IGV_RATE, 2)
  # line_total = line_ext + line_igv
  def self.line_amounts(unit_price:, quantity:, tax_type: "gravado")
    qty = to_bd(quantity)
    base_unit = base_unit_price(unit_price, tax_type: tax_type)
    line_ext = (qty * base_unit).round(2, BigDecimal::ROUND_HALF_UP)
    line_igv = tax_type.to_s == "gravado" ? (line_ext * IGV_RATE).round(2, BigDecimal::ROUND_HALF_UP) : BigDecimal("0")
    {
      base_unit: base_unit,
      line_ext: line_ext,
      line_igv: line_igv,
      line_total: line_ext + line_igv
    }
  end

  def self.to_bd(value)
    case value
    when BigDecimal then value
    when nil then BigDecimal("0")
    when Integer then BigDecimal(value)
    when Float then value.to_d
    else BigDecimal(value.to_s)
    end
  end
end
