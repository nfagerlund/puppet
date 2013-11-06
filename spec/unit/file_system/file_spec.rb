require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe Puppet::FileSystem::File do
  include PuppetSpec::Files

  context "#exclusive_open" do
    it "opens ands allows updating of an existing file" do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "the contents"))

      file.exclusive_open(0660, 'r+') do |fh|
        old = fh.read
        fh.truncate(0)
        fh.rewind
        fh.write("updated #{old}")
      end

      expect(file.read).to eq("updated the contents")
    end

    it "opens, creates ands allows updating of a new file" do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      file.exclusive_open(0660, 'w') do |fh|
        fh.write("updated new file")
      end

      expect(file.read).to eq("updated new file")
    end

    it "excludes other processes from updating at the same time", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "0"))

      increment_counter_in_multiple_processes(file, 5, 'r+')

      expect(file.read).to eq("5")
    end

    it "excludes other processes from updating at the same time even when creating the file", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      increment_counter_in_multiple_processes(file, 5, 'a+')

      expect(file.read).to eq("5")
    end

    it "times out if the lock cannot be aquired in a specified amount of time", :unless => Puppet::Util::Platform.windows? do
      file = tmpfile("file_to_update")

      child = spawn_process_that_locks(file)

      expect do
        Puppet::FileSystem::File.new(file).exclusive_open(0666, 'a', 0.1) do |f|
        end
      end.to raise_error(Timeout::Error)

      Process.kill(9, child)
    end

    def spawn_process_that_locks(file)
      read, write = IO.pipe

      child = Kernel.fork do
        read.close
        Puppet::FileSystem::File.new(file).exclusive_open(0666, 'a') do |fh|
          write.write(true)
          write.close
          sleep 10
        end
      end

      write.close
      read.read
      read.close

      child
    end

    def increment_counter_in_multiple_processes(file, num_procs, options)
      children = []
      5.times do |number|
        children << Kernel.fork do
          file.exclusive_open(0660, options) do |fh|
            fh.rewind
            contents = (fh.read || 0).to_i
            fh.truncate(0)
            fh.rewind
            fh.write((contents + 1).to_s)
          end
          exit(0)
        end
      end

      children.each { |pid| Process.wait(pid) }
    end
  end

  describe "symlink", :if => Puppet.features.manages_symlinks?

    let (:file) { Puppet::FileSystem::File.new(tmpfile("somefile")) }
    let (:missing_file) { Puppet::FileSystem::File.new(tmpfile("missingfile")) }
    let (:dir) { Puppet::FileSystem::File.new(tmpdir("somedir")) }

    before :each do
      FileUtils.touch(file.path)
    end

    it "should return true for exist? on a present file" do
      file.exist?.should be_true
      Puppet::FileSystem::File.exist?(file.path).should be_true
    end

    it "should return false for exist? on a non-existant file" do
      missing_file.exist?.should be_false
      Puppet::FileSystem::File.exist?(missing_file.path).should be_false
    end

    it "should return true for exist? on a present directory" do
      dir.exist?.should be_true
      Puppet::FileSystem::File.exist?(dir.path).should be_true
    end

    it "should return false for exist? on a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      missing_file.exist?.should be_false
      symlink.exist?.should be_false
    end

    it "should return true for exist? on valid symlinks" do
      [file, dir].each do |target|
        symlink = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_link"))
        target.symlink(symlink.path)

        target.exist?.should be_true
        symlink.exist?.should be_true
      end
    end

    it "should accept a string, Pathname or object with to_str (Puppet::Util::WatchedFile) for exist?" do
      [ tmpfile('bogus1'),
        Pathname.new(tmpfile('bogus2')),
        Puppet::Util::WatchedFile.new(tmpfile('bogus3'))
        ].each { |f| Puppet::FileSystem::File.exist?(f).should be_false  }
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      file.stat.should be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { missing_file.stat }.to raise_error(Errno::ENOENT)
    end

    it "should be able to create a symlink, and verify it with symlink?" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      symlink.symlink?.should be_true
    end

    it "should report symlink? as false on file, directory and missing files" do
      [file, dir, missing_file].each do |f|
        f.symlink?.should be_false
      end
    end

    it "should return a File::Stat with ftype 'link' when calling lstat on a symlink pointing to existing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      stat = symlink.lstat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'link' when calling lstat on a symlink pointing to missing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      stat = symlink.lstat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to existing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      stat = symlink.stat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'file'
    end

    it "should return a File::Stat of ftype 'directory' when calling stat on a symlink pointing to existing directory" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      dir.symlink(symlink.path)

      stat = symlink.stat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'directory'
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to another symlink" do
      # point symlink -> file
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      # point symlink2 -> symlink
      symlink2 = Puppet::FileSystem::File.new(tmpfile("somefile_link2"))
      symlink.symlink(symlink2.path)

      symlink2.stat.ftype.should == 'file'
    end


    it "should raise Errno::ENOENT when calling stat on a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      expect { symlink.stat }.to raise_error(Errno::ENOENT)
    end

    it "should be able to readlink to resolve the physical path to a symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      file.exist?.should be_true
      symlink.readlink.should == file.path.to_s
    end

    it "should not resolve entire symlink chain with readlink on a symlink'd symlink" do
      # point symlink -> file
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      # point symlink2 -> symlink
      symlink2 = Puppet::FileSystem::File.new(tmpfile("somefile_link2"))
      symlink.symlink(symlink2.path)

      file.exist?.should be_true
      symlink2.readlink.should == symlink.path.to_s
    end

    it "should be able to readlink to resolve the physical path to a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      missing_file.exist?.should be_false
      symlink.readlink.should == missing_file.path.to_s
    end
end
