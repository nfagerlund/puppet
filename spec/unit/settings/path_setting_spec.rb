#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Settings::PathSetting do
  subject { described_class.new(:settings => mock('settings'), :desc => "test") }

  context "#munge" do
    it "should expand all path elements" do
      munged = subject.munge("hello#{File::PATH_SEPARATOR}good/morning#{File::PATH_SEPARATOR}goodbye")
      munged.split(File::PATH_SEPARATOR).each do |p|
        Puppet::Util.should be_absolute_path(p)
      end
    end

    it "should leave nil as nil" do
      subject.munge(nil).should be_nil
    end

    context "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should convert \\ to /" do
        subject.munge('C:\test\directory').should == 'C:/test/directory'
      end

      it "should work with UNC paths" do
        subject.munge('//server/some/path').should == '//server/some/path'
        subject.munge('\\\\server\some\path').should == '//server/some/path'
      end
    end
  end
end
