#!/usr/bin/env bash
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean
bin/rails db:prepare

# db:prepare can skip loading the cache/queue/cable schemas here, because
# they share the same physical Postgres database as `primary` (see
# config/database.yml) — it sees existing migration history on that shared
# database and assumes those roles are already set up too. Explicitly load
# each one's schema, but only if its signature table is still missing, so
# this stays safe (and non-destructive) to run on every deploy.
bin/rails runner - <<'RUBY'
checks = {
  "cache" => "solid_cache_entries",
  "queue" => "solid_queue_jobs",
  "cable" => "solid_cable_messages"
}

checks.each do |db_name, table|
  config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: db_name)
  next unless config

  ActiveRecord::Base.establish_connection(config)

  if ActiveRecord::Base.connection.table_exists?(table)
    puts "[render-build] #{db_name}: #{table} already exists, skipping"
  else
    puts "[render-build] #{db_name}: loading schema (#{table} missing)"
    ActiveRecord::Tasks::DatabaseTasks.load_schema(config, :ruby, nil)
  end
end

ActiveRecord::Base.establish_connection(:primary)
RUBY
