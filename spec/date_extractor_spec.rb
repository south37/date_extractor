require 'date_extractor'

RSpec.describe DateExtractor do
  it "has a version number" do
    expect(DateExtractor::VERSION).not_to be nil
  end

  describe ".extract" do
    subject { DateExtractor.extract(body, fallback_month: 8, fallback_year: 2017, debug: true) }

    context "when `~以降` is used" do
      let(:body) { "6月27日16時以降、28日14時～16時、29日13時～17時、30日13時以降" }
      let(:expected) {
        [
          ["6月27日16時以降", "28日14時～16時", "29日13時～17時", "30日13時以降"],
          [
            [Date.new(2017, 6, 27), DateTime.new(2017, 6, 27, 16, 0), nil],
            [Date.new(2017, 6, 28), DateTime.new(2017, 6, 28, 14, 0), DateTime.new(2017, 6, 28, 16, 0)],
            [Date.new(2017, 6, 29), DateTime.new(2017, 6, 29, 13, 0), DateTime.new(2017, 6, 29, 17, 0)],
            [Date.new(2017, 6, 30), DateTime.new(2017, 6, 30, 13, 0), nil],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when uppercase letters are used" do
      let(:body) { "・８月１５日１５時以降（明日）・８月１７日１４時以降・８月１８日１４時以降のいずれかはいかがでしょうか" }
      let(:expected) {
        [
          ["８月１５日１５時以降", "８月１７日１４時以降", "８月１８日１４時以降"],
          [
            [Date.new(2017, 8, 15), DateTime.new(2017, 8, 15, 15, 0), nil],
            [Date.new(2017, 8, 17), DateTime.new(2017, 8, 17, 14, 0), nil],
            [Date.new(2017, 8, 18), DateTime.new(2017, 8, 18, 14, 0), nil],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when `/` is used" do
      let(:body) { "8/7   19時から8/8  19時から8/9  19時から" }
      let(:expected) {
        [
          ["8/7   19時", "8/8  19時", "8/9  19時"],
          [
            [Date.new(2017, 8, 7), DateTime.new(2017, 8, 7, 19, 0), nil],
            [Date.new(2017, 8, 8), DateTime.new(2017, 8, 8, 19, 0), nil],
            [Date.new(2017, 8, 9), DateTime.new(2017, 8, 9, 19, 0), nil],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when day of the week is used" do
      let(:body) { "8/11（金）10:00〜12:00 14:00〜19:00 8/12（土）10:00〜12:00 14:00〜19:00 " }
      let(:expected) {
        [
          ["8/11（金）10:00〜12:00", "14:00〜19:00", "8/12（土）10:00〜12:00", "14:00〜19:00"],
          [
            [Date.new(2017, 8, 11), DateTime.new(2017, 8, 11, 10, 0), DateTime.new(2017, 8, 11, 12, 0)],
            [Date.new(2017, 8, 11), DateTime.new(2017, 8, 11, 14, 0), DateTime.new(2017, 8, 11, 19, 0)],
            [Date.new(2017, 8, 12), DateTime.new(2017, 8, 12, 10, 0), DateTime.new(2017, 8, 12, 12, 0)],
            [Date.new(2017, 8, 12), DateTime.new(2017, 8, 12, 14, 0), DateTime.new(2017, 8, 12, 19, 0)],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when day of the week and `時` is used" do
      let(:body) { "日時：8月16日（水）14時～17時 日時：8月17日（木）14時～17時 日時：8月18日（金）14時～17時" }
      let(:expected) {
        [
          ["8月16日（水）14時～17時", "8月17日（木）14時～17時", "8月18日（金）14時～17時"],
          [
            [Date.new(2017, 8, 16), DateTime.new(2017, 8, 16, 14, 0), DateTime.new(2017, 8, 16, 17, 0)],
            [Date.new(2017, 8, 17), DateTime.new(2017, 8, 17, 14, 0), DateTime.new(2017, 8, 17, 17, 0)],
            [Date.new(2017, 8, 18), DateTime.new(2017, 8, 18, 14, 0), DateTime.new(2017, 8, 18, 17, 0)],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when `朝` is used" do
      let(:body) { "8/17 朝-13:00 16:00-夜8/20 朝-12:00 17:00-夜" }
      let(:expected) {
        [
          ["8/17 朝-13:00", "16:00-", "8/20 朝-12:00", "17:00-"],
          [
            [Date.new(2017, 8, 17), nil, DateTime.new(2017, 8, 17, 13, 0)],
            [Date.new(2017, 8, 17), DateTime.new(2017, 8, 17, 16, 0), nil],
            [Date.new(2017, 8, 20), nil, DateTime.new(2017, 8, 20, 12, 0)],
            [Date.new(2017, 8, 20), DateTime.new(2017, 8, 20, 17, 0), nil],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    # TODO: Improve regular expression not to match invalid string.
    context "when invalid match exists" do
      let(:body) { "8/17(木)12:00~です。詳細はhttp://345/79まで。" }
      let(:expected) {
        [
          ["8/17(木)12:00~", "345/79"],
          [
            [Date.new(2017, 8, 17), DateTime.new(2017, 8, 17, 12, 0), nil],
            [nil, nil, nil],
          ]
        ]
      }

      it "extracts dates and returns nil as invalid match" do
        expect(subject).to eq expected
      end
    end

    context "when there are days only" do
      let(:body) { "7/27（木）7/26（水）8/1（火）" }
      let(:expected) {
        [
          ["7/27（木）", "7/26（水）", "8/1（火）"],
          [
            [Date.new(2017, 7, 27), nil, nil],
            [Date.new(2017, 7, 26), nil, nil],
            [Date.new(2017, 8, 1), nil, nil],
          ]
        ]
      }

      it "extracts dates and returns nil as invalid match" do
        expect(subject).to eq expected
      end
    end

    # TODO: Consider `12時まで` as `~12時`
    context "when there is no month" do
      let(:body) { "15日18時〜、17日13時以降、18日12時まで" }
      let(:expected) {
        [
          ["15日18時〜", "17日13時以降", "18日12時"],
          [
            [Date.new(2017, 8, 15), DateTime.new(2017, 8, 15, 18, 0), nil],
            [Date.new(2017, 8, 17), DateTime.new(2017, 8, 17, 13, 0), nil],
            [Date.new(2017, 8, 18), DateTime.new(2017, 8, 18, 12, 0), nil],
          ]
        ]
      }

      it "extracts dates with fallback_month" do
        expect(subject).to eq expected
      end
    end

    context "when `ー` is used" do
      let(:body) { "8月9日    13時30分ー15時の間、8月10日  13時ー15時" }
      let(:expected) {
        [
          ["8月9日    13時30分ー15時", "8月10日  13時ー15時"],
          [
            [Date.new(2017, 8, 9), DateTime.new(2017, 8, 9, 13, 30), DateTime.new(2017, 8, 9, 15, 0)],
            [Date.new(2017, 8, 10), DateTime.new(2017, 8, 10, 13, 0), DateTime.new(2017, 8, 10, 15, 0)],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end

    context "when `半` is used" do
      let(:body) { "8/1（火）19時半以降" }
      let(:expected) {
        [
          ["8/1（火）19時半以降"],
          [
            [Date.new(2017, 8, 1), DateTime.new(2017, 8, 1, 19, 30), nil],
          ]
        ]
      }

      it "extracts dates" do
        expect(subject).to eq expected
      end
    end
  end
end
