#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/code/configuration'

describe Puppet::Indirector::Code::Configuration do
    # LAK:TODO I have no idea how to do this, or even if it should be in this class or test or what.
    # This is used for determining if the client should recompile its configuration, so it's not sufficient
    # to recompile and compare versions.
    #   It might be that the right solution is to require configuration caching, and then compare the cached
    # configuration version to the current version, via some querying mechanism (i.e., the client asks for just
    # the configuration's 'up-to-date' attribute, rather than the whole configuration).
    it "should provide a mechanism for determining if the client's configuration is up to date"
end

describe Puppet::Indirector::Code::Configuration do
    before do
        Puppet.expects(:version).returns(1)
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
    end

    it "should gather data about itself" do
        Puppet::Indirector::Code::Configuration.new
    end

    it "should cache the server metadata and reuse it" do
        compiler = Puppet::Indirector::Code::Configuration.new
        node1 = stub 'node1', :merge => nil
        node2 = stub 'node2', :merge => nil
        compiler.stubs(:compile)
        Puppet::Node.stubs(:search).with('node1').returns(node1)
        Puppet::Node.stubs(:search).with('node2').returns(node2)

        compiler.find('node1')
        compiler.find('node2')
    end
end

describe Puppet::Indirector::Code::Configuration, " when creating the interpreter" do
    before do
        @compiler = Puppet::Indirector::Code::Configuration.new
    end

    it "should not create the interpreter until it is asked for the first time" do
        interp = mock 'interp'
        Puppet::Parser::Interpreter.expects(:new).with({}).returns(interp)
        @compiler.interpreter.should equal(interp)
    end

    it "should use the same interpreter for all compiles" do
        interp = mock 'interp'
        Puppet::Parser::Interpreter.expects(:new).with({}).returns(interp)
        @compiler.interpreter.should equal(interp)
        @compiler.interpreter.should equal(interp)
    end

    it "should provide a mechanism for setting the code to pass to the interpreter" do
        @compiler.should respond_to(:code=)
    end

    it "should pass any specified code on to the interpreter when it is being initialized" do
        code = "some code"
        @compiler.code = code
        interp = mock 'interp'
        Puppet::Parser::Interpreter.expects(:new).with(:Code => code).returns(interp)
        @compiler.send(:interpreter).should equal(interp)
    end

end

describe Puppet::Indirector::Code::Configuration, " when finding nodes" do
    before do
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = mock 'node'
        @compiler.stubs(:compile)
    end

    it "should look node information up via the Node class with the provided key" do
        @node.stubs :merge 
        Puppet::Node.expects(:search).with(@name).returns(@node)
        @compiler.find(@name)
    end

    it "should fail if it cannot find the node" do
        @node.stubs :merge 
        Puppet::Node.expects(:search).with(@name).returns(nil)
        proc { @compiler.find(@name) }.should raise_error(Puppet::Error)
    end
end

describe Puppet::Indirector::Code::Configuration, " after finding nodes" do
    before do
        Puppet.expects(:version).returns(1)
        Puppet.settings.stubs(:value).with(:node_name).returns("cert")
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = mock 'node'
        @compiler.stubs(:compile)
        Puppet::Node.stubs(:search).with(@name).returns(@node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
        @node.expects(:merge).with { |args| args["serverversion"] == "1" }
        @compiler.find(@name)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
        @node.expects(:merge).with { |args| args["servername"] == "my.server.com" }
        @compiler.find(@name)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
        @node.expects(:merge).with { |args| args["serverip"] == "my.ip.address" }
        @compiler.find(@name)
    end

    # LAK:TODO This is going to be difficult, because this whole process is so
    # far removed from the actual connection that the certificate information
    # will be quite hard to come by, dum by, gum by.
    it "should search for the name using the client certificate's DN if the :node_name setting is set to 'cert'"
end

describe Puppet::Indirector::Code::Configuration, " when creating configurations" do
    before do
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = stub 'node', :merge => nil, :name => @name, :environment => "yay"
        Puppet::Node.stubs(:search).with(@name).returns(@node)
    end

    it "should pass the found node to the interpreter for compiling" do
        config = mock 'config'
        @compiler.interpreter.expects(:compile).with(@node)
        @compiler.find(@name)
    end

    it "should return the results of compiling as the configuration" do
        config = mock 'config'
        @compiler.interpreter.expects(:compile).with(@node).returns(:configuration)
        @compiler.find(@name).should == :configuration
    end

    it "should benchmark the compile process" do
        @compiler.expects(:benchmark).with do |level, message|
            level == :notice and message =~ /^Compiled configuration/
        end
        @compiler.interpreter.stubs(:compile).with(@node)
        @compiler.find(@name)
    end
end
