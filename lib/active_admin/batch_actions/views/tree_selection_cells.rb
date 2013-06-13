require 'active_admin/component'

module ActiveAdmin
  module BatchActions

    class ResourceSelectionToggleTreeCell < ActiveAdmin::Component
      builder_method :resource_selection_toggle_tree_cell

      def build(options = {})
        input :type => 'checkbox', 'data-bind' => 'select-tree', 'data-select-tree-name' => options[:name] || 'tree-selection'
      end
    end

    class ResourceSelectionTreeCell < ActiveAdmin::Component
      builder_method :resource_selection_tree_cell

      def build(resource, options = {})
        input :type => "checkbox", :name => "tree_collection_selection[]", :value => resource.id,
          'data-bind' => 'select-tree', 'data-select-tree-parent' => options[:name] || 'tree-selection',
          'data-select-tree-name' => "#{resource.class.model_name.underscore}-#{resource.id}",
          'data-select-tree-count-total' => options.fetch(:count) { true }
      end
    end

  end
end
