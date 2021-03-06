# Copyright 2013 Google Inc. All Rights Reserved.
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
require "vagrant-google/config"

describe VagrantPlugins::Google::Config do
  let(:instance) { described_class.new }

  # Ensure tests are not affected by Google credential environment variables
  before :each do
    ENV.stub(:[] => nil)
  end

  describe "defaults" do
    subject do
      instance.tap do |o|
        o.finalize!
      end
    end

    its("name")              { should == "new" }
    its("image")             { should == "debian-7-wheezy-v20130816" }
    its("zone")              { should == "us-central1-a" }
    its("network")           { should == "default" }
    its("machine_type")      { should == "n1-standard-1" }
    its("metadata")          { should == {} }
    its("external_ip")       { should == nil }
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:name, :image, :zone, :machine_type, :network,
      :metadata, :external_ip].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end
    end
  end

  describe "getting credentials from environment" do
    context "without Google credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("google_client_email") { should be_nil }
      its("google_key_location") { should be_nil }
    end

    context "with Google credential environment variables" do
      before :each do
        ENV.stub(:[]).with("GOOGLE_CLIENT_EMAIL").and_return("client_id_email")
        ENV.stub(:[]).with("GOOGLE_KEY_LOCATION").and_return("/path/to/key")
      end

      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("google_client_email") { should == "client_id_email" }
      its("google_key_location") { should == "/path/to/key" }
    end
  end

  describe "zone config" do
    let(:config_image)           { "foo" }
    let(:config_machine_type)    { "foo" }
    let(:config_name)            { "foo" }
    let(:config_zone)            { "foo" }
    let(:config_network)         { "foo" }
    let(:config_external_ip)     { "foo" }

    def set_test_values(instance)
      instance.name              = config_name
      instance.network           = config_network
      instance.image             = config_image
      instance.machine_type      = config_machine_type
      instance.zone              = config_zone
      instance.external_ip       = config_external_ip
    end

    it "should raise an exception if not finalized" do
      expect { instance.get_zone_config("us-central1-a") }.
        to raise_error
    end

    context "with no specific config set" do
      subject do
        # Set the values on the top-level object
        set_test_values(instance)

        # Finalize so we can get the zone config
        instance.finalize!

        # Get a lower level zone
        instance.get_zone_config("us-central1-a")
      end

      its("name")              { should == config_name }
      its("image")             { should == config_image }
      its("machine_type")      { should == config_machine_type }
      its("network")           { should == config_network }
      its("zone")              { should == config_zone }
      its("external_ip")       { should == config_external_ip }
    end

    context "with a specific config set" do
      let(:zone_name) { "hashi-zone" }

      subject do
        # Set the values on a specific zone
        instance.zone_config zone_name do |config|
          set_test_values(config)
        end

        # Finalize so we can get the zone config
        instance.finalize!

        # Get the zone
        instance.get_zone_config(zone_name)
      end

      its("name")              { should == config_name }
      its("image")             { should == config_image }
      its("machine_type")      { should == config_machine_type }
      its("network")           { should == config_network }
      its("zone")              { should == zone_name }
      its("external_ip")       { should == zone_external_ip }
    end

    describe "inheritance of parent config" do
      let(:zone) { "hashi-zone" }

      subject do
        # Set the values on a specific zone
        instance.zone_config zone do |config|
          config.image = "child"
        end

        # Set some top-level values
        instance.image = "parent"

        # Finalize and get the zone
        instance.finalize!
        instance.get_zone_config(zone)
      end

      its("image")           { should == "child" }
    end

    describe "shortcut configuration" do
      subject do
        # Use the shortcut configuration to set some values
        instance.zone_config "us-central1-a", :image => "child"
        instance.finalize!
        instance.get_zone_config("us-central1-a")
      end

      its("image") { should == "child" }
    end

    describe "merging" do
      let(:first) { described_class.new }
      let(:second) { described_class.new }

      it "should merge the metadata" do
        first.metadata["one"] = "foo"
        second.metadata["two"] = "bar"

        third = first.merge(second)
        third.metadata.should == {
          "one" => "foo",
          "two" => "bar"
        }
      end
    end
  end
end
