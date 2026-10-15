# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/npm_and_yarn"
require "dependabot/npm_and_yarn/helpers"
require "dependabot/npm_and_yarn/native_helpers"

RSpec.describe Dependabot::NpmAndYarn::NativeHelpers do
  after { Dependabot::NpmAndYarn::Helpers.dependency_files = nil }

  describe ".run_pnpm_audit_fix_command" do
    before do
      allow(Dependabot::NpmAndYarn::Helpers).to receive(:run_pnpm_command) do |command, **|
        command == "-v" ? pnpm_version : ""
      end
    end

    context "with pnpm 11" do
      let(:pnpm_version) { "Corepack warning\n11.25.0\n" }

      it "uses the lockfile update fix method" do
        described_class.run_pnpm_audit_fix_command

        expect(Dependabot::NpmAndYarn::Helpers).to have_received(:run_pnpm_command)
          .with("audit --fix=update", fingerprint: "audit --fix=update")
      end
    end

    context "with pnpm 10" do
      let(:pnpm_version) { "10.16.0" }

      it "uses the compatible override fix method" do
        described_class.run_pnpm_audit_fix_command

        expect(Dependabot::NpmAndYarn::Helpers).to have_received(:run_pnpm_command)
          .with("audit --fix", fingerprint: "audit --fix")
      end
    end
  end

  describe ".run_npm8_subdependency_update_command" do
    context "when running on npm 12" do
      before do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:npm_version)
          .and_return(Dependabot::NpmAndYarn::Version.new("12.2.0"))
      end

      it "includes --allow-git=all and --allow-remote=all flags and fingerprints" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to include("--allow-git=all")
          expect(command).to include("--allow-remote=all")
          expect(command).to include("--ignore-scripts")
          expect(options[:fingerprint]).to include("--allow-git=all")
          expect(options[:fingerprint]).to include("--allow-remote=all")
          ""
        end

        described_class.run_npm8_subdependency_update_command(["lodash"])
      end

      it "respects explicit deny in .npmrc by omitting the denied flag" do
        Dependabot::NpmAndYarn::Helpers.dependency_files = [
          Dependabot::DependencyFile.new(name: ".npmrc", content: "allow-git=none\n")
        ]

        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).not_to include("--allow-git")
          expect(command).to include("--allow-remote=all")
          expect(options[:fingerprint]).not_to include("--allow-git")
          expect(options[:fingerprint]).to include("--allow-remote=all")
          ""
        end

        described_class.run_npm8_subdependency_update_command(["lodash"])
      ensure
        Dependabot::NpmAndYarn::Helpers.dependency_files = nil
      end

      it "passes the security bypass through verbatim and keeps it distinguishable in the fingerprint" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to include("--min-release-age=0")
          expect(options[:fingerprint]).to include("--min-release-age=0")
          ""
        end

        described_class.run_npm8_subdependency_update_command(["lodash"], min_release_age_arg: "--min-release-age=0")
      end

      it "passes a cooldown floor through but masks the day count in the fingerprint" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to include("--min-release-age=7")
          expect(options[:fingerprint]).to include("--min-release-age=<days>")
          expect(options[:fingerprint]).not_to include("--min-release-age=7")
          ""
        end

        described_class.run_npm8_subdependency_update_command(["lodash"], min_release_age_arg: "--min-release-age=7")
      end
    end

    context "when running on npm 11" do
      before do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:npm_version)
          .and_return(Dependabot::NpmAndYarn::Version.new("11.17.0"))
      end

      it "does not include allow flags" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).not_to include("--allow-git")
          expect(command).not_to include("--allow-remote")
          expect(options[:fingerprint]).not_to include("--allow-git")
          expect(options[:fingerprint]).not_to include("--allow-remote")
          ""
        end

        described_class.run_npm8_subdependency_update_command(["lodash"])
      end
    end
  end

  describe ".run_npm_audit_fix_command" do
    context "when running on npm 12" do
      before do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:npm_version)
          .and_return(Dependabot::NpmAndYarn::Version.new("12.2.0"))
      end

      it "includes --allow-git=all and --allow-remote=all flags and fingerprints" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to include("--allow-git=all")
          expect(command).to include("--allow-remote=all")
          expect(command).to include("--ignore-scripts")
          expect(options[:fingerprint]).to include("--allow-git=all")
          expect(options[:fingerprint]).to include("--allow-remote=all")
          ""
        end

        described_class.run_npm_audit_fix_command
      end

      it "passes the security bypass through verbatim and keeps it distinguishable in the fingerprint" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to start_with("audit fix")
          expect(command).to include("--min-release-age=0")
          expect(options[:fingerprint]).to include("--min-release-age=0")
          ""
        end

        described_class.run_npm_audit_fix_command(min_release_age_arg: "--min-release-age=0")
      end

      it "passes a cooldown floor through but masks the day count in the fingerprint" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).to include("--min-release-age=14")
          expect(options[:fingerprint]).to include("--min-release-age=<days>")
          expect(options[:fingerprint]).not_to include("--min-release-age=14")
          ""
        end

        described_class.run_npm_audit_fix_command(min_release_age_arg: "--min-release-age=14")
      end
    end

    context "when running on npm 11" do
      before do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:npm_version)
          .and_return(Dependabot::NpmAndYarn::Version.new("11.17.0"))
      end

      it "does not include allow flags" do
        expect(Dependabot::NpmAndYarn::Helpers).to receive(:run_npm_command) do |command, options|
          expect(command).not_to include("--allow-git")
          expect(command).not_to include("--allow-remote")
          expect(options[:fingerprint]).not_to include("--allow-git")
          expect(options[:fingerprint]).not_to include("--allow-remote")
          ""
        end

        described_class.run_npm_audit_fix_command
      end
    end
  end

  # Runs the real commands so that a flag the installed npm rejects (npm 12 throws on unknown or
  # abbreviated flags) is caught. `npm audit fix` exits non-zero when vulnerabilities remain, which is fine here.
  describe "flags accepted by the installed npm" do
    let(:rejected_flag_error) { /EUNKNOWNCONFIG|Unknown cli flag|Unknown cli config/ }

    around do |example|
      fixture_files = project_dependency_files("npm8/subdependency_update")

      Dependabot::SharedHelpers.in_a_temporary_directory do
        fixture_files.each do |file|
          FileUtils.mkdir_p(File.dirname(file.name))
          File.write(file.name, file.content)
        end
        example.run
      end
    end

    def command_error
      yield
      nil
    rescue Dependabot::SharedHelpers::HelperSubprocessFailed => e
      e.message
    end

    it "accepts the flags used by the subdependency update, with and without a release-age gate" do
      [nil, "--min-release-age=0", "--min-release-age=7"].each do |gate|
        error = command_error do
          described_class.run_npm8_subdependency_update_command(["acorn"], min_release_age_arg: gate)
        end

        expect(error).not_to match(rejected_flag_error)
      end
    end

    it "accepts the flags used by the audit fix fallback, with and without a release-age gate" do
      [nil, "--min-release-age=0", "--min-release-age=7"].each do |gate|
        error = command_error { described_class.run_npm_audit_fix_command(min_release_age_arg: gate) }

        expect(error).not_to match(rejected_flag_error)
      end
    end
  end
end
