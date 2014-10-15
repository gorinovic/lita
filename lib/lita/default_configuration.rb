module Lita
  class DefaultConfiguration
    LOG_LEVELS = %w(debug info warn error fatal)

    attr_reader :registry
    attr_reader :root

    def initialize(registry)
      @registry = registry
      @root = Configuration.new

      adapters_config
      handlers_config
      http_config
      redis_config
      robot_config
    end

    def finalize
      final_config = root.finalize
      add_adapter_attribute(final_config)
      add_struct_access_to_redis(final_config.redis)
      final_config
    end

    private

    def adapters_config
      adapters = registry.adapters

      root.config :adapters do
        adapters.each do |key, adapter|
          combine(key, adapter.configuration)
        end
      end
    end

    def add_adapter_attribute(config)
      config.singleton_class.class_exec { attr_accessor :adapter }
      config.adapter = Class.new(Config) do
        def []=(key, value)
          deprecation_warning

          super
        end

        def [](key)
          deprecation_warning

          super
        end

        def method_missing(name, *args)
          deprecation_warning

          super
        end

        def deprecation_warning
          Lita.logger.warn(I18n.t("lita.config.adapter_deprecated"))
        end
        private :deprecation_warning
      end.new
    end

    def add_struct_access_to_redis(redis)
      def redis.method_missing(name, *args)
        Lita.logger.warn(I18n.t("lita.config.redis_struct_access_deprecated"))
        name_string = name.to_s
        if name_string.chomp!("=")
          self[name_string.to_sym] = args.first
        else
          self[name_string.to_sym]
        end
      end
    end

    def handlers_config
      handlers = registry.handlers

      root.config :handlers do
        handlers.each do |handler|
          if handler.configuration.children?
            combine(handler.namespace, handler.configuration)
          else
            old_config = Config.new
            handler.default_config(old_config) if handler.respond_to?(:default_config)
            config(handler.namespace, default: old_config)
          end
        end
      end
    end

    def http_config
      root.config :http do
        config :host, type: String, default: "0.0.0.0"
        config :port, type: Integer, default: 8080
        config :min_threads, type: Integer, default: 0
        config :max_threads, type: Integer, default: 16
        config :middleware, type: Array, default: []
      end
    end

    def redis_config
      root.config :redis, type: Hash, default: {}
    end

    def robot_config
      root.config :robot do
        config :name, type: String, default: "Lita"
        config :mention_name, type: String
        config :alias, type: String
        config :adapter, types: [String, Symbol], default: :shell
        config :locale, types: [String, Symbol], default: I18n.locale
        config :log_level, types: [String, Symbol], default: :info do
          validate do |value|
            unless LOG_LEVELS.include?(value.to_s.downcase.strip)
              "log_level must be one of: #{LOG_LEVELS.join(", ")}"
            end
          end
        end
        config :admins
      end
    end
  end
end
