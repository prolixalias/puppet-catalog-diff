require 'puppet/network/http_pool'
require 'uri'
require 'json'

module Puppet::CatalogDiff
  # A compiled catalog from Puppet Enterprise
  # The get_factsets retrieves all of the factsets on a puppet master
  #
  # @param pe_hostname [String] The hostname of the puppet enterprise server to pull the factsets from
  # @param environment [String] The environment to use when catalog compiling
  # @param node [String] The name of the ndoe to run a compile against
  # @param facts [Array<Hash>] List of facts to compile the catalog againsts
  # @return [Catalog] a compiled catalog from the Puppet Enterprise Server
  class Catalog
    def self.get_catalog(pe_hostname, environment, node, facts)
      # Clone a passed in object.
      local_facts = facts.clone

      local_facts['values'].delete('trusted')

      # Let's stick to PSON for now. Early version of Puppet accept only PSON.
      facts_pson = PSON.generate(local_facts)

      # Escape facts not once, not thrice, but twice
      facts_pson_encoded = URI.escape(URI.escape(facts_pson))

      endpoint = "/puppet/v3/catalog/#{node}?environment=#{environment}"
      #data = "environment=#{environment}&facts_format=pson&facts=#{facts_pson_encoded}"
      #endpoint = "/puppet/v3/catalog/#{node}"
      data = "facts_format=pson&facts=#{facts_pson_encoded}"

      begin
        connection = Puppet::Network::HttpPool.http_instance(pe_hostname, '8140')
        response = connection.post(endpoint, data, 'Content-Type' => 'application/x-www-form-urlencoded').body

        filtered = JSON.parse(response)

        catalog = Puppet::CatalogDiff::Catalog.new(
          filtered['tags'],
          filtered['name'],
          filtered['version'],
          filtered['code_id'],
          filtered['catalog_uuid'],
          filtered['catalog_format'],
          filtered['environment'],
          filtered['resources'],
          filtered['edges'],
          filtered['classes'],
        )
        # rescue Exception => e
        #  raise "Error retrieving catalog from #{server}: #{e.message}"
      end

      catalog
    end

    def to_json
      {
        'tags' => @tags,
        'name' => @name,
        'version' => @version,
        'code_id' => @code_id,
        'catalog_uuid' => @catalog_uuid,
        'catalog_format' => @catalog_format,
        'environment' => @environment,
        'resources' => @resources,
        'edges' => @edges,
        'classes' => @classes
      }.to_json
    end

    def initialize(tags, name, version, code_id, catalog_uuid, catalog_format, environment, resources, edges, classes)
      @tags = tags
      @name = name
      @version = version
      @code_id = code_id
      @catalog_uuid = catalog_uuid
      @catalog_format = catalog_format
      @environment = environment
      @resources = resources
      @edges = edges
      @classes = classes
    end

    def ==(other_item)
      @tags == other_item.tags &&
        @name == other_item.name &&
        @environment == other_item.environment &&
        @resources == other_item.resources &&
        @edges == other_item.edges &&
        @classes == other_item.classes
    end

    def eql?(other_item)
      self == other_item
    end

    def hash
      @tags.hash ^ @name.hash ^ @environment.hash ^ @resources.hash ^ @edges.hash ^ @classes.hash
    end

    attr_reader :tags

    attr_reader :name

    attr_reader :version

    attr_reader :code_id

    attr_reader :catalog_uuid

    attr_reader :catalog_format

    attr_reader :environment

    attr_reader :resources

    attr_reader :edges

    attr_reader :classes
  end
end
