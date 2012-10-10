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

RSpec.configure do |config|
  config.before do
    User._disable_foreman_orchestration = nil
  end
  config.after do
    User._disable_foreman_orchestration = nil
  end
end

User.singleton_class.send :attr_accessor, :_disable_foreman_orchestration
User.singleton_class.send :public, :_disable_foreman_orchestration, :_disable_foreman_orchestration=

disable_foreman_orchestration_methods = lambda do |user|
  [:create_foreman_user, :update_foreman_user, :destroy_foreman_user, :foreman_consistency_check].each do |method|
    user.stub!(method).and_return(true)
  end
end

method_body = lambda do |original_method, *args, &block|
  user = original_method.call(*args, &block)
  disable_foreman_orchestration_methods.call user if User._disable_foreman_orchestration
  user
end

original_new      = User.method :new
User.singleton_class.send(:define_method, :new) do |*args, &block|
  method_body.call original_new, *args, &block
end

original_allocate = User.method :allocate
User.singleton_class.send(:define_method, :allocate) do
  method_body.call original_allocate
end