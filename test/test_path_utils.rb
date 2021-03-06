# -*- coding: utf-8 -*-
require 'sprockets_test'
require 'sprockets/path_utils'

class TestPathUtils < Sprockets::TestCase
  include Sprockets::PathUtils

  test "stat" do
    assert_kind_of File::Stat, stat(FIXTURE_ROOT)
    refute stat("/tmp/sprockets/missingfile")
  end

  test "entries" do
    assert_equal [
      "asset",
      "compass",
      "context",
      "default",
      "directives",
      "encoding",
      "engines",
      "errors",
      "public",
      "sass",
      "server",
      "symlink"
    ], entries(FIXTURE_ROOT)
  end

  test "stat directory" do
    assert_equal 23, stat_directory(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_directory(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_directory(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  test "stat tree" do
    assert_equal 44, stat_tree(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_tree(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_tree(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  test "read unicode" do
    assert_equal "var foo = \"bar\";\n",
      read_unicode_file(fixture_path('encoding/ascii.js'))
    assert_equal "var snowman = \"☃\";",
      read_unicode_file(fixture_path('encoding/utf8.js'))
    assert_equal "var snowman = \"☃\";",
      read_unicode_file(fixture_path('encoding/utf8_bom.js'))

    assert_raises Sprockets::EncodingError do
      read_unicode_file(fixture_path('encoding/utf16.js'))
    end
  end

  test "atomic write without errors" do
    filename = "atomic.file"
    begin
      contents = "Atomic Text"
      atomic_write(filename, Dir.pwd) do |file|
        file.write(contents)
        assert !File.exist?(filename)
      end
      assert File.exist?(filename)
      assert_equal contents, File.read(filename)
    ensure
      File.unlink(filename) rescue nil
    end
  end
end
