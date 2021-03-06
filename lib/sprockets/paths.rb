module Sprockets
  module Paths
    # Returns `Environment` root.
    #
    # All relative paths are expanded with root as its base. To be
    # useful set this to your applications root directory. (`Rails.root`)
    def root
      @trail.root.dup
    end

    # Returns an `Array` of path `String`s.
    #
    # These paths will be used for asset logical path lookups.
    #
    # Note that a copy of the `Array` is returned so mutating will
    # have no affect on the environment. See `append_path`,
    # `prepend_path`, and `clear_paths`.
    def paths
      @trail.paths.dup
    end

    # Prepend a `path` to the `paths` list.
    #
    # Paths at the end of the `Array` have the least priority.
    def prepend_path(path)
      @trail.prepend_path(path)
    end

    # Append a `path` to the `paths` list.
    #
    # Paths at the beginning of the `Array` have a higher priority.
    def append_path(path)
      @trail.append_path(path)
    end

    # Clear all paths and start fresh.
    #
    # There is no mechanism for reordering paths, so its best to
    # completely wipe the paths list and reappend them in the order
    # you want.
    def clear_paths
      @trail.paths.dup.each { |path| @trail.remove_path(path) }
    end

    # Returns an `Array` of extensions.
    #
    # These extensions maybe omitted from logical path searches.
    #
    #     # => [".js", ".css", ".coffee", ".sass", ...]
    #
    def extensions
      @trail.extensions.dup
    end

    # Works like `Dir.entries`.
    #
    # Subclasses may cache this method.
    def entries(filename)
      @trail.entries(filename)
    end

    # Works like `File.stat`.
    #
    # Subclasses may cache this method.
    def stat(path)
      @trail.stat(path)
    end

    # Internal: Reverse guess logical path for fully expanded path.
    #
    # This has some known issues. For an example if a file is
    # shaddowed in the path, but is required relatively, its logical
    # path will be incorrect.
    def logical_path_for(filename)
      if root_path = paths.detect { |path| filename[path] }
        path = Pathname.new(filename).relative_path_from(Pathname.new(root_path)).to_s
        attributes = attributes_for(filename)
        path = attributes.engine_extensions.inject(path) { |p, ext| p.sub(ext, '') }
        path = "#{path}#{attributes.send(:engine_format_extension)}" unless attributes.format_extension
        extname = File.extname(path)
        path = path.sub(/\/index\./, '.') if File.basename(path, extname) == 'index'
        path
      else
        raise FileOutsidePaths, "#{filename} isn't in paths: #{paths.join(', ')}"
      end
    end

    # Public: Finds the expanded real path for a given logical path by searching
    # the environment's paths. Includes all matching paths including fallbacks
    # and shadowed matches.
    #
    #     resolve_all("application.js").first
    #     # => "/path/to/app/javascripts/application.js.coffee"
    #
    # `resolve_all` returns an `Enumerator`. This allows you to filter your
    # matches by any condition.
    #
    #     resolve_all("application").find do |path|
    #       mime_type_for(path) == "text/css"
    #     end
    #
    def resolve_all(path, options = {}, &block)
      return to_enum(__method__, path, options) unless block_given?
      path = path.to_s

      if Pathname.new(path).absolute?
        if filename = resolve_absolute_path(path, options)
          yield filename
        end
      else
        resolve_all_logical_paths(path, options, &block)
      end

      nil
    end

    # Public: Enumerate over all logical paths in the environment.
    #
    # Returns an Enumerator of [logical_path, filename].
    def logical_paths
      return to_enum(__method__) unless block_given?

      seen = Set.new
      paths.each do |root|
        stat_tree(root).each do |filename, stat|
          if stat.file?
            logical_path = logical_path_for(filename)
            if !seen.include?(logical_path)
              yield logical_path, filename
              seen << logical_path
            end
          end
        end
      end

      nil
    end

    protected
      attr_reader :trail

      # Internal: Resolve absolute path to ensure it exists and is in the
      # load path.
      #
      # filename - String
      # options  - Hash (default: {})
      #
      # Returns String filename or nil
      def resolve_absolute_path(filename, options = {})
        content_type = options[:content_type]

        if paths.detect { |path| filename[path] }
          if stat(filename)
            if content_type.nil? || content_type == content_type_of(filename)
              return filename
            end
          end
        end
      end

      # Internal: Resolve logical path in trail load paths.
      #
      # logical_path - String
      # options      - Hash (default: {})
      # block
      #   filename - String or nil
      #
      # Returns nothing.
      def resolve_all_logical_paths(logical_path, options = {})
        content_type = options[:content_type]
        extension = attributes_for(logical_path).format_extension
        content_type_extension = extension_for_mime_type(content_type)

        paths = [logical_path]

        path_without_extension = extension ?
          logical_path.sub(extension, '') :
          logical_path

        # optimization: bower.json can only be nested one level deep
        if !path_without_extension.index('/')
          paths << File.join(path_without_extension, "bower.json")
        end

        paths << File.join(path_without_extension, "index#{extension}")

        @trail.find_all(*paths, options).each do |path|
          if File.basename(logical_path) != 'bower.json'
            path = expand_bower_path(path, extension || content_type_extension) || path
          end

          if content_type.nil? || content_type == content_type_of(path)
            yield path
          end
        end
      end
  end
end
