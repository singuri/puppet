require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet/parser/script_compiler'

describe 'the script compiler' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include Matchers::Resource
  before(:each) do
    Puppet[:tasks] = true
  end

  context "when used" do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Puppet[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
    let(:node) { Puppet::Node.new("test", :environment => env) }

    let(:env_dir_files) {
      {
        'modules' => {
          'test' => {
            'plans' => {
               'run_me.pp' => 'plan test::run_me() { "worked2" }'
            }
          }
        }
      }
    }

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    let(:script_compiler) do
      Puppet::Parser::ScriptCompiler.new(env, node.name)
    end

    context 'is configured such that' do
      it 'returns what the script_compiler returns' do
        Puppet[:code] = <<-CODE
            42
          CODE
        expect(script_compiler.compile).to eql(42)
      end

      it 'can run a plan' do
        Puppet[:code] = <<-CODE
            run_plan('test::run_me')
          CODE
        expect(script_compiler.compile).to eql('worked2')
      end

      it 'referencing undefined variables raises an error' do
        expect do
          Puppet[:code] = <<-CODE
              notice $rubyversion
            CODE
            Puppet::Parser::ScriptCompiler.new(env, 'test_node_name').compile

        end.to raise_error(/Unknown variable: 'rubyversion'/)
      end
    end
  end
end
