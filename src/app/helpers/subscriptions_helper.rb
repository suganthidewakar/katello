#
# Copyright 2012 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module SubscriptionsHelper

  def subscriptions_pool_link_helper pool_id
    pool = Pool.find(pool_id)
    link_to pool.productName, root_path + "subscriptions#panel=subscription_#{pool_id}"
  end

  def subscriptions_product_helper product_id
    cp_product = Candlepin::Product.get(product_id).first
    product = OpenStruct.new cp_product
    product.cp_id = cp_product['id']
    product
  end

  def subscriptions_system_link_helper host_id
    system = System.first(:conditions => { :uuid => host_id })
    link_to system.name, root_path + "systems#panel=system_#{system.id}"
  end
end
