module ActiveAdmin
  module Views
    class TableFor < Arbre::HTML::Table
      builder_method :table_for

      def tag_name
        'table'
      end

      def build(collection, options = {})
        @sortable       = options.delete(:sortable)
        @resource_class = options.delete(:i18n)
        @row_builder    = options.delete(:row_builder)
        @cell_builder   = options.delete(:cell_builder)
        @collection     = collection
        @item_rows      = { }
        @used_row_cols  = { }
        @columns        = []
        build_table
        super(options)
      end

      def column(*args, &block)
        create_column(*args, &block).tap do |col|
          build_column_elements(col, @collection)
        end
      end

        # Display a column for checkbox
        def selectable_column
          return unless active_admin_config.batch_actions.any?
          column( resource_selection_toggle_cell, { :class => "selectable" } ) { |resource| resource_selection_cell( resource ) }
        end

        # Display a column for a tree-based check box selection
        def selectable_tree_column(options = {})
          column(resource_selection_toggle_tree_cell(options), { :class => "selection" } ) { |resource| resource_selection_tree_cell(resource, options) }
        end

        # Display a column for the id
        def id_column
          column(resource_class.human_attribute_name(resource_class.primary_key), :sortable => resource_class.primary_key) do |resource|
            link_to resource.id, resource_path(resource), :class => "resource_id_link"
          end
        end

      def sortable?
        @sortable
      end

      # Returns the columns to display based on the conditional block
      def visible_columns
        @visible_columns ||= @columns.select{|col| col.display_column? }
      end

      protected

      def create_column(*args, &block)
        options = default_options.merge(args.extract_options!)
        title = args[0]
        data  = args[1] || args[0]

        col = Column.new(title, data, @resource_class, options, &block)
        @columns << col

        col
      end

      def build_column_elements(col, collection, options = { })

        # Build our header item
        within @header_row do
          build_table_header(col)
        end

        build_table_cells(col, collection, options)
      end

      def build_table_cells(col, collection, options = { })
        # Add a table cell for each item
        collection.each_with_index do |item, i|
          fill_row(item, col) do |row|
            if @cell_builder
              instance_exec(col, item, &@cell_builder)
            else
              within row do
                build_table_cell(col, item)
              end
            end
          end
        end
      end

      def fill_row(item, col)
        @used_row_cols[item] ||= { }
        unless @used_row_cols[item][col]
          yield(get_row(item))
          @used_row_cols[item][col] = true
        end
      end

      def build_table
        build_table_head
        build_table_body
      end

      def build_table_head
        @thead = thead do
          @header_row = tr
        end
      end

      def build_table_header(col)
        classes = Arbre::HTML::ClassList.new
        sort_key = sortable? && col.sortable? && col.sort_key

        classes << 'sortable'                         if sort_key
        classes << "sorted-#{current_sort[1]}"        if sort_key && current_sort[0] == sort_key
        classes << col.html_class

        if sort_key
          th :class => classes do
            link_to(col.pretty_title, params.merge(:order => "#{sort_key}_#{order_for_sort_key(sort_key)}").except(:page))
          end
        else
          th(col.pretty_title, :class => classes)
        end
      end

      def default_row_builder(item)
        tr(:class => cycle('odd', 'even'), :id => dom_id(item))
      end

      def set_row(item, row)
        @item_rows[item] ||= row
      end

      def get_row(item)
        @item_rows[item]
      end

      def build_table_body
        @tbody = tbody do
          build_table_rows(@collection)
        end
      end

      def build_table_rows(collection)
        if @row_builder
          collection.each { |item| set_row(item, instance_exec(item, &@row_builder)) }
        else
          collection.each { |item| set_row(item, default_row_builder(item)) }
        end
      end

      def build_table_cell(col, item)
        td(:class =>  col.html_class) do
          rvalue = call_method_or_proc_on(item, col.data, :exec => false)
          if col.data.is_a?(Symbol)
            rvalue = pretty_format(rvalue)
          end
          rvalue
        end
      end

      # Returns an array for the current sort order
      #   current_sort[0] #=> sort_key
      #   current_sort[1] #=> asc | desc
      def current_sort
        @current_sort ||= if params[:order] && params[:order] =~ /^([\w\_\.]+)_(desc|asc)$/
          [$1,$2]
        else
          []
        end
      end

      # Returns the order to use for a given sort key
      #
      # Default is to use 'desc'. If the current sort key is
      # 'desc' it will return 'asc'
      def order_for_sort_key(sort_key)
        current_key, current_order = current_sort
        return 'desc' unless current_key == sort_key
        current_order == 'desc' ? 'asc' : 'desc'
      end

      def default_options
        {
          :i18n => @resource_class
        }
      end

      class Column

        attr_accessor :title, :data , :html_class

        def initialize(*args, &block)
          @options = args.extract_options!

          @title = args[0]
          @html_class = @options.delete(:class) || @title.to_s.downcase.underscore.gsub(/ +/,'_')
          @data  = args[1] || args[0]
          @data = block if block
          @resource_class = args[2]
        end

        def sortable?
          if @data.is_a?(Proc)
            [String, Symbol].include?(@options[:sortable].class)
          elsif @options.has_key?(:sortable)
            @options[:sortable]
          elsif @data.respond_to?(:to_sym) && @resource_class
            !@resource_class.reflect_on_association(@data.to_sym)
          else
            true
          end
        end

        #
        # Returns the key to be used for sorting this column
        #
        # Defaults to the column's method if its a symbol
        #   column :username
        #   # => Sort key will be set to 'username'
        #
        # You can set the sort key by passing a string or symbol
        # to the sortable option:
        #   column :username, :sortable => 'other_column_to_sort_on'
        #
        # If you pass a block to be rendered for this column, the column
        # will not be sortable unless you pass a string to sortable to
        # sort the column on:
        #
        #   column('Username', :sortable => 'login'){ @user.pretty_name }
        #   # => Sort key will be 'login'
        #
        def sort_key
          # If boolean or nil, use the default sort key.
          if @options[:sortable] == true || @options[:sortable] == false || @options[:sortable].nil?
            @data.to_s
          else
            @options[:sortable].to_s
          end
        end

        def pretty_title
          if @title.is_a?(Symbol)
            default_title =  @title.to_s.titleize
            if @options[:i18n] && @options[:i18n].respond_to?(:human_attribute_name)
              @title = @options[:i18n].human_attribute_name(@title, :default => default_title)
            else
              default_title
            end
          else
            @title
          end
        end
      end
    end
  end
end
