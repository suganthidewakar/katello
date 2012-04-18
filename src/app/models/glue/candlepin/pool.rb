#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require_dependency 'resources/candlepin'
require 'util/search'

module Glue::Candlepin::Pool

=begin
  def self.find id
    pool_json = Candlepin::Pool.find_as_json(id)
    Glue::Candlepin::Pool.new(pool_json) if not pool_json.nil?
  end

  attr_accessor :name

  def initialize(params = {})
    params.each_pair {|k,v| instance_variable_set("@#{k}", v) unless v.nil? }
  end

  def self.name_search query, number=15
    return [] if !Tire.index(self.index).exists?
    start = 0

    query = Katello::Search::filter_input query
    query = "name_autocomplete:#{query}"

    search = Tire.search self.index do
      fields [:name]
      query do
        string query
      end
    end
    to_ret = []
    search.results.each{|pkg|
       to_ret << pkg.name if !to_ret.include?(pkg.name)
       break if to_ret.size == number
    }
    return to_ret
  end

  def self.search query, start, page_size, sort=[:name_sort, "ASC"]
    return [] if !Tire.index(self.index).exists?

    all_rows = query.blank? #if blank, get all rows

    search = Tire.search self.index do
      query do
        if all_rows
          all
        else
          string query, {:default_field=>'name'}
        end
      end

      if page_size > 0
       size page_size
       from start
      end

      sort { by sort[0], sort[1] } unless !all_rows
    end
    return search.results
  rescue
    return []
  end
=end

  def self.included(base)
    base.send :include, LazyAccessor
    base.send :include, InstanceMethods
    base.send :extend, ClassMethods

    base.class_eval do
=begin
      lazy_accessor :productName, :productId, :startDate, :endDate, :consumed, :quantity, :attrs, :owner,
        :initializer => lambda {
          json = Candlepin::Pool.find(cp_id)
          # symbol "attributes" is reserved by Rails and cannot be used
          json['attrs'] = json['attributes']
          json
        }

      alias_method :poolName, :productName
      alias_method :expires, :endDate
      alias_method :expires_as_datetime, :endDate_as_datetime
=end
    end
  end

  module ClassMethods
    def find_by_organization_and_id(organization, pool_id)
      pool = KTPool.find_by_cp_id(pool_id) || KTPool.new(Candlepin::Pool.find(pool_id))
      if pool.organization == organization
        return pool
      end
    end
  end

  module InstanceMethods

    attr_accessor :cp_id, :poolDerived, :productName, :consumed, :quantity, :supportLevel, :supportType
    attr_accessor :startDate, :endDate, :attrs, :owner, :productId, :accountNumber, :contractNumber
    attr_accessor :sourcePoolId, :hostId, :virtOnly, :virtLimit
    attr_accessor :arch, :sockets, :description, :productFamily, :variant
    attr_accessor :providedProducts

    def initialize(attrs = nil)
      if not attrs.nil? and attrs.member? 'id'
        # initializing from candlepin json
        @productName = attrs["productName"]
        @startDate = Date.parse(attrs["startDate"])
        @endDate = Date.parse(attrs["endDate"])
        @consumed = attrs["consumed"]
        @quantity = attrs["quantity"]
        @attrs = attrs["attributes"]
        @owner = attrs["owner"]
        @productId = attrs["productId"]
        @cp_id = attrs['id']
        @accountNumber = attrs['accountNumber']
        @contractNumber = attrs['contractNumber']
        @providedProducts = attrs['providedProducts']

        @sourcePoolId = nil
        @hostId = nil
        @virtOnly = false
        @poolDerived = false
        attrs['attributes'].each do |attr|
          if attr['name'] == 'source_pool_id'
            @sourcePoolId = attr['value']
          elsif attr['name'] == 'requires_host'
            @hostId = attr['value']
          elsif attr['name'] == 'virt_only'
            @virtOnly = attr['value'] == 'true' ? true : false
          elsif attr['name'] == 'pool_derived'
            @poolDerived = attr['value'] == 'true' ? true : false
          end
        end

        @virtLimit = 0
        @supportType = ""
        @arch = ""
        @supportLevel = ""
        @sockets = 0
        @description = ""
        @productFamily = ""
        @variant = ""
        attrs['productAttributes'].each do |attr|
          if attr['name'] == 'virt_limit'
            @virtLimit = attr['value'].to_i
          elsif attr['name'] == 'support_type'
            @supportType = attr['value']
          elsif attr['name'] == 'arch'
            @arch = attr['value']
          elsif attr['name'] == 'support_level'
            @supportLevel = attr['value']
          elsif attr['name'] == 'sockets'
            @sockets = attr['value'].to_i
          elsif attr['name'] == 'description'
            @description = attr['value']
          elsif attr['name'] == 'product_family'
            @productFamily = attr['value']
          elsif attr['name'] == 'variant'
            @variant = attr['value']
          end
        end
      end
    end

=begin
    def startDate_as_datetime
      DateTime.parse(startDate)
    end

    def endDate_as_datetime
      DateTime.parse(endDate)
    end
=end

    def organization
      Organization.find_by_name(owner["key"])
    end

  end
end
