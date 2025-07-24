require 'rails_helper'

describe 'Factory' do
  FactoryBot.factories.each do |factory|
    context factory.name do
      subject { FactoryBot.build(factory.name) }

      it { is_expected.to be_valid }
    end
  end
end
