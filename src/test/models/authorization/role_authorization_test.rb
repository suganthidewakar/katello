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

require 'models/repository_base'

class RoleAuthorizationAdminTest < MiniTest::Rails::ActiveSupport::TestCase
  include RepositoryTestBase

  def setup
    super
    User.current = User.find(users('admin'))
    @role = Role.find(roles(:administrator))
  end

  def test_readable
    assert !Role.readable.empty?
  end

   def test_creatable?
     assert Role.creatable?
   end

   def test_editable?
     assert Role.editable?
   end

   def test_deletable?
      assert Role.deletable?
   end

   def test_any_readable?
     assert Role.any_readable?
   end

   def test_readable?
     assert Role.readable?
   end

end


class RoleAuthorizationNoPermsTest < MiniTest::Rails::ActiveSupport::TestCase
  include RepositoryTestBase

  def setup
    super
    User.current = User.find(users('no_perms_user'))
    @role = Role.find(roles(:administrator))
  end

  def test_readable
    assert Role.readable.empty?
  end

   def test_creatable?
     assert !Role.creatable?
   end

   def test_editable?
     assert !Role.editable?
   end

   def test_deletable?
      assert !Role.deletable?
   end

   def test_any_readable?
     assert !Role.any_readable?
   end

   def test_readable?
     assert !Role.readable?
   end

end