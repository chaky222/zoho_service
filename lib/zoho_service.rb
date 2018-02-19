require "zoho_service/version"
require "zoho_service/Hash"
require "active_support"
require "active_support/core_ext"
require "zoho_service/base"
require "zoho_service/api_connector"
require "zoho_service/api_collection"

module ZohoService
  def self.name_to_many(model_name)
    model_name.to_s.pluralize.underscore
  end

  def self.many_to_name(models_name)
    models_name.to_s.singularize.camelize
  end

  def self.init_models_recursion(recursion, tree, parent_class)
    raise("Too deep recursion in init_models_recursion in ZohoService gem") unless recursion && recursion > 0
    raise("Need parent class in init_models_recursion in ZohoService gem") unless parent_class
    parent_name = parent_class.name.demodulize.underscore
    models = tree.map { |m| m.kind_of?(Array) ? { name: m.first, childs: m.second, params: m.third } : { name: m } }
    models.each do |model|
      # puts "\n try init parent_name2=[#{parent_name}] recursion=[#{recursion}] mod=[#{model.to_json}] \n"
      current_class = nil
      if const_defined?(model[:name])
        current_class = const_get(model[:name])
      else
        current_class = Class.new(Base)
        const_set(model[:name], current_class)
        current_class.model_params = model[:params]
        current_class.default_parent_name = parent_name
      end
      current_class.send(:define_method, parent_name) { |params = {}| get_parent(__method__, params) }
      parent_class.send(:define_method, ZohoService::name_to_many(model[:name])) do
        get_childs(__method__.to_sym, current_class)
      end
      init_models_recursion(recursion - 1, model[:childs], current_class) if model[:childs]
    end
    parent_class.class.send(:define_method, 'childs_list') { models.map { |x| x[:name] }.sort }
  end
end

ZohoService::init_models_recursion(5, ([
  #[model_name, [childs_array], {params}]
  ['Ticket', %w[Comment Thread Attachment TimeEntry], { queries: %w[from limit departmentId sortBy include] }],
  ['Contact', %w[Ticket], { queries: %w[from limit sortBy include] }],
  ['Task', nil, { queries: %w[from limit departmentId sortBy include] }]
] + %w[Organization Account Agent Department]), ZohoService::ApiConnector)
