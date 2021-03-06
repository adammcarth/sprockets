require 'sprockets/base'
require 'sprockets/context'
require 'sprockets/cached_environment'

require 'digest/sha1'
require 'hike'
require 'logger'

module Sprockets
  class Environment < Base
    # `Environment` should initialized with your application's root
    # directory. This should be the same as your Rails or Rack root.
    #
    #     env = Environment.new(Rails.root)
    #
    def initialize(root = ".")
      @trail = Hike::Trail.new(root)

      self.logger = Logger.new($stderr)
      self.logger.level = Logger::FATAL

      self.default_external_encoding = Encoding::UTF_8

      # Create a safe `Context` subclass to mutate
      @context_class = Class.new(Context)

      # Set the default digest
      @digest_class = Digest::SHA1
      @version = ''

      @mime_types        = Sprockets.registered_mime_types
      @engines           = Sprockets.engines
      @engine_mime_types = Sprockets.engine_mime_types
      @preprocessors     = Sprockets.preprocessors
      @postprocessors    = Sprockets.postprocessors
      @bundle_processors = Sprockets.bundle_processors
      @compressors       = Sprockets.compressors

      Sprockets.paths.each do |path|
        append_path(path)
      end

      @engines.each do |ext, klass|
        add_engine_to_trail(ext)
      end

      @mime_types.each do |ext, type|
        @trail.append_extension(ext)
      end

      self.cache = Cache::MemoryStore.new
      expire_cache!

      yield self if block_given?
    end

    # Returns a cached version of the environment.
    #
    # All its file system calls are cached which makes `cached` much
    # faster. This behavior is ideal in production since the file
    # system only changes between deploys.
    def cached
      CachedEnvironment.new(self)
    end
    alias_method :index, :cached

    # Cache `find_asset` calls
    def find_asset(path, options = {})
      cached.find_asset(path, options)
    end

    protected
      def expire_cache!
        # Clear digest to be recomputed
        @digest = nil
        @asset_cache = Cache::MemoryStore.new
      end
  end
end
