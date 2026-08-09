require "net/http"
require "uri"
require "json"
require "base64"

# Extracts structured data (merchant, total, purchase date, spending
# category) from a photo of a receipt using Google's Gemini API
# (Interactions API), which has a genuine free tier. Requires
# GEMINI_API_KEY to be set in the environment. Get a free key at
# https://aistudio.google.com/apikey
class ReceiptScanner
  API_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
  CATEGORIES = %w[Groceries Dining Transportation Shopping Entertainment Utilities Health Travel Other].freeze

  SCHEMA = {
    type: "object",
    properties: {
      merchant: { type: "string", description: "The store or business name" },
      total: { type: "number", description: "The final total amount charged, as a plain number" },
      purchased_on: { type: "string", description: "The purchase date, formatted as YYYY-MM-DD" },
      category: { type: "string", enum: CATEGORIES, description: "Best-fit spending category" },
      raw_text: { type: "string", description: "All legible text on the receipt, transcribed as-is" }
    },
    required: ["raw_text"]
  }.freeze

  def initialize(image_path, content_type: "image/jpeg")
    @image_path = image_path
    @content_type = content_type
  end

  def extract
    result = call_gemini

    {
      raw_text: result["raw_text"].to_s,
      merchant: result["merchant"],
      total: result["total"] && result["total"].to_f,
      purchased_on: parse_date(result["purchased_on"]),
      category: result["category"]
    }
  rescue StandardError => e
    Rails.logger.error("ReceiptScanner failed: #{e.class}: #{e.message}")
    { raw_text: "", merchant: nil, total: nil, purchased_on: nil, category: nil }
  end

  private

  def call_gemini
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
    request["content-type"] = "application/json"

    request.body = {
      model: ENV.fetch("GEMINI_MODEL", "gemini-3.6-flash"),
      input: [
        { type: "text", text: "Extract this receipt's data." },
        { type: "image", data: encoded_image, mime_type: @content_type }
      ],
      response_format: {
        type: "text",
        mime_type: "application/json",
        schema: SCHEMA
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60) do |http|
      http.request(request)
    end

    body = JSON.parse(response.body)
    raise "Gemini API error: #{body['error']}" if body["error"]

    model_output = body["steps"]&.find { |step| step["type"] == "model_output" }
    raise "No model_output step in Gemini response: #{body.inspect}" unless model_output

    text_block = model_output["content"]&.find { |block| block["type"] == "text" }
    raise "No text content in Gemini response: #{body.inspect}" unless text_block

    JSON.parse(text_block["text"])
  end

  def encoded_image
    Base64.strict_encode64(File.binread(@image_path))
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end
end
