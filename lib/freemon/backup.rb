# frozen_string_literal: true

require "fileutils"

# Snapshots and restores an instance's data: the primary SQLite database and
# the Active Storage files beside it. The cache, queue and cable databases are
# left out; they hold nothing that can't be rebuilt.
class Freemon::Backup
  DATABASE = "database.sqlite3"
  STORAGE = "storage"

  def self.for_app
    database = File.expand_path(ActiveRecord::Base.connection_db_config.database, Rails.root)
    new(database: database, storage: ActiveStorage::Blob.service.root.to_s)
  end

  def initialize(database:, storage:)
    @database = database
    @storage = storage
  end

  # VACUUM INTO writes a consistent copy even while the app is running,
  # unlike copying the file, which can miss writes still in the WAL.
  def create(destination)
    snapshot = File.join(destination, DATABASE)
    raise ArgumentError, "#{destination} already contains a backup" if File.exist?(snapshot)

    FileUtils.mkdir_p(destination)
    SQLite3::Database.new(@database, readonly: true) { |db| db.execute("VACUUM INTO ?", [ snapshot ]) }
    copy_blobs(@storage, File.join(destination, STORAGE))
    destination
  end

  # Replaces the live data with a snapshot. Only run while the server is stopped.
  def restore(source)
    snapshot = File.join(source, DATABASE)
    raise ArgumentError, "No #{DATABASE} in #{source}" unless File.file?(snapshot)

    FileUtils.mkdir_p(File.dirname(@database))
    %w[-wal -shm].each { |suffix| FileUtils.rm_f("#{@database}#{suffix}") }
    FileUtils.cp(snapshot, @database)
    blob_dirs(@storage).each { |dir| FileUtils.rm_rf(dir) }
    copy_blobs(File.join(source, STORAGE), @storage)
  end

  private

  # Active Storage keeps files in nested folders next to the database files.
  def blob_dirs(root)
    return [] unless Dir.exist?(root)

    Dir.children(root).map { |entry| File.join(root, entry) }.select { |path| File.directory?(path) }
  end

  def copy_blobs(from, to)
    FileUtils.mkdir_p(to)
    blob_dirs(from).each { |dir| FileUtils.cp_r(dir, to) }
  end
end
