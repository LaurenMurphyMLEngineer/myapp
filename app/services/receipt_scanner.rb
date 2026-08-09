require "net/http"
require "uri"
require "json"
require "securerandom"

# Extracts merchant, total, and purchase date from a receipt image using the
# OCR.space API (https://ocr.space/ocrapi). Requires OCR_SPACE_API_KEY to be
# set in the environment. Get a free key at https://ocr.space/ocrapi/freekey
class ReceiptScanner
  API_URL = "https://api.ocr.space/parse/image"

  def initialize(image_path)
    @image_path = image_path
  end

  def extract
    text = ocr_text

    {
      raw_text: text,
      merchant: extract_merchant(text),
      total: extract_total(text),
      purchased_on: extract_date(text)
    }
  end

  private

  def ocr_text
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["apikey"] = ENV.fetch("OCR_SPACE_API_KEY")

    boundary = "ReceiptScanner#{SecureRandom.hex(8)}"
    request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    request.body = build_multipart_body(boundary)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    return "" if result["IsErroredOnProcessing"]

    result.dig("ParsedResults", 0, "ParsedText").to_s
  rescue StandardError => e
    Rails.logger.error("ReceiptScanner OCR failed: #{e.class}: #{e.message}")
    ""
  end

  def build_multipart_body(boundary)
    filename = File.basename(@image_path)
    file_content = File.binread(@image_path)

    body = +""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: application/octet-stream\r\n\r\n"
    body << file_content
    body << "\r\n--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"OCREngine\"\r\n\r\n2\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"scale\"\r\n\r\ntrue\r\n"
    body << "--#{boundary}--\r\n"
    body
  end

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
