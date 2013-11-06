#! /usr/bin/env ruby

require 'spec_helper'

describe "Puppet::Util::Windows::Process", :if => Puppet.features.microsoft_windows? do
  describe "as an admin" do
    it "should have the SeCreateSymbolicLinkPrivilege necessary to create symlinks" do
      # this is a bit of a lame duck test since it requires running user to be admin
      # a better integration test would create a new user with the privilege and verify
      Puppet::Util::Windows::User.should be_admin
      Puppet::Util::Windows::Process.process_privilege_symlink?.should be_true
    end
  end
end
