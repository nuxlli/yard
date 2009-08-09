module YARD
  module Generators
    class FullDocGenerator < Base
      before_generate :is_namespace?
      before_list :setup_options
      before_list :generate_assets
      before_list :generate_index
      before_list :generate_files
      
      def sections_for(object) 
        case object
        when CodeObjects::RootObject
          [:header, [G(RootGenerator)]]
        when CodeObjects::ClassObject
          [:header, [G(ClassGenerator)]]
        when CodeObjects::ModuleObject
          [:header, [G(ModuleGenerator)]]
        end
      end
      
      protected
      
      def setup_options
        options[:readme] ||= Dir['{README,README.*}']
        options[:files]  ||= []
      end
    
      def css_file;         'style.css'             end
      def css_custom_file;  'custom.css'            end
      def css_syntax_file;  'syntax_highlight.css'  end
      def js_file;          'jquery.js'             end
      def js_app_file;      'app.js'                end
      
      def readme_file
        @readme_file ||= [options[:readme]].flatten.compact.find do |readme|
          File.exists?(readme.to_s)
        end.to_s
      end
      
      def readme_file_exists?; not readme_file.empty?; end
      
      def extra_files
        [readme_file] + options[:files]
      end
      
      def generate_assets
        if format == :html && serializer
          [css_file, css_custom_file, css_syntax_file, js_file, js_app_file].each do |filename|
            template_file = find_template template_path(filename)
            serializer.serialize(filename, File.read(template_file)) unless template_file.nil?
          end
        end
        true
      end
      
      def generate_index(all_objects)
        if format == :html && serializer
          ns = all_objects.select {|o| o.type == :module || o.type == :class }
          all_namespaces = { 
            :objects => ns.sort_by {|o| o.path },
            :root => all_objects.find {|o| o.type == :root && (!o.meths.empty? || !o.constants.empty?) }
          }
          all_methods = { :objects => methods_to_show(all_objects) }
          
          serializer.serialize 'index.html', render(:index)
          serializer.serialize 'all-files.html', render(:all_files)
          serializer.serialize 'all-namespaces.html', render(:all_namespaces, all_namespaces)
          serializer.serialize 'all-methods.html', render(:all_methods, all_methods)
        end
        true
      end
      
      def generate_files
        if format == :html && serializer 
          extra_files.each do |file|
            next unless File.exists?(file)
            @contents = File.read(file)
            file = File.basename(file)
            serializer.serialize file + '.html', render(:file, :filename => file)
          end
        end
        true
      end
      
      def markup_for(filename)
        case File.extname(filename).downcase
        when /^\.(?:mdown|markdown|mkdn|markdn|md)$/
          :markdown
        when ".textile"
          :textile
        when /^\.html?$/
          if format == :html
            nil # no markup, use raw data
          else
            # TODO implement some html->plaintext markup
            :rdoc
          end
        else
          if @contents =~ /\A#!(\S+)\s*$/ # Shebang support
            markup = $1
            @contents.gsub!(/\A.+?\r?\n/, '')
            markup.to_sym
          else
            :rdoc
          end
        end
      end
      
      def methods_to_show(namespaces)
        meths = namespaces.inject([]) do |arr, namespace|
          next(arr) unless namespace.is_a?(CodeObjects::NamespaceObject)
          more_meths = namespace.meths(:included => false, :inherited => false)
          more_meths = more_meths.select {|object| object.is_explicit? }
          arr += more_meths
        end
        if options[:verifier]
          meths.reject! do |object|
            # FIXME we should be using call_verifier here, but visibility
            # is checked on the generator, not the object
            options[:verifier].call(object, object).is_a?(FalseClass)
          end
        end
        meths.sort_by {|object| object.path }
      end
    end
  end
end
