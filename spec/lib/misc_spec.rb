# frozen_string_literal: true

module UplinkTest
  describe Uplink do
    context '[Misc Tests]' do
      it 'checking if there is data stored in the global map' do
        expect(described_class.internal_universe_is_empty?).to be(true)

        described_class.parse_access(ACCESS_STRING) do |_access|
          expect(described_class.internal_universe_is_empty?).to be(false)
        end

        expect(described_class.internal_universe_is_empty?).to be(true)
      end
    end
  end
end
