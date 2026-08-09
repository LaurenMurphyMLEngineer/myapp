require "net/http"
require "uri"
require "json"
require "base64"

# Extracts structured data (merchant, total, purchase date, spending
# category) from a photo of a receipt using Claude's vision + tool-use
# capability. Requires ANTHROPIC_API_KEY to be set in the environment.
# Get a key at https://console.anthropic.com
class ReceiptScanner
  API_URL = "https://api.anthropic.com/v1/messages"
  ANTHROPIC_VERSION = "2023-06-01"
  CATEGORIES = %w[Groceries Dining Transportation Shopping Entertainment Utilities Health Travel Other].freeze

  TOOL = {
    name: "record_receipt",
    description: "Record structured data extracted from a photo of a receipt.",
    input_schema: {
      type: "object",
      properties: {
        merchant: { type: %w[string null], description: "The store or business name" },
        total: { type: %w[number null], description: "The final total amount charged, as a plain number" },
        purchased_on: { type: %w[string null], description: "The purchase date, formatted as YYYY-MM-DD" },
        category: { type: %w[string null], enum: CATEGORIES, description: "Best-fit spending category" },
        raw_text: { type: "string", description: "All legible text on the receipt, transcribed as-is" }
      },
      required: ["raw_text"]
    }
  }.freeze

  def initialize(image_path, content_type: "image/jpeg")
    @image_path = image_path
    @content_type = content_type
  end

  def extract
    result = call_claude

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

  def call_claude
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = ENV.fetch("ANTHROPIC_API_KEY")
    request["anthropic-version"] = ANTHROPIC_VERSION
    request["content-type"] = "application/json"

    request.body = {
      model: ENV.fetch("CLAUDE_MODEL", "claude-haiku-4-5-20251001"),
      max_tokens: 1024,
      tools: [TOOL],
      tool_choice: { type: "tool", name: "record_receipt" },
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: @content_type, data: encoded_image } },
            { type: "text", text: "Extract this receipt's data using the record_receipt tool." }
          ]
        }
      ]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60) do |http|
      http.request(request)
    end

    body = JSON.parse(response.body)
    raise "Claude API error: #{body["error"]}" if body["error"]

    tool_use = body["content"]&.find { |block| block["type"] == "tool_use" }
    raise "No tool_use block in Claude response: #{body.inspect}" unless tool_use

    tool_use["input"]
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
