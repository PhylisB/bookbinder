module Bookbinder
  module Commands
    class Generate
      include Commands::Naming

      def initialize(fs, sheller, context_dir, streams)
        @fs = fs
        @sheller = sheller
        @context_dir = context_dir
        @streams = streams
      end

      def command_for?(name)
        name == 'generate'
      end

      def usage
        ["generate <book-name>",
         "Generate a skeleton book that can be bound with 'bookbinder bind'"]
      end

      def run((name))
        path = context_dir.join(name)
        streams[:out].puts "Generating book at #{path}…"
        if fs.file_exist?(path)
          streams[:err].puts "Cannot generate book: directory already exists"
          1
        elsif install(path).success?
          streams[:success].puts "Successfully generated book at #{path}"
          0
        else
          1
        end
      end

      private

      attr_reader :fs, :sheller, :streams

      def install(path)
        make_middleman_dir(path)
        init_gemfile(path)
        init_config(path)
        init_index(path)
        bundle_install(path)
      end

      def make_middleman_dir(path)
        fs.make_directory(path.join('master_middleman/build'))
      end

      def init_gemfile(path)
        fs.write(
          text: <<-GEMFILE,
source "https://rubygems.org"

gem "bookbindery"
          GEMFILE
          to: path.join('Gemfile')
        )
      end

      def init_config(path)
        fs.write(
          text: YAML.dump(
            'book_repo' => '',
            'public_host' => '',
          ),
          to: path.join('config.yml')
        )
      end

      def init_index(path)
        fs.write(
          text: '# Empty book',
          to: path.join('master_middleman/source/index.md.erb')
        )
      end

      def bundle_install(path)
        Bundler.with_clean_env do
          sheller.run_command(
            "bundle install --binstubs --gemfile=#{path.join('Gemfile')}",
            out: streams[:out], err: streams[:err]
          )
        end
      end

      def context_dir
        Pathname(@context_dir)
      end
    end
  end
end
