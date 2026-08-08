class ReceiptScanner
  def initialize(image_path)
    @image_path = image_path
  end

  def extract
    text = RTesseract.new(@image_path).to_s

    {
      raw_text: text,
      merchant: extract_merchant(text),
      total: extract_total(text),
      purchased_on: extract_date(text)
    }
  end

  private

  def extract_merchant(text)
    text.lines.map(&:strip).find(&:present?)
  end

  def extract_total(text)
    match = text.match(/total[:\s]*\$?\s*(\d+\.\d{2})/i)
    match && match[1].to_f
  end

  def extract_date(text)
    match = text.match(/(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/)
    return nil unless match

    Date.parse(match[1])
  rescue ArgumentError
    nil
  end
end
