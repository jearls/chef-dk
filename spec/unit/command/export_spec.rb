#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'chef-dk/command/export'

describe ChefDK::Command::Export do

  let(:params) { [] }

  let(:command) do
    described_class.new
  end

  let(:policyfile_lock) do
    instance_double(ChefDK::PolicyfileLock, name: "example-policy")
  end

  let(:export_service) do
    instance_double(ChefDK::PolicyfileServices::ExportRepo,
                    policyfile_lock: policyfile_lock)
  end

  context "after evaluating params" do

    let(:params) { [ "path/to/export" ] }

    before do
      command.apply_params!(params)
    end

    it "disables debug by default" do
      expect(command.debug?).to be(false)
    end

    it "configures a default UI component" do
      ui = command.ui
      expect(ui.out_stream).to eq($stdout)
      expect(ui.err_stream).to eq($stderr)
    end

    context "when debug mode is set" do

      let(:params) { [ "path/to/export", "-D" ] }

      it "enables debug" do
        expect(command.debug?).to be(true)
      end
    end

    context "when the path to the exported repo is given" do

      let(:params) { [ "path/to/export" ] }

      it "configures the export service with the export path" do
        expect(command.export_service.export_dir).to eq(File.expand_path("path/to/export"))
      end

      it "uses the default policyfile name" do
        expect(command.export_service.policyfile_filename).to eq(File.expand_path("Policyfile.rb"))
      end

    end

    context "when a Policyfile relative path and export path are given" do

      let(:params) { [ "CustomNamedPolicy.rb", "path/to/export" ] }

      it "configures the export service with the export path" do
        expect(command.export_service.export_dir).to eq(File.expand_path("path/to/export"))
      end

      it "configures the export service with the policyfile relative path" do
        expect(command.export_service.policyfile_filename).to eq(File.expand_path("CustomNamedPolicy.rb"))
      end
    end
  end

  describe "running the export" do

    let(:params) { [ "/path/to/export" ] }

    let(:ui) { TestHelpers::TestUI.new }

    before do
      command.ui = ui
      allow(command).to receive(:export_service).and_return(export_service)
    end

    context "with no arguments" do

      it "exits non-zero and prints a help message" do
        expect(command.run).to eq(1)
      end

    end

    context "when the command is successful" do

      before do
        expect(export_service).to receive(:run)
      end

      it "returns 0" do
        expect(command.run(params)).to eq(0)
      end
    end

    context "when the command is unsuccessful" do

      let(:backtrace) { caller[0...3] }

      let(:cause) do
        e = StandardError.new("some operation failed")
        e.set_backtrace(backtrace)
        e
      end

      let(:exception) do
        ChefDK::PolicyfileExportRepoError.new("export failed", cause)
      end

      before do
        expect(export_service).to receive(:run).and_raise(exception)
      end

      it "returns 1" do
        expect(command.run(params)).to eq(1)
      end

      it "displays the exception and cause" do
        expected_error_text=<<-E
Error: export failed
Reason: (StandardError) some operation failed

E

        command.run(params)
        expect(ui.output).to eq(expected_error_text)
      end

      context "and debug is enabled" do

        let(:params) { [ "path/to/export", "-D"] }

        it "displays the exception and cause with backtrace" do
          expected_error_text=<<-E
Error: export failed
Reason: (StandardError) some operation failed


E

          expected_error_text << backtrace.join("\n") << "\n"

          command.run(params)
          expect(ui.output).to eq(expected_error_text)
        end
      end

    end

  end
end
