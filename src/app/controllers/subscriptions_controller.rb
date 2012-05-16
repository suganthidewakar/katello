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
# DONE: display all relevant fields in Details page
# DONE: replace OpenStruct w/ Pool model
# TODO: remove unneeded fields in json before indexing
# TODO: activation keys broken
# TODO: links to subscriptions, systems, activation keys
# TODO: third tab "consumers" (?) to list referenced systems, activation keys, etc.
# TODO: index provided products fields for better search
# TODO: spinner while manifest importing
# TODO: start / end dates in left subscriptions list
# DONE: where / when to force update search index? (currently on call to 'items' w/o search) <- leaving there
# TODO: infinite scroll search not showing correct totals (working at all?)
# TODO: prepend 'repo url' to products' Content Download URL on Products tab <- Does this make sense? The URL has $releasever and $basearch in it
# TODO: limit subscriptions to red hat provider
# TODO: add a 'Repositories' tab in addition to/replace of 'Products'? Could show/edit enabled
# TODO: add name sorting in left list (how? using name_sort elastic search field?)
# TODO: start date range not working?  start:2012-01-31 fails but start:"2012-01-31" works
# TODO: in 'consumers' fence by roles what systems and activation keys are visible
# TODO: spinner while importing manifest

class SubscriptionsController < ApplicationController

  before_filter :find_provider
  before_filter :find_subscription, :except=>[:index, :items, :new, :upload, :history]
  before_filter :authorize
  before_filter :setup_options, :only=>[:index, :items]

  # two pane columns and mapping for sortable fields
  COLUMNS = {'name' => 'name_sort'}

  def rules
    read_org = lambda{current_organization && current_organization.readable?}
    read_provider_test = lambda{@provider.readable?}
    edit_provider_test = lambda{@provider.editable?}
    {
      :index => read_org,
      :items => read_org,
      :show => lambda{true},
      :edit => lambda{true},
      :products => lambda{true},
      :consumers => lambda{true},
      :history => lambda{true},
      :new => read_provider_test,
      :upload => edit_provider_test
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
    offset = params[:offset] || "0"
    filters = {}

    # Without any search terms, all subscriptions for an org are queried directly from candlepin instead of
    # hitting elastic search. This is important since this is then only time subscriptions get reindexed
    # currently.
    if search.nil?
      find_subscriptions
    else
      @subscriptions = Pool.search(current_organization.cp_key, search, offset, current_user.page_size)
    end

    if offset != "0"
      render :text => "" and return if @subscriptions.empty?

      render_panel_items(@subscriptions, @panel_options, nil, offset)
    else
      @subscriptions = @subscriptions[0..current_user.page_size]

      render_panel_items(@subscriptions, @panel_options, nil, offset)
    end
  end

  def edit
    render :partial => "edit", :layout => "tupane_layout", :locals => {:subscription => @subscription, :editable => false, :name => controller_display_name}
  end

  def show
    @provider = current_organization.redhat_provider
    render :partial=>"subscriptions/list_subscription_show", :locals=>{:item=>@subscription, :columns => COLUMNS.keys, :noblock => 1}
  end

  def products
    render :partial=>"products", :layout => "tupane_layout", :locals=>{:subscription=>@subscription, :editable => false, :name => controller_display_name}
  end

  def consumers
    systems = current_organization.systems
    systems = systems.all_by_pool(@subscription.cp_id)

    activation_keys = ActivationKey.joins(:pools).where('pools.cp_id'=>@subscription.cp_id)

    render :partial=>"consumers", :layout => "tupane_layout", :locals=>{:subscription=>@subscription, :systems=>systems, :activation_keys=>activation_keys, :editable => false, :name => controller_display_name}
  end

  def new
    render :partial=>"new", :layout =>"tupane_layout", :locals=>{:provider=>@provider, :name => controller_display_name}
  end

  def history

    begin
      @statuses = @provider.owner_imports
    rescue Exception => error
      @statuses = []
      display_message = parse_display_message(error.response)
      error_text = _("Unable to retrieve subscription history for provider '%{name}." % {:name => @provider.name})
      error_text += _("%{newline}Reason: %{reason}" % {:reason => display_message, :newline => "<br />"}) unless display_message.blank?
      notice error_text, {:level => :error, :synchronous_request => false}
      Rails.logger.error "Error fetching subscription history from Candlepin"
      Rails.logger.error error
      Rails.logger.error error.backtrace.join("\n")
      render :partial=>"history", :layout =>"tupane_layout", :status => :bad_request, :locals=>{:provider=>@provider, :name => controller_display_name, :statuses=>@statuses}
      return
    end

    render :partial=>"history", :layout =>"tupane_layout", :locals=>{:provider=>@provider, :name => controller_display_name, :statuses=>@statuses}
  end


  def upload
    if !params[:provider].blank? and params[:provider].has_key? :contents
      temp_file = nil
      begin
        dir = "#{Rails.root}/tmp"
        Dir.mkdir(dir) unless File.directory? dir
        temp_file = File.new(File.join(dir, "import_#{SecureRandom.hex(10)}.zip"), 'w+', 0600)
        temp_file.write params[:provider][:contents].read
        temp_file.close
        # force must be a string value
        force_update = params[:force_import] == "1" ? "true" : "false"
        @provider.import_manifest(File.expand_path(temp_file.path), { :force => force_update })
        if AppConfig.katello?
          notice _("Subscription manifest uploaded successfully for provider '%{name}'. Please enable the repositories you want to sync by selecting 'Enable Repositories' and selecting individual repositories to be enabled." % {:name => @provider.name}), {:synchronous_request => false}
        else
          notice _("Subscription manifest uploaded successfully for provider '%{name}'." % {:name => @provider.name}), {:synchronous_request => false}
        end

      rescue Exception => error
        if error.respond_to?(:response)
          display_message = parse_display_message(error.response)
        elsif error.message
          display_message = error.message
        else
          display_message = ""
        end

        error_text = _("Subscription manifest upload for provider '%{name}' failed." % {:name => @provider.name})
        error_text += _("%{newline}Reason: %{reason}" % {:reason => display_message, :newline => "<br />"}) unless display_message.blank?

        # In some cases, force_update will allow the manifest to be uploaded when it normally would not
        if force_update == "false"
          error_text += _("%{newline}If you are uploading an older manifest, you can use the Force checkbox to overwrite existing data." % { :newline => "<br />"})
        end

        notice error_text, {:level => :error, :details => pp_exception(error)}

        Rails.logger.error "error uploading subscriptions."
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")
        # Fall-through even on error so that the import history is refreshed
      end
      items
    else
      # user didn't provide a manifest to upload
      notice _("Subscription manifest must be specified on upload."), {:level => :error}
      render :nothing => true
    end
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
    @subscription = Pool.find(params[:id])
  end

  def find_subscriptions
    cp_pools = Candlepin::Owner.pools current_organization.cp_key

    # Update elastic-search
    @subscriptions = Pool.index_pools cp_pools
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
                      :accessor => 'unused'
                      }
  end

  def controller_display_name
    return 'subscription'
  end

  def find_provider
      @provider = current_organization.redhat_provider
  end


end
