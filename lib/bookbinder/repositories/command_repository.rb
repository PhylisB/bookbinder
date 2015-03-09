Dir.glob(File.expand_path('../../commands/*.rb', __FILE__)).each do |command_file|
  require command_file
end
require_relative '../configuration_fetcher'
require_relative '../configuration_validator'
require_relative '../dita_html_to_middleman_formatter'
require_relative '../html_document_manipulator'
require_relative '../ingest/cloner_factory'
require_relative '../local_dita_preprocessor'
require_relative '../local_dita_to_html_converter'
require_relative '../local_file_system_accessor'
require_relative '../middleman_runner'
require_relative '../spider'
require_relative '../subnav_formatter'
require_relative '../yaml_loader'

module Bookbinder
  module Repositories
    class CommandRepository
      include Enumerable

      def initialize(logger, version_control_system)
        @logger = logger
        @version_control_system = version_control_system
      end

      def each(&block)
        list.each(&block)
      end

      def help
        @help ||= Commands::Help.new(
          logger,
          [version] + standard_commands
        )
      end

      private

      attr_reader :logger, :version_control_system

      def list
        standard_commands + flags
      end

      def flags
        @flags ||= [ version, help ]
      end

      def standard_commands
        @standard_commands ||= [
          build_and_push_tarball,
          Commands::GeneratePDF.new(logger, configuration_fetcher),
          bind,
          Commands::PushFromLocal.new(logger, configuration_fetcher, 'acceptance'),
          push_local_to_staging,
          Commands::PushToProd.new(logger, configuration_fetcher),
          Commands::RunPublishCI.new(bind, push_local_to_staging, build_and_push_tarball),
          Commands::Tag.new(logger, configuration_fetcher),
          Commands::UpdateLocalDocRepos.new(logger, configuration_fetcher),
        ]
      end

      def version
        @version ||= Commands::Version.new(logger)
      end

      def bind
        @bind ||= Commands::Bind.new(
          logger,
          configuration_fetcher,
          ArchiveMenuConfiguration.new(
            loader: config_loader,
            config_filename: 'bookbinder.yml'
          ),
          version_control_system,
          local_file_system_accessor,
          middleman_runner,
          spider,
          final_app_directory,
          server_director,
          File.absolute_path('.'),
          dita_preprocessor,
          Ingest::ClonerFactory.new(logger, version_control_system)
        )
      end

      def push_local_to_staging
        @push_local_to_staging ||= Commands::PushFromLocal.new(
          logger,
          configuration_fetcher,
          'staging'
        )
      end

      def build_and_push_tarball
        @build_and_push_tarball ||= Commands::BuildAndPushTarball.new(
          logger,
          configuration_fetcher
        )
      end

      def spider
        @spider ||= Spider.new(logger, app_dir: final_app_directory)
      end

      def server_director
        @server_director ||= ServerDirector.new(
          logger,
          directory: final_app_directory
        )
      end

      def middleman_runner
        @middleman_runner ||= MiddlemanRunner.new(logger, version_control_system)
      end

      def configuration_fetcher
        @configuration_fetcher ||= ConfigurationFetcher.new(
          logger,
          ConfigurationValidator.new(logger, local_file_system_accessor),
          config_loader
        ).tap do |fetcher|
          fetcher.set_config_file_path './config.yml'
        end
      end

      def config_loader
        @config_loader ||= YAMLLoader.new
      end

      def final_app_directory
        @final_app_directory ||= File.absolute_path('final_app')
      end

      def dita_preprocessor
        @dita_preprocessor ||=
            LocalDitaPreprocessor.new(local_dita_processor,
                                 dita_html_to_middleman_formatter,
                                 local_file_system_accessor)
      end

      def local_dita_processor
        @local_dita_processor ||=
            LocalDitaToHtmlConverter.new(Sheller.new(logger),
                                         ENV['PATH_TO_DITA_OT_LIBRARY'])
      end

      def dita_html_to_middleman_formatter
        @dita_html_to_middleman_formatter ||= DitaHtmlToMiddlemanFormatter.new(local_file_system_accessor,
                                                                               subnav_formatter,
                                                                               html_document_manipulator)
      end

      def subnav_formatter
        @subnav_formatter ||= SubnavFormatter.new
      end

      def html_document_manipulator
        @html_document_manipulator ||= HtmlDocumentManipulator.new
      end

      def local_file_system_accessor
        @local_file_system_accessor ||= LocalFileSystemAccessor.new
      end
    end
  end
end
