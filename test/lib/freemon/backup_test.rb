# frozen_string_literal: true

require "test_helper"

class Freemon::BackupTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @live = File.join(@dir, "live")
    @database = File.join(@live, "production.sqlite3")
    FileUtils.mkdir_p(File.join(@live, "ab", "cd"))
    File.write(File.join(@live, "ab", "cd", "abcd1234"), "receipt")
    SQLite3::Database.new(@database) do |db|
      db.execute("PRAGMA journal_mode=WAL")
      db.execute("CREATE TABLE expenses (description TEXT)")
      db.execute("INSERT INTO expenses VALUES ('MacBook')")
    end
    @backup = Freemon::Backup.new(database: @database, storage: @live)
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "a backup holds the database and the stored files, but not the live database files" do
    snapshot = @backup.create(File.join(@dir, "snapshot"))

    assert_equal [ [ "MacBook" ] ], descriptions(File.join(snapshot, "database.sqlite3"))
    assert_equal "receipt", File.read(File.join(snapshot, "storage", "ab", "cd", "abcd1234"))
    assert_equal [ "ab" ], Dir.children(File.join(snapshot, "storage"))
  end

  test "restoring brings back the snapshot and drops files it doesn't have" do
    snapshot = @backup.create(File.join(@dir, "snapshot"))
    SQLite3::Database.new(@database) { |db| db.execute("DELETE FROM expenses") }
    FileUtils.rm_rf(File.join(@live, "ab"))
    FileUtils.mkdir_p(File.join(@live, "zz"))

    @backup.restore(snapshot)

    assert_equal [ [ "MacBook" ] ], descriptions(@database)
    assert File.exist?(File.join(@live, "ab", "cd", "abcd1234"))
    assert_not File.exist?(File.join(@live, "zz"))
  end

  test "it won't overwrite a backup or restore from a folder without one" do
    snapshot = @backup.create(File.join(@dir, "snapshot"))

    assert_raises(ArgumentError) { @backup.create(snapshot) }
    assert_raises(ArgumentError) { @backup.restore(@dir) }
  end

  private

  def descriptions(path)
    db = SQLite3::Database.new(path, readonly: true)
    db.execute("SELECT description FROM expenses")
  ensure
    db&.close
  end
end
