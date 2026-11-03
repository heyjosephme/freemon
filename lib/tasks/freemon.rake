# frozen_string_literal: true

# Used by bin/freemon backup / restore, which supply DIR and FROM.
namespace :freemon do
  desc "Snapshot the primary database and stored files into DIR"
  task backup: :environment do
    dir = ENV["DIR"].presence or abort "Usage: bin/rails freemon:backup DIR=path"
    puts "Backed up to #{Freemon::Backup.for_app.create(dir)}"
  end

  desc "Replace the primary database and stored files with the snapshot in FROM (stop the server first)"
  task restore: :environment do
    from = ENV["FROM"].presence or abort "Usage: bin/rails freemon:restore FROM=path"
    Freemon::Backup.for_app.restore(from)
    puts "Restored from #{from}"
  end
end
