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
module Navigation
  module SubscriptionMenu
    def self.included(base)
      base.class_eval do
        helper_method :subscriptions_navigation
      end
    end
    def menu_subscriptions
      {:key => :subscriptions,
       :name => _("Subscriptions"),
        :url => :sub_level,
        :options => {:class=>'subscriptions top_level', "data-menu"=>"subscriptions"},
        :items => [ menu_subscriptions_list]
      }
    end


    def menu_subscriptions_list
      {:key => :registered,
       :name => _("All"),
       :url => subscriptions_path,
       :if => lambda{current_organization && current_organization.readable?},
       :options => {:class=>'subscriptions second_level', "data-menu"=>"subscriptions"}
      }
    end

    def subscriptions_navigation
      [
        { :key => :details,
          :name =>_("Details"),
          :url => lambda{edit_subscription_path(@subscription.id)},
          :if => lambda{@subscription},
          :options => {:class=>"navigation_element"},
        },
        { :key => :products,
          :name =>_("Products"),
          :url => lambda{subscriptions_subscription_path(@subscription.id)},
          :if => lambda{@subscription},
          :options => {:class=>"navigation_element"}
        }
      ]
    end
  end
end
