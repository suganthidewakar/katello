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
require 'ostruct'

# TODO: subscriptions_controller rules - what roles to test?
# DONE: subscriptions_controller param_rules
# DONE: limit search to organization
# TODO: display all relevant fields in Details page
# TODO: replace OpenStruct w/ Pool model
# TODO: remove unneeded fields in json before indexing
# TODO: activation keys broken
# TODO: links to subscriptions, systems, activation keys
# TODO: third tab "consumers" (?) to list referenced systems, activation keys, etc.
# TODO: index provided products fields for better search
# TODO: spinner while manifest importing
# TODO: start / end dates in left subscriptions list
# TODO: where / when to force update search index? (currently on call to 'items' w/o search)
# TODO: infinite scroll search not showing correct totals (working at all?)
# TODO: prepend 'repo url' to products' Content Download URL on Products tab

class SubscriptionsController < ApplicationController

  before_filter :find_provider
  before_filter :find_subscription, :except=>[:index, :items, :new]
  before_filter :authorize
  before_filter :setup_options, :only=>[:index, :items]

  # two pane columns and mapping for sortable fields
  COLUMNS = {'name' => 'name_sort'}

  def rules
    read_org = lambda{current_organization && current_organization.readable?}
    read_provider_test = lambda{@provider.readable?}
    {
      :index => read_org,
      :items => read_org,
      :show => lambda{true},
      :edit => lambda{true},
      :products => lambda{true},
      :new => read_provider_test
    }
  end

  def param_rules
    {
        # empty
    }
  end


  def index
  end

  def items
    order = split_order(params[:order])
    search = params[:search]
    offset = params[:offset]
    filters = {}

    if search.nil?
      find_subscriptions
    else
      @subscriptions = Pool.search(current_organization.cp_key, search, offset, current_user.page_size)
    end

    if offset
      render :text => "" and return if @subscriptions.empty?

      #options = {:list_partial => 'subscriptions/list_subscriptions', :accessor => "product_id", :name => controller_display_name}
      render_panel_items(@subscriptions, @panel_options, nil, offset)
    else
      @subscriptions = @subscriptions[0..current_user.page_size]

      #options = {:list_partial => 'subscriptions/list_subscriptions', :accessor => "product_id", :name => controller_display_name}
      render_panel_items(@subscriptions, @panel_options, nil, offset)
    end

    #render_panel_direct(Product, @panel_options, search, params[:offset], order,
    #                    {:filter=>filters, :load=>true})
  end

  def edit
    render :partial => "edit", :layout => "tupane_layout", :locals => {:subscription => @subscription, :editable => false, :name => controller_display_name}
  end

  def show
    @provider = current_organization.redhat_provider
    render :partial=>"subscriptions/list_subscription_show", :locals=>{:item=>@subscription, :accessor=>"product_id", :columns => COLUMNS.keys, :noblock => 1}
  end

  def products
    render :partial=>"products", :layout => "tupane_layout", :locals=>{:subscription=>@subscription, :editable => false, :name => controller_display_name}
  end

  def new
    render :partial=>"new", :layout =>"tupane_layout", :locals=>{:provider=>@provider}
  end

  def section_id
    'subscriptions'
  end

  private

  def split_order order
    if order
      order.split
    else
      [:name_sort, "ASC"]
    end
  end

  def find_subscription
    cp_pool = Candlepin::Pool.find(params[:id])
    cp_product = Candlepin::Product.get(cp_pool['productId']).first
    @subscription = populate_subscription(cp_pool, cp_product)
  end

  def find_subscriptions
    pools = Candlepin::Owner.pools current_organization.cp_key

    # Update elastic-search
    Pool.index_pools pools

    @subscriptions = []

    # Cache products to avoid duplicating calls to candlepin
    products = {}

    pools.each do |pool|
      # Bonus pools have their sourceEntitlement set
      # TODO: Does the count of the parent pool get its quantity updated?
      #next if pool['sourceEntitlement'] != nil

      product = products[pool['productId']]
      if !product
        product = Candlepin::Product.get(pool['productId']).first
        products[pool['productId']] = product
      end
      @subscriptions << populate_subscription(pool, product)
    end

    @subscriptions
  end

  # Package up subscription details for consumption by view layer
  def populate_subscription(cp_pool, cp_product)

    subscription = OpenStruct.new cp_pool
    #subscription.consumed_stats = converted_stats
    subscription.cp_id = cp_pool['id']
    subscription.product = cp_product
    subscription.startDate = Date.parse(subscription.startDate)
    subscription.endDate = Date.parse(subscription.endDate)

    # Other interesting attributes for easier access
    subscription.virt_only = false
    subscription.support_level = 'None'
    subscription.requires_host_id = nil
    subscription.source_pool_id = nil
    cp_pool['attributes'].each do |attr|
      if attr['name'] == 'virt_only' && attr['value'] == 'true'
        subscription.virt_only = true
      elsif attr['name'] == 'requires_host'
        subscription.requires_host_id = attr['value']
      elsif attr['name'] == 'source_pool_id'
        subscription.source_pool_id = attr['value']
      end
    end
    cp_product['attributes'].each do |attr|
      if attr['name'] == 'virt_only' && attr['value'] == 'true'
          subscription.virt_only = true
      elsif attr['name'] == 'support_level'
        subscription.support_level = attr['value']
      elsif attr['name'] == 'arch'
        subscription.arch = attr['value']
      end
    end

    subscription
  end

  def setup_options
    @panel_options = { :title => _('Subscriptions'),
                      :col => ["name"],
                      :titles => [_("Name")],
                      :custom_rows => true,
                      :enable_create => @provider.editable?,
                      :create_label => _("+ Import Manifest"),
                      :enable_sort => true,
                      :name => controller_display_name,
                      :list_partial => 'subscriptions/list_subscriptions',
                      :ajax_load  => true,
                      :ajax_scroll => items_subscriptions_path(),
                      :actions => nil,
                      :search_class => Pool,
                      :accessor => "cp_id"
                      }
  end

  def controller_display_name
    return 'subscription'
  end

  def find_provider
      @provider = current_organization.redhat_provider
  end


end
