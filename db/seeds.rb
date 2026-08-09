# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Creates the first (and, for this single-user app, only) login from
# ADMIN_EMAIL / ADMIN_PASSWORD env vars — only if no user exists yet, so
# it's safe to run on every deploy. This is how you get an account without
# needing shell access to run `rails console` in production.
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present? && User.count.zero?
  User.create!(email_address: ENV["ADMIN_EMAIL"], password: ENV["ADMIN_PASSWORD"])
  puts "[seeds] Created initial user #{ENV['ADMIN_EMAIL']}"
end
